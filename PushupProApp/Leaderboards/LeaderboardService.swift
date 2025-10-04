//
//  LeaderboardService.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 03/10/2025.
//


// LeaderboardService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore

struct LeaderboardEntry: Identifiable, Equatable {
  var id: String { uid }
  let uid: String
  let score: Int
  let firstAtScore: Date?
  let displayName: String?
  let handle: String?
  let photoURL: String?
}

enum LBScope: String, CaseIterable, Identifiable { case global, following, followers, me; var id: String { rawValue } }

enum LBPeriod: Equatable {
  case todayUTC, thisMonthUTC, thisYearUTC, allTime

  var key: String {
    switch self {
    case .todayUTC:     return PeriodKey.daily(Date())
    case .thisMonthUTC: return PeriodKey.monthly(Date())
    case .thisYearUTC:  return PeriodKey.yearly(Date())
    case .allTime:      return PeriodKey.allTime()
    }
  }
}

struct LeaderboardService {
  private let db = Firestore.firestore()
  private var myUid: String? { Auth.auth().currentUser?.uid }

  // GLOBAL: single orderBy to avoid composite index; tie-break client-side.
  func global(period: LBPeriod, limit: Int = 100) async throws -> [LeaderboardEntry] {
    let ref = db.collection("leaderboards").document("global")
      .collection("periods").document(period.key)
      .collection("entries")
      .order(by: "score", descending: true)
      .limit(to: max(limit, 100))
    let snap = try await ref.getDocuments()
    let rows = try await mapEntries(snap.documents.map { ($0.documentID, $0.data()) })
    return sort(rows).prefix(limit).map { $0 }
  }

  func following(period: LBPeriod) async throws -> [LeaderboardEntry] {
    guard let me = myUid else { return [] }
    let followSnap = try await db.collection("users").document(me).collection("following").getDocuments()
    let uids = Array(Set(followSnap.documents.map { $0.documentID } + [me]))
    return try await readRollups(uids: uids, period: period)
  }

    func followers(period: LBPeriod) async throws -> [LeaderboardEntry] {
      guard let me = myUid else { return [] }
      let folSnap = try await db.collection("users").document(me)
        .collection("followers").getDocuments()
      let uids = Array(Set(folSnap.documents.map { $0.documentID } + [me]))
      return try await readRollups(uids: uids, period: period)
    }

  func me(period: LBPeriod) async throws -> [LeaderboardEntry] {
    guard let me = myUid else { return [] }
    return try await readRollups(uids: [me], period: period)
  }

  // ---- Helpers ----
  private func readRollups(uids: [String], period: LBPeriod) async throws -> [LeaderboardEntry] {
    var entries: [LeaderboardEntry] = []
    try await withThrowingTaskGroup(of: LeaderboardEntry?.self) { group in
      for uid in uids {
        group.addTask {
          async let rollDoc = self.db.collection("users").document(uid)
            .collection("rollups").document(period.key).getDocument()
          async let profDoc = self.db.collection("users").document(uid).getDocument()
          let roll = try await rollDoc
          let prof = try await profDoc

          // Fallbacks for MY row (in case profile doc is empty/not created yet)
          let auth = Auth.auth().currentUser
          let myFallbackName: String? = (uid == auth?.uid)
            ? (auth?.displayName ?? auth?.email?.components(separatedBy: "@").first)
            : nil
          let myFallbackPhoto: String? = (uid == auth?.uid) ? auth?.photoURL?.absoluteString : nil

          return LeaderboardEntry(
            uid: uid,
            score: (roll.get("score") as? Int) ?? 0,
            firstAtScore: (roll.get("firstAtScore") as? Timestamp)?.dateValue(),
            displayName: (prof.get("displayName") as? String) ?? myFallbackName,
            handle: prof.get("handle") as? String,
            photoURL: (prof.get("photoURL") as? String) ?? myFallbackPhoto
          )
        }
      }
      for try await e in group { if let e { entries.append(e) } }
    }
    return sort(entries)
  }

  private func mapEntries(_ rows: [(String, [String: Any])]) async throws -> [LeaderboardEntry] {
    var out: [LeaderboardEntry] = []
    try await withThrowingTaskGroup(of: LeaderboardEntry?.self) { group in
      for (uid, data) in rows {
        group.addTask {
          let prof = try await self.db.collection("users").document(uid).getDocument()

          // Fallbacks for MY row
          let auth = Auth.auth().currentUser
          let myFallbackName: String? = (uid == auth?.uid)
            ? (auth?.displayName ?? auth?.email?.components(separatedBy: "@").first)
            : nil
          let myFallbackPhoto: String? = (uid == auth?.uid) ? auth?.photoURL?.absoluteString : nil

          return LeaderboardEntry(
            uid: uid,
            score: (data["score"] as? Int) ?? 0,
            firstAtScore: (data["firstAtScore"] as? Timestamp)?.dateValue(),
            displayName: (prof.get("displayName") as? String) ?? myFallbackName,
            handle: prof.get("handle") as? String,
            photoURL: (prof.get("photoURL") as? String) ?? myFallbackPhoto
          )
        }
      }
      for try await e in group { if let e { out.append(e) } }
    }
    return out
  }

  private func sort(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
    entries.sorted {
      if $0.score != $1.score { return $0.score > $1.score }
      switch ($0.firstAtScore, $1.firstAtScore) {
      case let (a?, b?): return a < b
      case (nil, _?):    return false
      case (_?, nil):    return true
      default:           return $0.uid < $1.uid
      }
    }
  }
}
