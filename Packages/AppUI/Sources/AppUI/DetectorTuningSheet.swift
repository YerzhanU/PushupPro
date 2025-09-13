//
//  DetectorTuningSheet.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import SwiftUI

/// Sheet for tuning the single-threshold detector.
/// All values are in centimeters unless stated otherwise.
public struct DetectorTuningSheet: View {
  @Binding var heightDeltaCM: Double
  @Binding var rearmEpsCM: Double
  @Binding var minRepDuration: Double
  @Binding var smoothingAlpha: Double
  @Binding var topDecayPerSec: Double
  @Binding var showDebug: Bool

  var onSaveDefaults: (() -> Void)?
  var onResetSession: (() -> Void)?
  var onRestoreFactoryDefaults: (() -> Void)?   // NEW

  public init(
    heightDeltaCM: Binding<Double>,
    rearmEpsCM: Binding<Double>,
    minRepDuration: Binding<Double>,
    smoothingAlpha: Binding<Double>,
    topDecayPerSec: Binding<Double>,
    showDebug: Binding<Bool>,
    onSaveDefaults: (() -> Void)? = nil,
    onResetSession: (() -> Void)? = nil,
    onRestoreFactoryDefaults: (() -> Void)? = nil   // NEW
  ) {
    self._heightDeltaCM = heightDeltaCM
    self._rearmEpsCM = rearmEpsCM
    self._minRepDuration = minRepDuration
    self._smoothingAlpha = smoothingAlpha
    self._topDecayPerSec = topDecayPerSec
    self._showDebug = showDebug
    self.onSaveDefaults = onSaveDefaults
    self.onResetSession = onResetSession
    self.onRestoreFactoryDefaults = onRestoreFactoryDefaults
  }

  public var body: some View {
    VStack(spacing: 18) {
      Capsule().frame(width: 40, height: 4).foregroundStyle(.tertiary)
      Text("Detector Settings").font(.title3).bold()

      // Core
      Group {
        row("Height drop (green)") {
          Text("\(heightDeltaCM, specifier: "%.1f") cm").monospacedDigit()
        }
        Slider(value: $heightDeltaCM, in: 1.0...6.0, step: 0.1)

        row("Re-arm window") {
          Text("\(rearmEpsCM, specifier: "%.1f") cm").monospacedDigit()
        }
        Slider(value: $rearmEpsCM, in: 0.2...2.0, step: 0.1)

        row("Min rep duration") {
          Text("\(minRepDuration, specifier: "%.1f") s").monospacedDigit()
        }
        Slider(value: $minRepDuration, in: 0.4...1.2, step: 0.1)
      }

      // Advanced
      DisclosureGroup("Advanced") {
        VStack(alignment: .leading, spacing: 14) {
          row("Smoothing α") { Text("\(smoothingAlpha, specifier: "%.2f")").monospacedDigit() }
          Slider(value: $smoothingAlpha, in: 0.10...0.50, step: 0.01)

          row("Top decay") { Text("\(topDecayPerSec, specifier: "%.2f") cm/s").monospacedDigit() }
          Slider(value: $topDecayPerSec, in: 0.0...1.5, step: 0.05)

          Toggle("Show debug overlay", isOn: $showDebug).tint(.secondary)
        }
        .padding(.top, 6)
      }

      // Actions
      VStack(spacing: 10) {
        HStack {
          Button(role: .destructive) {
            onResetSession?()
          } label: {
            Label("Reset session", systemImage: "arrow.counterclockwise")
          }

          Spacer()

          Button {
            onSaveDefaults?()
          } label: {
            Label("Save as default", systemImage: "square.and.arrow.down")
          }
          .buttonStyle(.borderedProminent)
        }

        // NEW: Restore factory defaults (resets saved defaults + current values)
        Button(role: .destructive) {
          onRestoreFactoryDefaults?()
        } label: {
          Label("Restore factory defaults", systemImage: "arrow.uturn.backward")
        }
      }
    }
    .padding(20)
  }

  @ViewBuilder
  private func row(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
    HStack {
      Text(title)
      Spacer()
      trailing()
    }
  }
}
