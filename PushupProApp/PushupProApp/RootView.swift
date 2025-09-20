//
//  RootView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//

import SwiftUI
import AppUI
import FirebaseAuth   // ← fixes: Cannot find 'Auth' in scope

struct RootView: View {
  @EnvironmentObject private var auth: AuthService
  @State private var showAccount = false

  var body: some View {
    TabView {
      // HOME
      makeHomeTab()
        .tabItem { Label("Home", systemImage: "house.fill") }

      // SETTINGS
      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }

      // DEV
      DeveloperView()
        .tabItem { Label("Dev", systemImage: "wrench.and.screwdriver.fill") }
    }
    // Rebuild the tab when auth changes so History switches source seamlessly
    .id(auth.user?.uid ?? "guest")
    .sheet(isPresented: $showAccount) {
      AccountSheet().environmentObject(auth)
    }
  }

  @ViewBuilder
  private func makeHomeTab() -> some View {
    // Unified local list; uploads are silent when signed in
    HomeView(
      makeLive: {
        LiveSessionView { session in
          // Queue while Guest; upload when signed in
          CloudSessionSync.shared.upload(session)
        }
      },
      makeHistory: {
        // Always local list (single source of truth for UI)
        let client = HistoryClient.localOnly()
        return AnyView(HistoryView(client: client))
      },
      onTapAccount: { showAccount = true },
      isSignedIn: !(Auth.auth().currentUser?.isAnonymous ?? true)
    )
    .environmentObject(auth)
  }
}
