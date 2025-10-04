//  LiveSessionView.swift
//  AppUI

import SwiftUI
import Sensing
import RepEngine
import Sessions
#if canImport(ARKit)
import ARKit
#endif
#if os(iOS)
import UIKit
#endif

public struct LiveSessionView: View {
  // MARK: Injection
  private let onSessionSaved: ((Sessions.Session) -> Void)?
  private let saveLocally: Bool

  // MARK: Persisted defaults
  @AppStorage("pp_heightCM")        private var storedHeight: Double = 3.0
  @AppStorage("pp_rearmEpsCM")      private var storedRearmEps: Double = 0.5
  @AppStorage("pp_smoothingAlpha")  private var storedAlpha: Double = 0.25
  @AppStorage("pp_minRepDuration")  private var storedMinRep: Double = 0.7
  @AppStorage("pp_topDecayPerSec")  private var storedDecay: Double = 0.6
  @AppStorage("pp_showDebug")       private var storedShowDebug: Bool = true

  // MARK: Live UI state
  @State private var reps = 0
  @State private var telemetry = RepTelemetry()
  @State private var error: String?
  @State private var providerLabel = "—"

  // Tunables bound to the sheet
  @State private var manualCM: Double = 3.0
  @State private var rearmEpsCM: Double = 0.5
  @State private var smoothingAlpha: Double = 0.25
  @State private var minRepDuration: Double = 0.7
  @State private var topDecayPerSec: Double = 0.6

  @State private var currentConfig = RepConfig(heightDeltaCM: 3.0)

  // Session
  @State private var sessionID = UUID()
  @State private var finishedSession: Sessions.Session?
  @State private var showDebug = true
  @State private var showSettings = false

  // Recording & provider
  @State private var recorder = SessionRecorder()
  @State private var store = SessionStore()
  @State private var currentProvider: (any DistanceProvider)?
  @State private var lastSampleWallTime: Date?

  // Subtle status control
  private enum Phase: Equatable { case initializing, live, noSignal, error }
  @State private var phase: Phase = .initializing
  @State private var statusVisible = true
  @State private var startedAt = Date()
  private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  @Environment(\.dismiss) private var dismiss

  public init(
    onSessionSaved: ((Sessions.Session) -> Void)? = nil,
    saveLocally: Bool = true
  ) {
    self.onSessionSaved = onSessionSaved
    self.saveLocally = saveLocally
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        // Header
        HStack {
          Text("Push-ups").font(.largeTitle).bold()
          Spacer()
          Button("End") { endSession() }
            .buttonStyle(.borderedProminent)
          Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill").font(.title2)
          }
          .buttonStyle(.plain)
        }

