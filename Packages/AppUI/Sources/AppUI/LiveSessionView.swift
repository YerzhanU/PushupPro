//
//  LiveSessionView.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import SwiftUI
import Sensing
import RepEngine

public struct LiveSessionView: View {
  // MARK: UI state
  @State private var reps = 0
  @State private var telemetry = RepTelemetry()     // ← minimal telemetry struct
  @State private var error: String?

  // Height control (manualCM = required descent from TOP, in cm)
  // You can keep/use the "Auto" toggle in the chip UI, but this detector ignores it.
  @State private var useAuto = false
  @State private var manualCM: Double = 4.0         // start with 4 cm gap as requested

  // Simulator quick toggle
  @State private var useSynthetic = false

  // Config tracking & session restarts
  @State private var currentConfig = RepConfig(heightDeltaCM: 4.0)
  @State private var sessionID = UUID()

  // Debug overlay
  @State private var showDebug = true   // turn on while tuning; set false later

  @Environment(\.dismiss) private var dismiss
  public init() {}

  public var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Header
        HStack {
          Text("Push-ups").font(.largeTitle).bold()
          Spacer()
          Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill").font(.title2)
          }
          .buttonStyle(.plain)
        }

        // Counter
        Text("\(reps)")
          .font(.system(size: 96, weight: .black, design: .rounded))

        // Depth bar (single green threshold)
        depthBar
          .frame(height: 14)
          .clipShape(RoundedRectangle(cornerRadius: 7))

        // Debug overlay (labels & numbers)
        if showDebug { DebugPanel(t: telemetry) }

        // Controls / height chip
        VStack(spacing: 12) {
          HeightChipButton(useAuto: $useAuto, manualCM: $manualCM) // UI only; detector uses manualCM
          Toggle("Use synthetic (sim)", isOn: $useSynthetic).tint(.secondary)
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
          .help(showDebug ? "Hide debug overlay" : "Show debug overlay")
        }
      }
    }
    // Seed the detector config and keep it updated
    .onAppear {
      sessionID = UUID() // new view → new run loop
      currentConfig = RepConfig(
        heightDeltaCM: manualCM,   // required drop from rolling TOP
        rearmEpsCM: 0.5,
        minRepDuration: 0.7,
        smoothingAlpha: 0.25,
        clampMinCM: 0.3, clampMaxCM: 6.0,
        topDecayPerSec: 0.6
      )
    }
    .onChange(of: manualCM) { _, v in
      currentConfig.heightDeltaCM = v
    }
    // Switching provider type requires restarting the capture task
    .onChange(of: useSynthetic) { _, _ in sessionID = UUID() }
    // Run loop restarts whenever sessionID changes
    .task(id: sessionID) { await run() }
  }

  // MARK: - Depth Bar (single green threshold)
  @ViewBuilder private var depthBar: some View {
    GeometryReader { geo in
      // Provide safe defaults until telemetry becomes valid
      let target = telemetry.targetBottomCM.isFinite ? telemetry.targetBottomCM : manualCM
      let cm = telemetry.smoothedCM.isFinite ? telemetry.smoothedCM : target

      // Window for drawing
      let minCM = max(0, target - 6)
      let maxCM = max(minCM + 0.001, target + 10)

      let x: (Double) -> CGFloat = { value in
        let n = max(0, min(1, (value - minCM) / (maxCM - minCM)))
        return CGFloat(n) * geo.size.width
      }

      ZStack(alignment: .leading) {
        Rectangle().fill(Color.gray.opacity(0.2))

        // Live marker (blue fill)
        Rectangle().fill(.blue).frame(width: max(4, x(cm)))

        // Threshold (green) – the ONLY tick we show
        Path { $0.addRect(.init(x: x(target) - 1, y: 0, width: 2, height: geo.size.height)) }
          .stroke(style: .init(lineWidth: 2))
          .foregroundStyle(.green)
      }
    }
  }

  // MARK: - Capture & detection loop
  private func run() async {
    // Reset UI for a fresh session
    await MainActor.run {
      reps = 0
      telemetry = RepTelemetry()
      error = nil
    }

    // Choose provider for this session
    let provider: any DistanceProvider = {
      if useSynthetic { return SyntheticDepthProvider() }
      #if canImport(ARKit)
      return ARKitDepthProvider()
      #else
      return SyntheticDepthProvider()
      #endif
    }()

    var detector = RepDetector(config: currentConfig)
    var lastConfig = currentConfig

    do {
      try await provider.start()
      defer { provider.stop() }

      for await s in provider.samples {
        let cm = abs(s.cm)

        // Only reset detector when config actually changes
        if currentConfig != lastConfig {
          detector.reset(config: currentConfig)
          lastConfig = currentConfig
        }

        let events = detector.ingest(cm: cm, t: s.t)
        let snap = detector.telemetry

        await MainActor.run {
          telemetry = snap
          for e in events {
            switch e {
            case .rep(let c):
              reps = c
              Haptics.repTick()
            case .warningTooFast:
              Haptics.warning()
            }
          }
        }
      }
    } catch {
      await MainActor.run { self.error = error.localizedDescription }
    }
  }
}

// MARK: - Minimal Debug panel (shows cm, threshold, top, and armed state)
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
