//
//  HeightControls.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import SwiftUI

public struct HeightControls: View {
  @Binding var useAuto: Bool
  @Binding var manualCM: Double

  public init(useAuto: Binding<Bool>, manualCM: Binding<Double>) {
    _useAuto = useAuto; _manualCM = manualCM
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle("Automatic height", isOn: $useAuto)
      if !useAuto {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Target bottom: \(Int(manualCM)) cm")
            Spacer()
          }
          Slider(value: $manualCM, in: 5...25, step: 1)
          Text("Vision can vary by angle & lighting. If reps don’t count, try **1–2 cm lower**.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      } else {
        Text("We’ll auto-learn your top and bottom during the first seconds of your set.")
          .font(.footnote).foregroundStyle(.secondary)
      }
    }
    .padding()
    .presentationDetents([.height(260), .medium])
  }
}

public struct HeightChipButton: View {
  @Binding var useAuto: Bool
  @Binding var manualCM: Double
  @State private var showing = false
  public init(useAuto: Binding<Bool>, manualCM: Binding<Double>) { _useAuto = useAuto; _manualCM = manualCM }
  public var body: some View {
    Button {
      showing = true
    } label: {
      HStack {
        Image(systemName: "arrow.up.and.down.circle")
        Text(useAuto ? "Height: Auto" : "Height: \(Int(manualCM)) cm")
        Spacer()
      }
      .padding(12)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    .sheet(isPresented: $showing) {
      HeightControls(useAuto: $useAuto, manualCM: $manualCM)
        .presentationDragIndicator(.visible)
    }
  }
}
