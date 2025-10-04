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
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//

import SwiftUI
import AppUI
import FirebaseAuth

struct RootView: View {
  @EnvironmentObject private var auth: AuthService
  @State private var showAccount = false

  // Local flags so we don't collide with any existing FeatureFlags type.
  private enum Flags {
    static let showSettingsTab = false
    static let showDevTab      = false
  }

  private var isSignedIn: Bool {
    let u = Auth.auth().currentUser
    return u != nil && !(u?.isAnonymous ?? true)
  }

  var body: some View {
    TabView {
      makeHomeTab()
        .tabItem { Label("Home", systemImage: "house.fill") }

      // Leaderboard: gated to signed-in users; otherwise show a sign-in prompt tab
      if isSignedIn {
        LeaderboardScreen()
          .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
      } else {
        Button { showAccount = true } label: {
          Text("Sign in to view Leaderboard")
        }
        .tabItem { Label("Leaderboard", systemImage: "trophy") }
      }

      // Hidden tabs (flip flags to true to bring back)
      if Flags.showSettingsTab {
        SettingsView()
          .tabItem { Label("Settings", systemImage: "gearshape.fill") }
      }
      if Flags.showDevTab {
        DeveloperView()
          .tabItem { Label("Dev", systemImage: "wrench.and.screwdriver.fill") }
      }
    }
    .sheet(isPresented: $showAccount) {
      AccountSheet().environmentObject(auth)
    }
  }

  @ViewBuilder
  private func makeHomeTab() -> some View {
    HomeView(
      makeLive: {
        // Save locally only for Guests; when signed in, upload only.
        LiveSessionView(
          onSessionSaved: { session in
            CloudSessionSync.shared.upload(session) // queues if Guest
          },
          saveLocally: (Auth.auth().currentUser?.isAnonymous ?? true)
        )
      },
      makeHistory: { AnyView(UnifiedHistoryScreen()) },
      onTapAccount: { showAccount = true },
      isSignedIn: isSignedIn
    )
    .environmentObject(auth)
  }
}
