//
//  MigrationCoordinator.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 21/09/2025.
//


//
//  MigrationCoordinator.swift
//  PushupProApp
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Sessions

/// Migrates local (unsigned) sessions into the currently signed-in account,
/// then removes them from local storage.
final class MigrationCoordinator {
  static let shared = MigrationCoordinator()
  private init() {}

  func hasLocalSessions() -> Int {
    LocalSessionFilesystem.loadAllMetas().count
  }

  /// Uploads all local sessions to Firestore under users/{uid}/sessions/{id}
  /// and removes the local copies on success.
  @discardableResult
  func importAllLocalToCurrentUserDeleteLocal() async throws -> (migrated: Int, failed: Int) {
    guard let user = Auth.auth().currentUser, !user.isAnonymous else {
      throw NSError(domain: "Migration", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No signed-in user for import"])
    }
    let uid = user.uid
    let db = Firestore.firestore()
    let store = SessionStore() // reads the local device store

    let metas = LocalSessionFilesystem.loadAllMetas()
    var migrated = 0, failed = 0

    for m in metas {
      do {
        let s = try store.load(id: m.id)
        let payload: [String: Any] = [
          "id": s.id.uuidString,
          "startedAt": Timestamp(date: s.startedAt),
          "endedAt": Timestamp(date: s.endedAt),
          "totalReps": s.totalReps,
          "durationSec": s.durationSec,
          "avgCadenceRPM": s.avgCadenceRPM,
          "bestCadence30sRPM": s.bestCadence30sRPM,
          "heightDeltaCM": s.heightDeltaCM,
          "percentClean": s.percentClean,
          "samples": s.samples.map { ["t": $0.t, "cm": $0.cm, "threshold": $0.threshold, "armed": $0.armed] },
          "events": s.events.map { ["t": $0.t, "kind": $0.kind.rawValue] }
        ]
        let ref = db.collection("users").document(uid)
          .collection("sessions").document(s.id.uuidString)
        try await ref.setData(payload, merge: true)

        // Remove local copy after successful upload
        try LocalSessionFilesystem.delete(id: s.id)
        migrated += 1
        print("[Import] Moved \(s.id) → cloud user=\(uid) and deleted local file")
      } catch {
        failed += 1
        let ns = error as NSError
        print("[Import] Failed \(m.id) \(ns.domain)#\(ns.code): \(ns.localizedDescription)")
      }
    }
    print("[Import] Done. migrated=\(migrated) failed=\(failed)")
    return (migrated, failed)
  }
}
