//
//  CloudAuth.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import Foundation
import FirebaseCore
import FirebaseAuth

/// Minimal observable auth (email/password).
final class CloudAuth: ObservableObject {
  static let shared = CloudAuth()

  @Published private(set) var uid: String?
  @Published private(set) var email: String?

  private var handle: AuthStateDidChangeListenerHandle?

  private init() {
    // Do NOT call Auth here (Firebase may not be configured yet).
  }

  /// Attach the Firebase auth state listener (idempotent).
  func start() {
    // If Firebase isn't configured yet, try again on the next runloop tick.
    guard FirebaseApp.app() != nil else {
      DispatchQueue.main.async { [weak self] in self?.start() }
      return
    }
    guard handle == nil else { return }
    handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      self?.uid = user?.uid
      self?.email = user?.email
    }
  }

  deinit { if let h = handle { Auth.auth().removeStateDidChangeListener(h) } }

  // MARK: Flows
  func signUp(email: String, password: String) async throws {
    _ = try await Auth.auth().createUser(withEmail: email, password: password)
  }
  func signIn(email: String, password: String) async throws {
    _ = try await Auth.auth().signIn(withEmail: email, password: password)
  }
  func signOut() throws { try Auth.auth().signOut() }
}
