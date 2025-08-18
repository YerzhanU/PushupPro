//
//  DistanceDebugView.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI
import Sensing

/// Live distance viewer used during M1 to validate TrueDepth capture
/// and the Synthetic provider. Shows a numeric readout and a sparkline.
public struct DistanceDebugView: View {
  @Environment(\.scenePhase) private var scenePhase

  @State private var readings: [Double] = []
  @State private var latest: Double = 0
  @State private var errorMessage: String?

  // Use `any` for existential in Swift 6 mode.
  private let provider: any DistanceProvider

  /// - Parameter useSynthetic: When true, uses the synthetic generator (works in Simulator).
  public init(useSynthetic: Bool) {
    #if canImport(ARKit)
    self.provider = useSynthetic ? SyntheticDepthProvider() : ARKitDepthProvider()
    #else
    // On platforms without ARKit, always fall back to synthetic.
    self.provider = SyntheticDepthProvider()
    #endif
  }

  public var body: some View {
    VStack(spacing: 16) {
      if let msg = errorMessage {
        Text(msg)
          .font(.headline)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.vertical, 8)
      } else {
        Text(String(format: "%.1f cm", latest))
          .font(.system(size: 48, weight: .bold, design: .rounded))
        sparkline
          .frame(height: 80)
      }
      Spacer()
    }
    .padding()
    .navigationTitle("Depth Debug")
    .task { await start() }                   // kick off capture
    .onDisappear { provider.stop() }          // stop when leaving
    .onChange(of: scenePhase) { _, phase in   // simple lifecycle handling
      switch phase {
      case .background: provider.stop()
      case .active: Task { await start() }
      default: break
      }
    }
  }

  // MARK: - Private

  private func start() async {
    do {
      try await provider.start()
      errorMessage = nil
      for await s in provider.samples {
        latest = s.cm
        readings.append(s.cm)
        // keep a small rolling window to limit memory
        if readings.count > 600 { readings.removeFirst(readings.count - 600) }
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @ViewBuilder private var sparkline: some View {
    GeometryReader { geo in
      let vals = readings.suffix(150)
      Path { path in
        guard let first = vals.first else { return }
        let w = geo.size.width, h = geo.size.height
        let minV = (vals.min() ?? first) - 1
        let maxV = (vals.max() ?? first) + 1
        func y(_ v: Double) -> CGFloat {
          let n = (v - minV) / max(0.001, (maxV - minV))
          return h - h * CGFloat(n)
        }

        path.move(to: .init(x: 0, y: y(first)))
        for (i, v) in vals.enumerated() {
          let x = CGFloat(i) / CGFloat(max(1, vals.count - 1)) * w
          path.addLine(to: .init(x: x, y: y(v)))
        }
      }
      .stroke(style: .init(lineWidth: 2, lineJoin: .round))
    }
  }
}
