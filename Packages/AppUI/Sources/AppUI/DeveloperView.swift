//
//  DeveloperView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI

public struct DeveloperView: View {
  @State private var useSynthetic = false
  public init() {}
  public var body: some View {
    NavigationStack {
      Form {
        Section("Feature flags") {
          Toggle("Use Synthetic Depth", isOn: $useSynthetic)
        }
        Section {
          NavigationLink("Depth Debug") {
            DistanceDebugView(useSynthetic: useSynthetic)
          }
        }
      }
      .navigationTitle("Developer")
    }
  }
}
