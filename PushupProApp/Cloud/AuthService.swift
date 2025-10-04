// AuthService.swift
import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(CryptoKit)
import CryptoKit
#endif

@MainActor
final class AuthService: ObservableObject {
  static let shared = AuthService()
  static let allowAnonymous = false

  @Published var user: User?
  @Published var isAnonymous: Bool = true
  @Published var email: String?

  private var authHandle: AuthStateDidChangeListenerHandle?

  private init() {
    authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      guard let self else { return }
      self.user = user
      self.isAnonymous = user?.isAnonymous ?? true
      self.email = user?.email
      // 👇 Make sure users/{uid} has displayName/handle; runs on app launch & any sign-in.
      if let u = user, !u.isAnonymous {
        Task { try? await ProfileService.shared.ensureProfileForCurrentUser() }
      }
      self.printAuthDiagnostics(tag: "StateListener")
    }
  }
  deinit { if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) } }

  func printAuthDiagnostics(tag: String) {
    let app = FirebaseApp.app()
    let opts = app?.options
    let u = Auth.auth().currentUser
    let providers = u?.providerData.map { $0.providerID }.joined(separator: ",") ?? "none"
    print("""
    [Diag:\(tag)]
      FirebaseApp.exists=\(app != nil)
      projectID=\(opts?.projectID ?? "nil")
      apiKey=\(opts?.apiKey ?? "nil")
      bundleID=\(opts?.bundleID ?? "nil")
      clientID=\(opts?.clientID ?? "nil")
      user.uid=\(u?.uid ?? "nil")
      user.isAnonymous=\(u?.isAnonymous ?? false)
      user.email=\(u?.email ?? "nil")
      user.providers=[\(providers)]
    """)
  }

  func ensureAnonymous() async {
    guard FirebaseApp.app() != nil else { return }
    guard Self.allowAnonymous else { return }
    if let u = Auth.auth().currentUser {
      self.user = u
      self.isAnonymous = u.isAnonymous
      return
    }
    do {
      let result = try await Auth.auth().signInAnonymously()
      self.user = result.user
      self.isAnonymous = result.user.isAnonymous
    } catch { print("[Anon] FAILED:", error.localizedDescription) }
  }

  func signOutAndBecomeGuest() async throws {
    try Auth.auth().signOut()
    self.user = nil
    self.isAnonymous = true
    if Self.allowAnonymous { await ensureAnonymous() }
  }

  var uid: String? { user?.uid ?? Auth.auth().currentUser?.uid }

  #if canImport(GoogleSignIn)
  func signInWithGoogle(presenting presenter: UIViewController) async throws {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
      throw NSError(domain: "AuthService", code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "Missing clientID"])
    }
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
    guard let idToken = result.user.idToken?.tokenString else {
      throw NSError(domain: "AuthService", code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"])
    }
    let credential = GoogleAuthProvider.credential(
      withIDToken: idToken,
      accessToken: result.user.accessToken.tokenString
    )
    try await linkOrSignIn(with: credential)
  }
  #endif

  func signInWithApple(presentationAnchor anchor: ASPresentationAnchor) async throws {
    #if !canImport(AuthenticationServices)
    throw NSError(domain: "AuthService", code: -20,
                  userInfo: [NSLocalizedDescriptionKey: "AuthenticationServices not available"])
    #else
    guard FirebaseApp.app() != nil else {
      throw NSError(domain: "AuthService", code: -21,
                    userInfo: [NSLocalizedDescriptionKey: "FirebaseApp not configured"])
    }

    let nonce = Self.randomNonceString()
    let hashed = Self.sha256(nonce)

    let provider = ASAuthorizationAppleIDProvider()
    let request = provider.createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = hashed

    let controller = ASAuthorizationController(authorizationRequests: [request])
    let delegate = AppleDelegate()
    controller.delegate = delegate
    controller.presentationContextProvider = delegate.makePresentationProvider(anchor: anchor)

    let appleIDCred: ASAuthorizationAppleIDCredential = try await delegate.perform(controller: controller)

    guard let idTokenData = appleIDCred.identityToken,
          let idTokenString = String(data: idTokenData, encoding: .utf8) else {
      throw NSError(domain: "AuthService", code: -23,
                    userInfo: [NSLocalizedDescriptionKey: "Missing Apple identity token"])
    }

    let credential = OAuthProvider.appleCredential(
      withIDToken: idTokenString,
      rawNonce: nonce,
      fullName: appleIDCred.fullName
    )

    do {
      try await linkOrSignIn(with: credential)
    } catch {
      let ns = error as NSError
      print("[Apple] Firebase link/sign-in failed \(ns.domain)#\(ns.code) \(ns.localizedDescription) userInfo=\(ns.userInfo)")
      throw error
    }
    #endif
  }

  private func linkOrSignIn(with credential: AuthCredential) async throws {
    if let u = Auth.auth().currentUser, u.isAnonymous {
      do {
        _ = try await u.link(with: credential)
        print("[Link] Linked to anonymous → uid stays \(u.uid)")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code),
           (code == .credentialAlreadyInUse || code == .emailAlreadyInUse) {
          _ = try await Auth.auth().signIn(with: credential)
          print("[Link] Credential already in use → signed in to existing account")
        } else {
          throw error
        }
      }
    } else {
      _ = try await Auth.auth().signIn(with: credential)
      print("[SignIn] Signed in with provider")
    }

    // Ensure profile (displayName/handle) after sign-in too.
    try? await ProfileService.shared.ensureProfileForCurrentUser()
    printAuthDiagnostics(tag: "PostSignIn")
  }

  private static func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    while remainingLength > 0 {
      var random: UInt8 = 0
      let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
      if status != errSecSuccess { fatalError("SecRandomCopyBytes failed") }
      if random < charset.count {
        result.append(charset[Int(random)])
        remainingLength -= 1
      }
    }
    return result
  }

  private static func sha256(_ input: String) -> String {
    guard let data = input.data(using: .utf8) else { return input }
    #if canImport(CryptoKit)
    let hashed = SHA256.hash(data: data)
    return hashed.map { String(format: "%02x", $0) }.joined()
    #else
    return input
    #endif
  }
}

#if canImport(AuthenticationServices)
private final class AppleDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
  private var anchor: ASPresentationAnchor?

  func makePresentationProvider(anchor: ASPresentationAnchor) -> ASAuthorizationControllerPresentationContextProviding {
    self.anchor = anchor
    return self
  }
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor ?? ASPresentationAnchor() }
  func perform(controller: ASAuthorizationController) async throws -> ASAuthorizationAppleIDCredential {
    try await withCheckedThrowingContinuation { cont in
      self.continuation = cont
      controller.performRequests()
    }
  }
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
      continuation?.resume(returning: cred)
    } else {
      continuation?.resume(throwing: NSError(domain: "AuthService", code: -22,
                                             userInfo: [NSLocalizedDescriptionKey: "Unexpected Apple credential"]))
    }
    continuation = nil
  }
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}
#endif
