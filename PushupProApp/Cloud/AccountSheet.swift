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

  var body: some View {
    NavigationStack {
      Form {
        // Header: show account / guest state
        Section {
          if let u = auth.user, !auth.isAnonymous {
            Label(u.email ?? "Signed in", systemImage: "person.crop.circle")
            Text("UID: \(u.uid)")
              .font(.footnote)
              .foregroundStyle(.secondary)
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
                  dismiss()
                } catch {
                  let ns = error as NSError
                  errorMessage = ns.localizedDescription
                  print("[UI:Apple] \(ns.domain)#\(ns.code) \(ns.localizedDescription) userInfo=\(ns.userInfo)")
                  AuthService.shared.printAuthDiagnostics(tag: "UI-Apple-Failure")
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
                  dismiss()
                } catch {
                  let ns = error as NSError
                  errorMessage = ns.localizedDescription
                  print("[UI:Google] \(ns.domain)#\(ns.code) \(ns.localizedDescription) userInfo=\(ns.userInfo)")
                  AuthService.shared.printAuthDiagnostics(tag: "UI-Google-Failure")
                }
              }
            } label: {
              Label("Sign in with Google", systemImage: "g.circle")
            }
            #endif
          }
        } else {
          // Signed-in → allow sign out (returns to Guest if you later re-enable Guest)
          Section {
            Button(role: .destructive) {
              Task {
                do {
                  try await auth.signOutAndBecomeGuest()
                  dismiss()
                } catch {
                  let ns = error as NSError
                  errorMessage = ns.localizedDescription
                  print("[UI:SignOut] \(ns.domain)#\(ns.code) \(ns.localizedDescription) userInfo=\(ns.userInfo)")
                }
              }
            } label: {
              Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
          }
        }

        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle("Account")
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
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
