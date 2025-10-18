// CloudSessionSync.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Sessions

/// Uploads finished sessions to Firestore under users/{uid}/sessions/{sessionId}.
/// While signed out, uploads are queued; on sign-in, queued + backfill can run.
/// After each successful cloud write, rollups + leaderboard mirrors are updated
/// so the Leaderboard reflects imported/backfilled sessions immediately.
final class CloudSessionSync {
  static let shared = CloudSessionSync()
  private init() {}

  private static let MAX_UPLOAD_SAMPLES = 1200
  private var db: Firestore { Firestore.firestore() }

  private let pending = PendingUploadStore()
  private let store = SessionStore()

  // Only treat non-anonymous as a real, signed-in user.
  private var realUID: String? {
    guard let u = Auth.auth().currentUser, !u.isAnonymous else { return nil }
    return u.uid
  }

  // MARK: - Public API

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
        let uploaded = (payload["samples"] as? [[String:Any]])?.count ?? 0
        print("Upload ok: \(session.id) (\(session.samples.count) local / \(uploaded) uploaded)")

        // ⬇️ After successful upload, bump rollups + mirror leaderboard.
        Task {
          do { try await self?.bumpRollupsForSession(session, uid: uid) }
          catch { print("Rollup/mirror failed after upload:", error.localizedDescription) }
        }
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
          if let error {
            print("Retry failed for \(id): \(error.localizedDescription)")
          } else {
            self?.pending.remove(id: id)
            Task {
              do { try await self?.bumpRollupsForSession(s, uid: uid) }
              catch { print("Rollup/mirror failed after retry:", error.localizedDescription) }
            }
          }
        }
      } else {
        pending.remove(id: id) // local file gone; drop from queue
      }
    }
  }

  /// Backfill ALL local sessions to the current real user (used on sign-in import).
  /// Each successfully written session bumps rollups and the global mirror.
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
            Task {
              do { try await self?.bumpRollupsForSession(s, uid: uid) }
              catch { print("Rollup/mirror failed after backfill:", error.localizedDescription) }
            }
          }
        }
      }
    } catch {
      print("Backfill scan failed:", error.localizedDescription)
    }
  }

  // MARK: - Rollups + Leaderboard

  /// Bumps non-decreasing rollups for the given session and mirrors the global leaderboard.
  /// - Important: respects rules — never decreases score; only sets `firstAtScore` on create.
  public func bumpRollupsForSession(_ session: Sessions.Session, uid: String) async throws {
    let ended = session.endedAt ?? session.startedAt
    let reps   = session.totalReps

    let keys = [
      PeriodKey.daily(ended),
      PeriodKey.monthly(ended),
      PeriodKey.yearly(ended),
      PeriodKey.allTime()
    ]

    for key in keys {
      // 1) Upsert rollup (non-decreasing) and get current rollup state back.
      let roll = try await upsertRollup(uid: uid, key: key, addScore: reps, createFirstAt: ended)

      // 2) Mirror to global leaderboard with score equal to rollup.score.
      //    Include firstAtScore only if present (on create), else omit.
      let lbRef = db.collection("leaderboards").document("global")
        .collection("periods").document(key)
        .collection("entries").document(uid)

      var payload: [String: Any] = ["score": roll.score]
      if let first = roll.firstAtScore { payload["firstAtScore"] = first }
      try await lbRef.setData(payload, merge: true)
    }
  }

  /// Upserts users/{uid}/rollups/{key} non-decreasing and returns the new state.
  private func upsertRollup(uid: String, key: String, addScore: Int, createFirstAt: Date) async throws -> (score: Int, firstAtScore: Timestamp?) {
    let ref = db.collection("users").document(uid).collection("rollups").document(key)
    let snap = try await ref.getDocument()
    let nowFirst = Timestamp(date: createFirstAt)

    if snap.exists {
      let current = (snap.get("score") as? Int) ?? 0
      let newScore = current + addScore
      try await ref.setData(["score": newScore], merge: true)
      let first = snap.get("firstAtScore") as? Timestamp
      return (newScore, first) // do not touch firstAtScore on update
    } else {
      // Create with initial score and firstAtScore set once.
      try await ref.setData([
        "score": addScore,
        "firstAtScore": nowFirst
      ], merge: true)
      return (addScore, nowFirst)
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
