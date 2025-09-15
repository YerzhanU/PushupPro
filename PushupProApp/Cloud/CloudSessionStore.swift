//
//  CloudSessionStore.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 15/09/2025.
//


import Foundation
import FirebaseFirestore
import Sessions

struct CloudSessionStore {
  private var db: Firestore { Firestore.firestore() }

  func fetchMetas(uid: String, limit: Int = 200) async throws -> [SessionMeta] {
    let snapshot = try await db.collection("users")
      .document(uid)
      .collection("sessions")
      .order(by: "startedAt", descending: true)
      .limit(to: limit)
      .getDocuments()

    return snapshot.documents.compactMap { doc in
      let d = doc.data()
      guard
        let startedAt = (d["startedAt"] as? Timestamp)?.dateValue(),
        let endedAt = (d["endedAt"] as? Timestamp)?.dateValue(),
        let totalReps = d["totalReps"] as? Int,
        let height = d["heightDeltaCM"] as? Double
      else { return nil }

      let id = UUID(uuidString: doc.documentID) ?? UUID()
      return SessionMeta(id: id, startedAt: startedAt, endedAt: endedAt, totalReps: totalReps, heightDeltaCM: height)
    }
  }

  func fetchSession(uid: String, id: UUID) async throws -> Session {
    let ref = db.collection("users").document(uid)
      .collection("sessions").document(id.uuidString)
    let snap = try await ref.getDocument()
    guard let d = snap.data() else {
      throw NSError(domain: "CloudSessionStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session not found"])
    }

    let startedAt = (d["startedAt"] as? Timestamp)?.dateValue() ?? Date()
    let endedAt   = (d["endedAt"]   as? Timestamp)?.dateValue() ?? startedAt
    let totalReps = d["totalReps"] as? Int ?? 0
    let duration  = d["durationSec"] as? Double ?? endedAt.timeIntervalSince(startedAt)
    let avgRPM    = d["avgCadenceRPM"] as? Double ?? 0
    let best30    = d["bestCadence30sRPM"] as? Double ?? 0
    let height    = d["heightDeltaCM"] as? Double ?? 0
    let clean     = d["percentClean"] as? Double ?? 0

    // Optional arrays (older docs might not have them)
    let samplesAny = d["samples"] as? [[String: Any]] ?? []
    let eventsAny  = d["events"]  as? [[String: Any]] ?? []

    let samples: [Sample] = samplesAny.compactMap { e in
      guard let t = e["t"] as? Double, let cm = e["cm"] as? Double else { return nil }
      let thr = e["threshold"] as? Double ?? 0
      let armed = e["armed"] as? Bool ?? false
      return Sample(t: t, cm: cm, threshold: thr, armed: armed)
    }

    let events: [RepEventDTO] = eventsAny.compactMap { e in
      guard let t = e["t"] as? Double,
            let kindStr = e["kind"] as? String,
            let kind = RepEventKind(rawValue: kindStr) else { return nil }
      return RepEventDTO(t: t, kind: kind)
    }

    return Session(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      totalReps: totalReps,
      durationSec: duration,
      avgCadenceRPM: avgRPM,
      bestCadence30sRPM: best30,
      heightDeltaCM: height,
      percentClean: clean,
      samples: samples,
      events: events
    )
  }
}
