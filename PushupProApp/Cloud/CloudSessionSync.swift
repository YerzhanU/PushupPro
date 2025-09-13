//
//  CloudSessionSync.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


//  CloudSessionSync.swift
//  PushupProApp

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Sessions

/// Uploads finished sessions to Firestore under users/{uid}/sessions/{sessionId}.
final class CloudSessionSync {
  static let shared = CloudSessionSync()
  private init() {}

  /// Hard cap on number of samples we send to Firestore.
  private static let MAX_UPLOAD_SAMPLES = 1200

  // Lazily resolve Firestore only when used (after FirebaseApp.configure()).
  private var db: Firestore { Firestore.firestore() }

  private let pending = PendingUploadStore()     // simple retry queue
  private let store = SessionStore()             // local loader

  /// Try to upload; if offline or no user, queue for later.
  func upload(_ session: Sessions.Session) {
    guard let uid = Auth.auth().currentUser?.uid else {
      pending.enqueue(id: session.id)
      print("Upload queued (no user): \(session.id)")
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
        print("Upload ok: \(session.id) (\(session.samples.count) local / \( (payload["samples"] as? [[String:Any]])?.count ?? 0) uploaded)")
      }
    }
  }

  /// Kick retry of any queued local sessions.
  func retryQueuedUploads() {
    guard let uid = Auth.auth().currentUser?.uid else { return }
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

  // MARK: - Mapping with sample capping
  private func makePayload(from s: Sessions.Session) -> [String: Any] {
    let cappedSamples = cap(samples: s.samples, max: Self.MAX_UPLOAD_SAMPLES)

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
      "samples": cappedSamples.map { ["t": $0.t, "cm": $0.cm, "threshold": $0.threshold, "armed": $0.armed] },
      "events": s.events.map { ["t": $0.t, "kind": $0.kind.rawValue] }
    ]
  }

  /// Evenly subsample to <= max while preserving start/end and overall shape.
  private func cap(samples: [Sample], max: Int) -> [Sample] {
    guard samples.count > max, max > 0 else { return samples }
    let step = Double(samples.count - 1) / Double(max - 1)  // include first & last
    var out: [Sample] = []
    out.reserveCapacity(max)
    var i = 0
    while i < max {
      let src = Int(round(Double(i) * step))
      out.append(samples[min(src, samples.count - 1)])
      i += 1
    }
    return out
  }
}
