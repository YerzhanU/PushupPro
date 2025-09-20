//
//  PushupProAppApp.swift
//  PushupProApp
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct PushupProAppApp: App {
  @StateObject private var auth: AuthService

  init() {
    // 1) Configure Firebase FIRST
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    if let app = FirebaseApp.app() {
      let o = app.options
      print("""
      [Bootstrap] FirebaseApp configured
        apiKey=\(String(describing: o.apiKey))
        projectID=\(o.projectID ?? "nil")
        gcmSenderID=\(o.gcmSenderID ?? "nil")
        bundleID=\(o.bundleID)
        clientID=\(o.clientID ?? "nil")
      """)
    } else {
      print("[Bootstrap] FirebaseApp.configure() FAILED (app == nil)")
    }

    // 2) NOW create the AuthService (after configure)
    _auth = StateObject(wrappedValue: AuthService.shared)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(auth)
        .task {
          // Print diagnostics at startup
          AuthService.shared.printAuthDiagnostics(tag: "AppLaunch")

          // ⛔️ Do NOT create anonymous user while debugging
          // await auth.ensureAnonymous()

          // 🔥 Purge any persisted anonymous user so we start clean
          if let u = Auth.auth().currentUser, u.isAnonymous {
            do {
              try Auth.auth().signOut()
              print("[Startup] Signed out persisted anonymous user \(u.uid)")
            } catch {
              let ns = error as NSError
              print("[Startup] Sign out anon FAILED \(ns.domain)#\(ns.code): \(ns.localizedDescription)")
            }
          }

          // Background sync only for real signed-in users
          if let u = Auth.auth().currentUser, !u.isAnonymous {
            CloudSessionSync.shared.retryQueuedUploads()
            CloudSessionSync.shared.backfillAll()
          }

          // Extra logging on any auth state changes
          Auth.auth().addStateDidChangeListener { _, user in
            print("[AuthState] change → uid=\(user?.uid ?? "nil")  isAnon=\(user?.isAnonymous ?? false)  email=\(user?.email ?? "nil")")
            if let u = user, !u.isAnonymous {
              CloudSessionSync.shared.retryQueuedUploads()
              CloudSessionSync.shared.backfillAll()
            }
          }
        }
    }
  }
}
