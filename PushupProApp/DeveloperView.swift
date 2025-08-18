//
//  DeveloperView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI

public struct DeveloperView: View {
  public init() {}
  public var body: some View {
    Form {
      Section("Feature flags") {
        Toggle("Use Synthetic Depth", isOn: .constant(true))
        Toggle("Enable Dev Overlay", isOn: .constant(true))
      }
      Section("Build") {
        Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")")
      }
    }
    .navigationTitle("Developer")
  }
}
