//
//  RootView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI
import AppUI

struct RootView: View {
  var body: some View {
    TabView {
      HomeView(
        makeLive: {
          LiveSessionView(onSessionSaved: { session in
            CloudSessionSync.shared.upload(session)
          })
        },
        makeHistory: {
          AnyView(UnifiedHistoryScreen())
        }
      )
      .tabItem { Label("Home", systemImage: "house.fill") }

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }

      DeveloperView()
        .tabItem { Label("Dev", systemImage: "wrench.and.screwdriver.fill") }
    }
  }
}
