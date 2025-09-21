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

  @State private var errorMessage: String?
  @State private var showImportPrompt = false
  @State private var importCount: Int = 0
  @State private var isMigrating = false
  @State private var migrateMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        // Header: account state
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

        // Sign-in options
        if auth.user == nil || auth.isAnonymous {
          Section("Sign in") {
            // Apple
            Button {
              Task {
                do {
                  try await auth.signInWithApple(presentationAnchor: topWindow() ?? .init())
                  afterSuccessfulSignIn()
                } catch {
                  handleError(prefix: "[UI:Apple]", error)
                }
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
                } catch {
                  handleError(prefix: "[UI:Google]", error)
                }
              }
            } label: {
              Label("Sign in with Google", systemImage: "g.circle")
            }
            #endif
          }
        } else {
          // Signed-in → allow sign out
          Section {
            Button(role: .destructive) {
              Task {
                do {
                  try await auth.signOutAndBecomeGuest()
                  dismiss()
                } catch {
                  handleError(prefix: "[UI:SignOut]", error)
                }
              }
            } label: {
              Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
          }
        }

        if let msg = errorMessage {
          Section { Text(msg).foregroundStyle(.red) }
        }

        if let msg = migrateMessage {
          Section { Text(msg).foregroundStyle(.secondary) }
        }
      }
      .navigationTitle("Account")
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
      .alert("Import your sessions?", isPresented: $showImportPrompt) {
        Button("Import & remove", role: .destructive) {
          isMigrating = true
          Task {
            do {
              let (ok, fail) = try await MigrationCoordinator.shared.importAllLocalToCurrentUserDeleteLocal()
              migrateMessage = "Imported \(ok) sessions to your account.\(fail > 0 ? " \(fail) failed." : "")"
              isMigrating = false
              dismiss() // close sheet; history will show cloud now
            } catch {
              handleError(prefix: "[UI:Import]", error)
              isMigrating = false
            }
          }
        }
        Button("Not now", role: .cancel) {
          // Keep local sessions; user can import later from Settings if you add an entry.
          dismiss()
        }
      } message: {
        Text("Found \(importCount) session\(importCount == 1 ? "" : "s") on this device. Import them into your account and remove them from this device?")
      }
      .overlay {
        if isMigrating {
          ProgressView("Importing…").padding().background(.ultraThinMaterial).cornerRadius(12)
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
}

// MARK: - Presentation helpers

extension AccountSheet {
  func topWindow() -> ASPresentationAnchor? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  func topViewController(base baseVC: UIViewController? = UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {

    if let nav = baseVC as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }
    if let presented = baseVC?.presentedViewController {
      return topViewController(base: presented)
    }
    return baseVC
  }
}
