//
//  PushupProAppApp.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct PushupProAppApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var auth = AuthService.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(auth)
        .task {
            if let app = FirebaseApp.app() {
              let o = app.options
              print("Firebase options → apiKey:\(o.apiKey)  bundleId:\(o.bundleID)")
            }
            print("Xcode bundle identifier →", Bundle.main.bundleIdentifier ?? "nil")

          // Make sure we at least have an anonymous user.
          await auth.ensureAnonymous()
          // Try to push any locally saved sessions that previously failed.
          CloudSessionSync.shared.retryQueuedUploads()
        }
    }
  }
}
