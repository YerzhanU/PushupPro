//
//  FollowsService.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 04/10/2025.
//


// FollowsService.swift
// PushupProApp

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum FollowsService {
  private static var db: Firestore { Firestore.firestore() }

  private static var myUid: String {
    guard let u = Auth.auth().currentUser, !u.isAnonymous else {
      fatalError("FollowsService: user must be signed in")
    }
    return u.uid
  }

  // FOLLOW: create users/{me}/following/{other}
  static func follow(_ otherUid: String) async throws {
    guard otherUid != myUid else { return }
    try await db.collection("users").document(myUid)
      .collection("following").document(otherUid)
      .setData([
        "otherUid": otherUid,
        "createdAt": FieldValue.serverTimestamp()
      ], merge: true)
  }

  // UNFOLLOW: delete users/{me}/following/{other}
  static func unfollow(_ otherUid: String) async throws {
    try await db.collection("users").document(myUid)
      .collection("following").document(otherUid)
      .delete()
  }

  // CHECK
  static func isFollowing(_ otherUid: String) async throws -> Bool {
    let d = try await db.collection("users").document(myUid)
      .collection("following").document(otherUid).getDocument()
    return d.exists
  }

  // STREAM my following set (uids)
  static func followingUids() -> AsyncThrowingStream<[String], Error> {
    let ref = db.collection("users").document(myUid).collection("following")
    return AsyncThrowingStream { cont in
      let lis = ref.addSnapshotListener { snap, err in
        if let err { cont.finish(throwing: err); return }
        cont.yield((snap?.documents ?? []).map { $0.documentID })
      }
      cont.onTermination = { _ in lis.remove() }
    }
  }

  // STREAM my followers via collectionGroup(following where otherUid == me)
  static func followersUids() -> AsyncThrowingStream<[String], Error> {
    let ref = db.collectionGroup("following").whereField("otherUid", isEqualTo: myUid)
    return AsyncThrowingStream { cont in
      let lis = ref.addSnapshotListener { snap, err in
        if let err { cont.finish(throwing: err); return }
        let ids = (snap?.documents ?? []).compactMap { $0.reference.parent.parent?.documentID }
        cont.yield(ids)
      }
      cont.onTermination = { _ in lis.remove() }
    }
  }
}
