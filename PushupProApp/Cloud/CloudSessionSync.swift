//
//  CloudSessionSync.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Sessions

/// Uploads finished sessions to Firestore under users/{uid}/sessions/{sessionId}.
final class CloudSessionSync {
  static let shared = CloudSessionSync()
  private init() {}

  private static let MAX_UPLOAD_SAMPLES = 1200
  private var db: Firestore { Firestore.firestore() }

  private let pending = PendingUploadStore()     // disk-backed retry queue
  private let store = SessionStore()             // local session store

  // Helper: only treat non-anonymous as a real, signed-in user.
  private var realUID: String? {
    guard let u = Auth.auth().currentUser, !u.isAnonymous else { return nil }
    return u.uid
  }

  /// Try to upload; if not a real signed-in user, queue for later.
  func upload(_ session: Sessions.Session) {
    guard let uid = realUID else {
      pending.enqueue(id: session.id)
      print("Upload queued (guest/no real user): \(session.id)")
      return
    }

    let ref = db.collection("users").document(uid)
      .collection("sessions").document(session.id.uuidString)

    let payload = makePayload(from: session)
    ref.setData(payload, merge: true) { [weak self] error in
      if let error {
        print("Upload failed, queued: \(error.localizedDescription)")
        self?.pending.enqueue(id: session.id)
      } else {
        self?.pending.remove(id: session.id)
        let uploaded = (payload["samples"] as? [[String: Any]])?.count ?? 0
        print("Upload ok: \(session.id) (\(session.samples.count) local / \(uploaded) uploaded)")
      }
    }
  }

  /// Retry any queued uploads — only when a real user exists.
  func retryQueuedUploads() {
    guard let uid = realUID else { return }
    for id in pending.all() {
      if let s = try? store.load(id: id) {
        let ref = db.collection("users").document(uid)
          .collection("sessions").document(id.uuidString)
        ref.setData(makePayload(from: s), merge: true) { [weak self] error in
          if error == nil { self?.pending.remove(id: id) }
        }
      }
    }
  }

  /// Backfill ALL local sessions to the current real user.
  func backfillAll(limit: Int = 500) {
    guard let uid = realUID else { return }
    do {
      let metas = try store.loadAllMetas(limit: limit)
      for m in metas {
        guard let s = try? store.load(id: m.id) else { continue }
        let ref = db.collection("users").document(uid)
          .collection("sessions").document(s.id.uuidString)
        ref.setData(makePayload(from: s), merge: true) { [weak self] error in
          if let error {
            print("Backfill failed for \(s.id): \(error.localizedDescription)")
            self?.pending.enqueue(id: s.id)
          } else {
            self?.pending.remove(id: s.id)
          }
        }
      }
    } catch {
      print("Backfill scan failed:", error.localizedDescription)
    }
  }

  // MARK: - Mapping + capping

  private func makePayload(from s: Sessions.Session) -> [String: Any] {
    let capped = cap(samples: s.samples, max: Self.MAX_UPLOAD_SAMPLES)
    return [
      "id": s.id.uuidString,
      "startedAt": Timestamp(date: s.startedAt),
      "endedAt": Timestamp(date: s.endedAt),
      "totalReps": s.totalReps,
      "durationSec": s.durationSec,
      "avgCadenceRPM": s.avgCadenceRPM,
      "bestCadence30sRPM": s.bestCadence30sRPM,
      "heightDeltaCM": s.heightDeltaCM,
      "percentClean": s.percentClean,
      "samples": capped.map { ["t": $0.t, "cm": $0.cm, "threshold": $0.threshold, "armed": $0.armed] },
      "events": s.events.map { ["t": $0.t, "kind": $0.kind.rawValue] }
    ]
  }

  /// Evenly subsample to <= max while preserving start/end and overall shape.
  private func cap(samples: [Sample], max: Int) -> [Sample] {
    guard samples.count > max, max > 0 else { return samples }
    let step = Double(samples.count - 1) / Double(max - 1)  // keep first/last
    var out: [Sample] = []
    out.reserveCapacity(max)
    for i in 0..<max {
      let src = Int(round(Double(i) * step))
      out.append(samples[min(src, samples.count - 1)])
    }
    return out
  }
}
