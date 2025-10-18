//
//  AccountSheet.swift
//  PushupProApp
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct AccountSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var auth: AuthService

  // Errors & migration
  @State private var errorMessage: String?
  @State private var showImportPrompt = false
  @State private var importCount: Int = 0
  @State private var isMigrating = false
  @State private var migrateMessage: String?

  // Deletion
  @State private var showDeleteConfirm = false
  @State private var isDeleting = false
  private let deletionService = AccountDeletionService.shared

  var body: some View {
    NavigationStack {
      Form {
        // Account header
        Section {
          if let u = auth.user, !auth.isAnonymous {
            Label(u.email ?? "Signed in", systemImage: "person.crop.circle")
            Text("UID: \(u.uid)").font(.footnote).foregroundStyle(.secondary)
          } else if auth.user != nil {
            Label("Guest", systemImage: "person.crop.circle.badge.questionmark")
          } else {
            Label("Not signed in", systemImage: "person.crop.circle.badge.exclamationmark")
          }
        }

        // Sign-in or account actions
        if auth.user == nil || auth.isAnonymous {
          Section("Sign in") {
            // Apple
            Button {
              Task {
                do {
                  try await auth.signInWithApple(presentationAnchor: topWindow() ?? .init())
                  afterSuccessfulSignIn()
                } catch { handleError(prefix: "[UI:Apple]", error) }
              }
            } label: {
              Label("Sign in with Apple", systemImage: "apple.logo")
            }

            // Google
            #if canImport(GoogleSignIn)
            Button {
              Task {
                do {
                  try await auth.signInWithGoogle(presenting: topViewController() ?? UIViewController())
                  afterSuccessfulSignIn()
                } catch { handleError(prefix: "[UI:Google]", error) }
              }
            } label: {
              Label("Sign in with Google", systemImage: "g.circle")
            }
            #endif
          }
        } else {
          // Signed-in actions
          Section {
            Button(role: .destructive) {
              Task {
                do {
                  try await auth.signOutAndBecomeGuest()
                  dismiss()
                } catch { handleError(prefix: "[UI:SignOut]", error) }
              }
            } label: {
              Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
          }

          // Account deletion (Guideline 5.1.1(v))
          Section {
            Button(role: .destructive) {
              showDeleteConfirm = true
            } label: {
              Label("Delete Account & Data", systemImage: "trash")
            }
          } footer: {
            Text("This permanently deletes your cloud data (sessions, rollups, follows, handle, leaderboard entries) and your account. You may be asked to re-authenticate.")
          }
        }

        // Inline status messages
        if let msg = errorMessage {
          Section { Text(msg).foregroundStyle(.red) }
        }
        if let msg = migrateMessage {
          Section { Text(msg).foregroundStyle(.secondary) }
        }
      }
      .navigationTitle("Account")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }

      // Prompt to import local sessions after a successful sign-in
      .alert("Import your sessions?", isPresented: $showImportPrompt) {
        Button("Import & remove", role: .destructive) {
          isMigrating = true
          Task {
            do {
              let (ok, fail) = try await MigrationCoordinator.shared
                .importAllLocalToCurrentUserDeleteLocal()
              migrateMessage = "Imported \(ok) sessions to your account.\(fail > 0 ? " \(fail) failed." : "")"
              isMigrating = false
              dismiss() // history/leaderboard reflect cloud state now
            } catch {
              handleError(prefix: "[UI:Import]", error)
              isMigrating = false
            }
          }
        }
        Button("Not now", role: .cancel) { dismiss() }
      } message: {
        Text("Found \(importCount) session\(importCount == 1 ? "" : "s") on this device. Import them into your account and remove them from this device?")
      }

      // Confirm destructive deletion
      .alert("Delete account & data?", isPresented: $showDeleteConfirm) {
        Button("Delete", role: .destructive) {
          Task { await performDeletion() }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This action is permanent. Your cloud sessions, rollups, follows, handle, leaderboard entries, and account will be deleted.")
      }

      // Busy overlay
      .overlay {
        if isMigrating || isDeleting {
          VStack(spacing: 12) {
            ProgressView(isMigrating ? "Importing…" : "Deleting…")
              .controlSize(.large)
          }
          .padding()
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
  }

  // MARK: - Helpers

  private func afterSuccessfulSignIn() {
    let count = MigrationCoordinator.shared.hasLocalSessions()
    if count > 0 {
      importCount = count
      showImportPrompt = true
    } else {
      dismiss()
    }
  }

  private func handleError(prefix: String, _ error: Error) {
    let ns = error as NSError
    errorMessage = ns.localizedDescription
    print("\(prefix) \(ns.domain)#\(ns.code) \(ns.localizedDescription) userInfo=\(ns.userInfo)")
    AuthService.shared.printAuthDiagnostics(tag: "\(prefix)-Failure")
  }

  private func performDeletion() async {
    guard let _ = Auth.auth().currentUser,
          !(Auth.auth().currentUser?.isAnonymous ?? true) else {
      errorMessage = "You must be signed in to delete your account."
      return
    }
    isDeleting = true
    defer { isDeleting = false }
    do {
      let anchor = topWindow()
      // FIXED: call the correct API name
      try await deletionService.deleteMyAccount(presentationAnchor: anchor)
      // Sign out locally after remote deletion completes
      try? await auth.signOutAndBecomeGuest()
      dismiss()
    } catch {
      handleError(prefix: "[UI:Delete]", error)
    }
  }
}

// MARK: - Presentation helpers

extension AccountSheet {
  func topWindow() -> ASPresentationAnchor? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  func topViewController(
    base baseVC: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?.rootViewController
  ) -> UIViewController? {
    if let nav = baseVC as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = baseVC as? UITabBarController,
       let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }
    if let presented = baseVC?.presentedViewController {
      return topViewController(base: presented)
    }
    return baseVC
  }
}
