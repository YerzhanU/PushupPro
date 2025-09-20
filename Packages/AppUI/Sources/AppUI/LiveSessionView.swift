//
//  LiveSessionView.swift
//  AppUI
//

//
//  LiveSessionView.swift
//  AppUI
//

import SwiftUI
import Sensing
import RepEngine
import Sessions
#if canImport(ARKit)
import ARKit
#endif

public struct LiveSessionView: View {
  // MARK: Injection
  private let onSessionSaved: ((Sessions.Session) -> Void)?

  // MARK: UI state
  @State private var reps = 0
  @State private var telemetry = RepTelemetry()
  @State private var error: String?
  @State private var statusText = "Starting…"
  @State private var providerLabel = "—"

  // Detector config
  @State private var manualCM: Double = 3.0
  @State private var currentConfig = RepConfig(heightDeltaCM: 3.0)

  // Session
  @State private var sessionID = UUID()
  @State private var finishedSession: Sessions.Session?
  @State private var showDebug = true

  // Recording & provider
  @State private var recorder = SessionRecorder()
  @State private var store = SessionStore()
  @State private var currentProvider: (any DistanceProvider)?
  @State private var lastSampleWallTime: Date?

  @Environment(\.dismiss) private var dismiss

  public init(onSessionSaved: ((Sessions.Session) -> Void)? = nil) {
    self.onSessionSaved = onSessionSaved
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        HStack {
          Text("Push-ups").font(.largeTitle).bold()
          Spacer()
          Button("End") { endSession() }.buttonStyle(.borderedProminent)
          Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
            .buttonStyle(.plain)
        }

        HStack(spacing: 8) {
          Circle().fill(hasRecentSample ? Color.green : Color.yellow).frame(width: 10, height: 10)
          Text(statusText).font(.footnote).foregroundStyle(.secondary)
          Spacer()
          Text(providerLabel).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

        Text("\(reps)")
          .font(.system(size: 96, weight: .black, design: .rounded))

        depthBar
          .frame(height: 14)
          .clipShape(RoundedRectangle(cornerRadius: 7))

        if showDebug { DebugPanel(t: telemetry) }

        if let error {
          Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Session")
      .navigationDestination(item: $finishedSession) { s in
        SessionSummaryView(session: s, onDone: { dismiss() })
      }
    }
    .onAppear {
      sessionID = UUID()
      statusText = "Starting…"
      providerLabel = "—"
      currentConfig = RepConfig(
        heightDeltaCM: manualCM,
        rearmEpsCM: 0.5,
        minRepDuration: 0.7,
        smoothingAlpha: 0.25,
        clampMinCM: 0.3, clampMaxCM: 6.0,
        topDecayPerSec: 0.6
      )
    }
    .onDisappear {
      currentProvider?.stop()
      currentProvider = nil
    }
    .task(id: sessionID) { await run() }
  }

  private var hasRecentSample: Bool {
    guard let last = lastSampleWallTime else { return false }
    return Date().timeIntervalSince(last) <= 1.5
  }

  // MARK: Depth bar
  @ViewBuilder private var depthBar: some View {
    GeometryReader { geo in
      let target = telemetry.targetBottomCM.isFinite ? telemetry.targetBottomCM : manualCM
      let cm = telemetry.smoothedCM.isFinite ? telemetry.smoothedCM : target

      let minCM = max(0, target - 6)
      let maxCM = max(minCM + 0.001, target + 10)
      let x: (Double) -> CGFloat = { value in
        let n = max(0, min(1, (value - minCM) / (maxCM - minCM)))
        return CGFloat(n) * geo.size.width
      }

      ZStack(alignment: .leading) {
        Rectangle().fill(Color.gray.opacity(0.2))
        Rectangle().fill(.blue).frame(width: max(4, x(cm)))
        Path { $0.addRect(.init(x: x(target) - 1, y: 0, width: 2, height: geo.size.height)) }
          .stroke(style: .init(lineWidth: 2))
          .foregroundStyle(.green)
      }
    }
  }

  // MARK: Loop (ARKit-only)
  private func run() async {
    await MainActor.run {
      reps = 0
      telemetry = RepTelemetry()
      error = nil
      lastSampleWallTime = nil
      recorder.start(heightDeltaCM: currentConfig.heightDeltaCM, startDate: Date())
    }

    #if !canImport(ARKit)
    await MainActor.run {
      self.error = "ARKit not available on this platform."
      self.statusText = "Unsupported"
    }
    return
    #else
    if !ARFaceTrackingConfiguration.isSupported {
      await MainActor.run {
        self.error = "This device doesn’t support TrueDepth face tracking."
        self.statusText = "Unsupported"
      }
      return
    }
    #endif

    let provider: any DistanceProvider = ARKitDepthProvider()
    currentProvider = provider
    do {
      try await provider.start()
      await MainActor.run {
        providerLabel = "ARKit TrueDepth"
        statusText = "Running…"
      }
    } catch {
      await MainActor.run {
        self.error = "Failed to start TrueDepth: \(error.localizedDescription)"
        self.statusText = "Error"
      }
      return
    }

    // No try/catch here — nothing throws in the loop.
    defer { provider.stop(); currentProvider = nil }

    var detector = RepDetector(config: currentConfig)
    var lastConfig = currentConfig
    var lastSampleT: TimeInterval?

    for await s in provider.samples {
      await MainActor.run { lastSampleWallTime = Date() }

      let cm = abs(s.cm)

      if currentConfig != lastConfig {
        detector.reset(config: currentConfig)
        await MainActor.run {
          recorder.start(heightDeltaCM: currentConfig.heightDeltaCM, startDate: Date())
        }
        lastConfig = currentConfig
        lastSampleT = nil
      }

      let events = detector.ingest(cm: cm, t: s.t)
      let snap = detector.telemetry

      if (lastSampleT == nil) || (s.t - (lastSampleT ?? s.t) >= 0.3) {
        recorder.record(sampleCM: snap.smoothedCM, threshold: snap.targetBottomCM, armed: snap.armed, t: s.t)
        lastSampleT = s.t
      }

      await MainActor.run {
        telemetry = snap
        for e in events {
          switch e {
          case .rep(let c):
            reps = c
            recorder.record(event: .rep, t: s.t)
            Haptics.repTick()
          case .warningTooFast:
            recorder.record(event: .warningTooFast, t: s.t)
            Haptics.warning()
          }
        }
      }
    }
  }

  private func endSession() {
    currentProvider?.stop()
    let session = recorder.finish(endDate: Date())
    do {
      try store.save(session)
    } catch {
      self.error = "Save failed: \(error.localizedDescription)"
    }
    onSessionSaved?(session)
    finishedSession = session
  }
}

// MARK: - Debug UI
private struct DebugPanel: View {
  let t: RepTelemetry
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label("cm \(fmt(t.smoothedCM))", systemImage: "ruler")
        Spacer()
        Text(t.armed ? "armed" : "re-arming").font(.footnote).foregroundStyle(.secondary)
      }
      HStack(spacing: 12) {
        Text("threshold \(fmt(t.targetBottomCM))")
        Text("top \(fmt(t.topCM))")
      }
      .font(.footnote.monospaced())
    }
    .padding(10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
  private func fmt(_ v: Double) -> String {
    guard v.isFinite else { return "—" }
    return String(format: "%.2f", v)
  }
}
