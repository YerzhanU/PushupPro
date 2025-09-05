//
//  LiveSessionView.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


//
//  LiveSessionView.swift
//  AppUI
//

import SwiftUI
import Sensing
import RepEngine
import Sessions

public struct LiveSessionView: View {
  // MARK: UI state
  @State private var reps = 0
  @State private var telemetry = RepTelemetry()
  @State private var error: String?

  // Height control = required descent from rolling TOP (cm)
  @State private var manualCM: Double = 3.0     // good default for 0.9↔︎4.0cm swing

  // Simulator quick toggle
  @State private var useSynthetic = false

  // Config / session
  @State private var currentConfig = RepConfig(heightDeltaCM: 3.0)
  @State private var sessionID = UUID()
  @State private var finishedSession: Sessions.Session?
  @State private var showDebug = true

  // Recording & storage
  @State private var recorder = SessionRecorder()
  @State private var store = SessionStore()
  @State private var currentProvider: (any DistanceProvider)?

  @Environment(\.dismiss) private var dismiss
  public init() {}

  public var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Header
        HStack {
          Text("Push-ups").font(.largeTitle).bold()
          Spacer()
          Button("End") { endSession() }
            .buttonStyle(.borderedProminent)
          Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
            .buttonStyle(.plain)
        }

        // Counter
        Text("\(reps)")
          .font(.system(size: 96, weight: .black, design: .rounded))

        // Depth bar (single green threshold)
        depthBar
          .frame(height: 14)
          .clipShape(RoundedRectangle(cornerRadius: 7))

        if showDebug { DebugPanel(t: telemetry) }

        // Controls
        VStack(spacing: 12) {
          HeightChipButton(useAuto: .constant(false), manualCM: $manualCM)
          Toggle("Use synthetic (sim)", isOn: $useSynthetic).tint(.secondary)
          Text("Height (drop from top): \(String(format: "%.1f", manualCM)) cm")
            .font(.footnote).foregroundStyle(.secondary)
        }

        if let error {
          Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
        }
        Spacer()
      }
      .padding()
      .navigationTitle("Session")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showDebug.toggle() } label: {
            Image(systemName: showDebug ? "eye.trianglebadge.exclamationmark.fill" : "eye")
          }
        }
      }
      .navigationDestination(item: $finishedSession) { (sess: Sessions.Session) in
        SessionSummaryView(session: sess, onDone: { dismiss() })
      }
    }
    // Seed config and keep it in sync
    .onAppear {
      sessionID = UUID()
      currentConfig = RepConfig(
        heightDeltaCM: manualCM,
        rearmEpsCM: 0.5,
        minRepDuration: 0.7,
        smoothingAlpha: 0.25,
        clampMinCM: 0.3, clampMaxCM: 6.0,
        topDecayPerSec: 0.6
      )
    }
    .onChange(of: manualCM) { _, v in currentConfig.heightDeltaCM = v }
    .onChange(of: useSynthetic) { _, _ in sessionID = UUID() } // restart loop
    .task(id: sessionID) { await run() }
  }

  // MARK: - Depth Bar (single green threshold)
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
          .stroke(style: .init(lineWidth: 2)).foregroundStyle(.green)
      }
    }
  }

  // MARK: - Loop
  private func run() async {
    // reset UI & recorder
    await MainActor.run {
      reps = 0
      telemetry = RepTelemetry()
      error = nil
      recorder.start(heightDeltaCM: currentConfig.heightDeltaCM, startDate: Date())
    }

    // Pick provider
    let provider: any DistanceProvider = {
      if useSynthetic { return SyntheticDepthProvider() }
      #if canImport(ARKit)
      return ARKitDepthProvider()
      #else
      return SyntheticDepthProvider()
      #endif
    }()
    currentProvider = provider

    var detector = RepDetector(config: currentConfig)
    var lastConfig = currentConfig
    var lastSampleT: TimeInterval?

    do {
      try await provider.start()
      defer { provider.stop(); currentProvider = nil }

      for await s in provider.samples {
        let cm = abs(s.cm)

        if currentConfig != lastConfig {
          detector.reset(config: currentConfig)
          await MainActor.run { recorder.start(heightDeltaCM: currentConfig.heightDeltaCM, startDate: Date()) }
          lastConfig = currentConfig
          lastSampleT = nil
        }

        let events = detector.ingest(cm: cm, t: s.t)
        let snap = detector.telemetry

        // Downsample telemetry to ~3–4 Hz into the recorder
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
    } catch {
      await MainActor.run { self.error = error.localizedDescription }
    }
  }

  private func endSession() {
    currentProvider?.stop() // this will break the loop soon
    let session = recorder.finish(endDate: Date())
    do {
      try store.save(session)
    } catch {
      self.error = "Save failed: \(error.localizedDescription)"
    }
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
