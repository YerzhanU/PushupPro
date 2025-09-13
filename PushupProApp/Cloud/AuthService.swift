//
//  AuthService.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


// AuthService.swift
import Foundation
import FirebaseCore
import FirebaseAuth

@MainActor
final class AuthService: ObservableObject {
  static let shared = AuthService()

  @Published private(set) var user: User?
  @Published private(set) var isAnonymous = true

  private init() {}

  /// Ensure we at least have an anonymous user and log every step.
  func ensureAnonymous() async {
    // 1) Prove Firebase is configured before we call Auth
    if FirebaseApp.app() == nil {
      print("AuthService.ensureAnonymous: FirebaseApp not configured yet")
      return
    }

    // 2) Already signed in?
    if let u = Auth.auth().currentUser {
      self.user = u
      self.isAnonymous = u.isAnonymous
      print("AuthService: already signed in uid=\(u.uid) anon=\(u.isAnonymous)")
      return
    }

    // 3) Try anonymous sign-in and LOG ERRORS
    do {
      let result = try await Auth.auth().signInAnonymously()
      self.user = result.user
      self.isAnonymous = result.user.isAnonymous
      print("AuthService: signed in anonymously uid=\(result.user.uid)")
    } catch {
      let ns = error as NSError
      print("""
      AuthService: anonymous sign-in FAILED
      code=\(ns.code) domain=\(ns.domain)
      desc=\(ns.localizedDescription)
      userInfo=\(ns.userInfo)
      """)
    }
  }

  var uid: String? { user?.uid ?? Auth.auth().currentUser?.uid }

  func signOut() throws {
    try Auth.auth().signOut()
    self.user = nil
    self.isAnonymous = true
  }
}
