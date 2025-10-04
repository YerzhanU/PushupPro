//
//  ProfileService.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 04/10/2025.
//


// ProfileService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore

final class ProfileService {
  static let shared = ProfileService()
  private init() {}
  private let db = Firestore.firestore()

  /// Ensures users/{uid} exists with displayName/handle/photo.
  /// Also reserves handles/{handle} on first run.
  @MainActor
  func ensureProfileForCurrentUser() async throws {
    guard let u = Auth.auth().currentUser, !u.isAnonymous else { return }

    let usersRef = db.collection("users").document(u.uid)
    let snap = try await usersRef.getDocument()

    var display = (u.displayName ?? u.email?.components(separatedBy: "@").first ?? "User")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if display.isEmpty { display = "User" }

    var data: [String: Any] = [
      "displayName": display,
      "updatedAt": FieldValue.serverTimestamp()
    ]
    if let url = u.photoURL?.absoluteString { data["photoURL"] = url }
    if !snap.exists { data["createdAt"] = FieldValue.serverTimestamp() }

    // On first profile create, pick & reserve a unique @handle
    if !(snap.exists), (snap.get("handle") as? String) == nil {
      let preferred = Self.slugify(display)
      let handle = try await reserveHandle(uid: u.uid, preferred: preferred)
      data["handle"] = handle
    }

    try await usersRef.setData(data, merge: true)
  }

  private func reserveHandle(uid: String, preferred: String) async throws -> String {
    let base = preferred.isEmpty ? "user" : preferred
    let handles = db.collection("handles")
    var attempt = base
    for i in 0..<25 {
      if i > 0 { attempt = "\(base)\(Int.random(in: 100...999))" }
      let hRef = handles.document(attempt)
      let s = try await hRef.getDocument()
      if !s.exists {
        try await hRef.setData(["uid": uid])
        return attempt
      }
    }
    let fallback = "\(base)\(Int(Date().timeIntervalSince1970))"
    try await handles.document(fallback).setData(["uid": uid])
    return fallback
  }

  private static func slugify(_ s: String) -> String {
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
    let lower = s.lowercased()
    var out = ""
    for ch in lower {
      if allowed.contains(ch) { out.append(ch) }
      else if ch.isWhitespace { out.append("_") }
    }
    out = out.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    return out.isEmpty ? "user" : out
  }

  // Simple one-shot load of a profile
  func loadProfile(uid: String) async throws -> (displayName: String?, handle: String?, photoURL: String?) {
    let doc = try await db.collection("users").document(uid).getDocument()
    return (
      displayName: doc.get("displayName") as? String,
      handle: doc.get("handle") as? String,
      photoURL: doc.get("photoURL") as? String
    )
  }
}
