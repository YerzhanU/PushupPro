//
//  AuthService.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import Foundation
import FirebaseAuth

@MainActor
final class AuthService: ObservableObject {
  static let shared = AuthService()

  @Published private(set) var user: User?         // FirebaseAuth.User
  @Published private(set) var isAnonymous = true  // true for anonymous

  private init() {
  }

    @MainActor
  /// Ensure we at least have an anonymous user.
  func ensureAnonymous() async {
    if Auth.auth().currentUser == nil {
      _ = try? await Auth.auth().signInAnonymously()
    }
  }

  var uid: String? { Auth.auth().currentUser?.uid }

  // Upgrade flows (wire later):
  func signInWithApple() async throws { /* TODO */ }
  func signInWithGoogle() async throws { /* TODO */ }
  func signOut() throws { try Auth.auth().signOut() }
}
