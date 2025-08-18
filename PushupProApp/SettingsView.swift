//
//  SettingsView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI

public struct SettingsView: View {
  public init() {}
  public var body: some View {
    Form {
      Section("General") {
        Toggle("Haptics", isOn: .constant(true))
        Picker("Units", selection: .constant(0)) {
          Text("Metric").tag(0); Text("Imperial").tag(1)
        }
      }
      Section {
        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
      }
    }
    .navigationTitle("Settings")
  }
}
