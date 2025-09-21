//
//  RootView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//

//
//  RootView.swift
//  PushupProApp
//

import SwiftUI
import AppUI
import FirebaseAuth

struct RootView: View {
  @EnvironmentObject private var auth: AuthService
  @State private var showAccount = false

  var body: some View {
    TabView {
      makeHomeTab()
        .tabItem { Label("Home", systemImage: "house.fill") }

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }

      DeveloperView()
        .tabItem { Label("Dev", systemImage: "wrench.and.screwdriver.fill") }
    }
    // Force a rebuild when the signed-in user changes
    .id(Auth.auth().currentUser?.uid ?? "unsigned")
    .sheet(isPresented: $showAccount) {
      AccountSheet().environmentObject(auth)
    }
  }

  @ViewBuilder
  private func makeHomeTab() -> some View {
    HomeView(
      makeLive: {
        LiveSessionView { session in
          // Queues while unsigned; uploads when signed in
          CloudSessionSync.shared.upload(session)
        }
      },
      makeHistory: {
        AnyView(UnifiedHistoryScreen())   // ← unified merged history
      },
      onTapAccount: { showAccount = true },
      isSignedIn: !(Auth.auth().currentUser?.isAnonymous ?? true)
    )
    .environmentObject(auth)
  }
}
