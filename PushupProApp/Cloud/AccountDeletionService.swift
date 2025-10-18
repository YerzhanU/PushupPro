//
//  AccountDeletionService.swift
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UIKit

final class AccountDeletionService: NSObject {
  static let shared = AccountDeletionService()
  private override init() {}

  // MARK: - Public entry

  /// Full flow: re-auth → delete Firestore data → delete Auth user.
  /// Call this from your UI (e.g., Settings) after the user confirms.
  @MainActor
  func deleteMyAccount(presentationAnchor: ASPresentationAnchor?) async throws {
    guard let user = Auth.auth().currentUser, !user.isAnonymous else {
      throw NSError(domain: "AccountDeletion",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
    }

    // 1) Re-authenticate (required by Firebase for sensitive operations).
    try await reauthenticate(user: user, anchor: presentationAnchor)

    // 2) Delete user data in Firestore (do this BEFORE deleting the Auth user,
    //    otherwise security rules may block you).
    try await deleteUserData(uid: user.uid)

    // 3) Delete the Auth user.
    try await user.delete()
  }

  // MARK: - Re-auth dispatcher

  @MainActor
  private func reauthenticate(user: User, anchor: ASPresentationAnchor?) async throws {
    let providers = Set(user.providerData.map { $0.providerID })
    if providers.contains("apple.com") {
      try await reauthWithApple(user: user, anchor: anchor)
    } else if providers.contains("google.com") {
      #if canImport(GoogleSignIn)
      try await reauthWithGoogle(user: user)
      #else
      throw NSError(domain: "AccountDeletion",
                    code: -13,
                    userInfo: [NSLocalizedDescriptionKey: "Google re-auth not available on this build."])
      #endif
    } else {
      throw NSError(domain: "AccountDeletion",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported sign-in provider."])
    }
  }

  // MARK: - Apple re-auth (ASAuthorization + new FirebaseAuth API)

  @MainActor
  private func reauthWithApple(user: User, anchor: ASPresentationAnchor?) async throws {
    let nonce = randomNonce()
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = []            // for re-auth you typically don't need name/email
    request.nonce = sha256(nonce)

    let controller = ASAuthorizationController(authorizationRequests: [request])
    let delegate = AppleDelegate()
    delegate.anchor = anchor
    controller.delegate = delegate
    controller.presentationContextProvider = delegate

    try await delegate.perform(controller: controller)

    guard
      let idTokenData = delegate.credential?.identityToken,
      let idToken = String(data: idTokenData, encoding: .utf8)
    else {
      throw NSError(domain: "AccountDeletion",
                    code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "Missing Apple ID token"])
    }

    // New FirebaseAuth initializer *requires* fullName:. Pass the credential’s fullName or nil.
    let credential = OAuthProvider.appleCredential(
      withIDToken: idToken,
      rawNonce: nonce,
      fullName: delegate.credential?.fullName
    )

    try await user.reauthenticate(with: credential)
  }

  // MARK: - Google re-auth

  #if canImport(GoogleSignIn)
  @MainActor
  private func reauthWithGoogle(user: User) async throws {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
      throw NSError(domain: "AccountDeletion",
                    code: -13,
                    userInfo: [NSLocalizedDescriptionKey: "Missing Google client ID"])
    }

    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    guard let presenter = topViewController() else {
      throw NSError(domain: "AccountDeletion",
                    code: -14,
                    userInfo: [NSLocalizedDescriptionKey: "Presenter not found"])
    }

    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
    guard let idToken = result.user.idToken?.tokenString else {
      throw NSError(domain: "AccountDeletion",
                    code: -15,
                    userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"])
    }
    let accessToken = result.user.accessToken.tokenString

    let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
    try await user.reauthenticate(with: credential)
  }
  #endif

  // MARK: - Firestore deletion

  /// Deletes the user document and key subcollections.
  private func deleteUserData(uid: String) async throws {
    // Subcollections under /users/{uid}
    try await deleteCollection(path: "users/\(uid)/sessions")
    try await deleteCollection(path: "users/\(uid)/rollups")
    try await deleteCollection(path: "users/\(uid)/following")
    try await deleteCollection(path: "users/\(uid)/sessionMarks")

    // Delete the user profile doc
    try? await Firestore.firestore().collection("users").document(uid).delete()

    // Best-effort: remove global leaderboard entries for common periods.
    // (If a doc doesn't exist, ignore the error.)
    let (daily, monthly, yearly, allTime) = periodKeysNowUTC()
    let db = Firestore.firestore()
    for key in [daily, monthly, yearly, allTime] {
      try? await db
        .collection("leaderboards/global/periods/\(key)/entries")
        .document(uid)
        .delete()
    }
  }

  /// Batched delete for a (sub)collection path. Accepts full path like "users/{uid}/sessions".
  private func deleteCollection(path: String, batchSize: Int = 250) async throws {
    let db = Firestore.firestore()
    var lastSnapshot: DocumentSnapshot?

    while true {
      var q: Query = db.collection(path).limit(to: batchSize)
      if let lastSnapshot { q = q.start(afterDocument: lastSnapshot) }
      let snap = try await q.getDocuments()
      if snap.documents.isEmpty { break }

      let batch = db.batch()
      for doc in snap.documents { batch.deleteDocument(doc.reference) }
      try await batch.commit()

      lastSnapshot = snap.documents.last
      if snap.documents.count < batchSize { break }
    }
  }

  // MARK: - Utilities

  /// Returns daily/monthly/yearly/allTime keys in UTC to clean leaderboards.
  private func periodKeysNowUTC() -> (String, String, String, String) {
    let now = Date()
    let tzUTC = TimeZone(secondsFromGMT: 0)!
    let cal = Calendar(identifier: .iso8601)

    let df = ISO8601DateFormatter()
    df.timeZone = tzUTC
    df.formatOptions = [.withFullDate]
    let daily = "daily:\(df.string(from: now))"

    let comps = cal.dateComponents(in: tzUTC, from: now)
    let monthly = String(format: "monthly:%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    let yearly = "yearly:\(comps.year ?? 0)"
    let all = "allTime"
    return (daily, monthly, yearly, all)
  }

  private func randomNonce(length: Int = 32) -> String {
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length

    while remaining > 0 {
      var randoms = [UInt8](repeating: 0, count: 16)
      let err = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
      if err != errSecSuccess { fatalError("Unable to generate nonce. OSStatus \(err)") }

      randoms.forEach { random in
        if remaining == 0 { return }
        if random < charset.count {
          result.append(charset[Int(random)])
          remaining -= 1
        }
      }
    }
    return result
  }

  private func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hashed = SHA256.hash(data: data)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
  }

  // A simple presenter finder for Google re-auth.
  @MainActor
  private func topViewController(base: UIViewController? = UIApplication.shared
    .connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {
      if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
      if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
        return topViewController(base: selected)
      }
      if let presented = base?.presentedViewController { return topViewController(base: presented) }
      return base
    }
}

// MARK: - Apple delegate (MainActor)

@MainActor
private final class AppleDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

  fileprivate var credential: ASAuthorizationAppleIDCredential?
  fileprivate var anchor: ASPresentationAnchor?

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    anchor ?? ASPresentationAnchor()
  }

  func perform(controller: ASAuthorizationController) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      self.continuation = cont
      controller.performRequests()
    }
  }

  // MARK: ASAuthorizationControllerDelegate

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithAuthorization authorization: ASAuthorization) {
    credential = authorization.credential as? ASAuthorizationAppleIDCredential
    continuation?.resume()
    continuation = nil
  }

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithError error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }

  // Keep the continuation around while the request runs.
  private var continuation: CheckedContinuation<Void, Error>?
}
