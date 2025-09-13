//
//  RootView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI
import AppUI
import Sessions
import FirebaseAuth

struct RootView: View {
    @State private var showAccount = false

    var body: some View {
    TabView {
        // Home tab: inject a LiveSessionView that reports finished sessions
        HomeView {
          LiveSessionView(onSessionSaved: { session in
            // App target owns Firebase; upload opportunistically
            CloudSessionSync.shared.upload(session)
          })
        }
        .tabItem { Label("Home", systemImage: "house.fill") }

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }

      DeveloperView()
        .tabItem { Label("Dev", systemImage: "wrench.and.screwdriver.fill") }
    }
    .sheet(isPresented: $showAccount) {
      AccountSheet()         // the sheet you already added
    }
  }
    
    @ToolbarContentBuilder
    private var accountToolbar: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showAccount = true
        } label: {
          // Filled vs outline makes it obvious when signed in (optional)
          if (try? Auth.auth().currentUser?.isAnonymous) == false {
            Image(systemName: "person.crop.circle.fill")
          } else {
            Image(systemName: "person.crop.circle")
          }
        }
        .accessibilityLabel("Account")
      }
    }
}