        // Status line (auto-hides while stable)
        if statusVisible {
          HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusText).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Text(providerLabel).font(.footnote).foregroundStyle(.secondary)
          }
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
          .transition(.opacity.combined(with: .move(edge: .top)))
        }

        // Big counter
        Text("\(reps)")
          .font(.system(size: 96, weight: .black, design: .rounded))
          .monospacedDigit()

        // Depth bar
        depthBar
          .frame(height: 14)
          .clipShape(RoundedRectangle(cornerRadius: 7))

        // Advanced settings entry (under the bar)
        Button {
          showSettings = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
            Text("Advanced settings")
          }
          .font(.footnote)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.gray.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)

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
      // Load defaults into live state
      manualCM        = storedHeight
      rearmEpsCM      = storedRearmEps
      smoothingAlpha  = storedAlpha
      minRepDuration  = storedMinRep
      topDecayPerSec  = storedDecay
      showDebug       = storedShowDebug
      refreshConfig()

      sessionID = UUID()
      startedAt = Date()
      phase = .initializing
      statusVisible = true
      providerLabel = "—"

      #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = true
      #endif
    }
    .onDisappear {
      currentProvider?.stop()
      currentProvider = nil
      #if os(iOS)
      UIApplication.shared.isIdleTimerDisabled = false
      #endif
    }
    .sheet(isPresented: $showSettings) {
      SettingsSheet(
        heightCM: $manualCM,
        rearmEpsCM: $rearmEpsCM,
        smoothingAlpha: $smoothingAlpha,
        minRepDuration: $minRepDuration,
        topDecayPerSec: $topDecayPerSec,
        showDebug: $showDebug,
        onApply: {
          // Persist choices
          storedHeight = manualCM
          storedRearmEps = rearmEpsCM
          storedAlpha = smoothingAlpha
          storedMinRep = minRepDuration
          storedDecay = topDecayPerSec
          storedShowDebug = showDebug
          // Update config (loop will reset detector)
          refreshConfig()
        }
      )
      .presentationDetents([.medium, .large])
    }
    .onChange(of: manualCM)       { _ in refreshConfig() }
    .onChange(of: rearmEpsCM)     { _ in refreshConfig() }
    .onChange(of: smoothingAlpha) { _ in refreshConfig() }
    .onChange(of: minRepDuration) { _ in refreshConfig() }
    .onChange(of: topDecayPerSec) { _ in refreshConfig() }
    .onReceive(ticker) { _ in tickPhase() }
    .task(id: sessionID) { await run() }
  }

  // MARK: Status helpers
  private var statusText: String {
    switch phase {
    case .initializing: return "Preparing…"
    case .live:         return "Live"
    case .noSignal:     return "Hold steady"
    case .error:        return "Error"
    }
  }
  private var statusColor: Color {
    switch phase {
    case .initializing: return .yellow
    case .live:         return .green
    case .noSignal:     return .orange
    case .error:        return .red
    }
  }
  private func tickPhase() {
    let newPhase: Phase
    if error != nil { newPhase = .error }
    else if hasRecentSample { newPhase = .live }
    else if Date().timeIntervalSince(startedAt) < 2.0 { newPhase = .initializing }
    else { newPhase = .noSignal }

    if newPhase != phase {
      phase = newPhase
      if newPhase == .live {
        // Auto-hide after 2s of stable live
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          if self.phase == .live { withAnimation { self.statusVisible = false } }
        }
      } else {
        withAnimation { statusVisible = true }
      }
    } else if newPhase == .noSignal {
      withAnimation { statusVisible = true }
    }
  }

  private func refreshConfig() {
    currentConfig = RepConfig(
      heightDeltaCM: manualCM,
      rearmEpsCM: rearmEpsCM,
      minRepDuration: minRepDuration,
      smoothingAlpha: smoothingAlpha,
      clampMinCM: 0.3,
      clampMaxCM: 6.0,
      topDecayPerSec: topDecayPerSec
    )
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
      self.phase = .error
    }
    return
    #else
    if !ARFaceTrackingConfiguration.isSupported {
      await MainActor.run {
        self.error = "This device doesn’t support TrueDepth face tracking."
        self.phase = .error
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
        startedAt = Date()
        phase = .initializing
      }
    } catch {
      await MainActor.run {
        self.error = "Failed to start TrueDepth: \(error.localizedDescription)"
        self.phase = .error
      }
      return
    }

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

    if saveLocally {
      do { try store.save(session) }
      catch { self.error = "Save failed: \(error.localizedDescription)" }
    }

    onSessionSaved?(session)
    finishedSession = session
  }
}

// MARK: - Settings sheet
private struct SettingsSheet: View {
  @Environment(\.dismiss) private var dismiss

  @Binding var heightCM: Double
  @Binding var rearmEpsCM: Double
  @Binding var smoothingAlpha: Double
  @Binding var minRepDuration: Double
  @Binding var topDecayPerSec: Double
  @Binding var showDebug: Bool

  var onApply: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("Push-up height (bottom target)") {
          HStack {
            Slider(value: $heightCM, in: 1...10, step: 0.1)
            Text(String(format: "%.1f cm", heightCM)).monospaced()
          }
          Text("Set how deep you must go to count a rep.")
            .font(.footnote).foregroundStyle(.secondary)
        }

        Section("Detection tuning") {
          LabeledContent("Re-arm epsilon") {
            Stepper(value: $rearmEpsCM, in: 0.1...2.0, step: 0.1) {
              Text(String(format: "%.1f cm", rearmEpsCM)).monospaced()
            }
          }
          LabeledContent("Smoothing α") {
            Stepper(value: $smoothingAlpha, in: 0.05...0.6, step: 0.05) {
              Text(String(format: "%.2f", smoothingAlpha)).monospaced()
            }
          }
          LabeledContent("Min rep duration") {
            Stepper(value: $minRepDuration, in: 0.3...2.0, step: 0.1) {
              Text(String(format: "%.1f s", minRepDuration)).monospaced()
            }
          }
          LabeledContent("Top decay / sec") {
            Stepper(value: $topDecayPerSec, in: 0.1...1.5, step: 0.1) {
              Text(String(format: "%.1f", topDecayPerSec)).monospaced()
            }
          }
        }

        Section {
          Toggle("Show debug panel", isOn: $showDebug)
        }
      }
      .navigationTitle("Session Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            onApply()
            dismiss()
          }
        }
      }
    }
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
