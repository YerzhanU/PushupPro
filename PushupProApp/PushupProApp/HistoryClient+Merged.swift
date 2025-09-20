//
//  HistoryClient+Merged.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 19/09/2025.
//

import Foundation
import Sessions
import FirebaseFirestore
import FirebaseAuth
import AppUI // for HistoryClient type

extension HistoryClient {
  static func merged(limit: Int = 200) -> HistoryClient {
    .init(
      fetchMetas: {
        async let localMetas: [SessionMeta] = try SessionStore().loadAllMetas(limit: limit)
        async let remoteMetas: [SessionMeta] = {
          guard let uid = Auth.auth().currentUser?.uid else { return [] }
          let db = Firestore.firestore()
          let snap = try await db.collection("users").document(uid)
            .collection("sessions")
            .order(by: "endedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

          return snap.documents.compactMap { doc in
            let d = doc.data()
            guard
              let idStr = d["id"] as? String,
              let id = UUID(uuidString: idStr),
              let started = (d["startedAt"] as? Timestamp)?.dateValue(),
              let ended = (d["endedAt"] as? Timestamp)?.dateValue(),
              let totalReps = d["totalReps"] as? Int,
              let heightDelta = d["heightDeltaCM"] as? Double
            else { return nil }
            return SessionMeta(
              id: id, startedAt: started, endedAt: ended,
              totalReps: totalReps, heightDeltaCM: heightDelta
            )
          }
        }()

        // Merge by id, keep one (prefer newest endedAt)
        var byId: [UUID: SessionMeta] = [:]
        for m in try await localMetas { byId[m.id] = m }
        for m in try await remoteMetas {
          if let old = byId[m.id] {
            byId[m.id] = (m.endedAt > old.endedAt) ? m : old
          } else {
            byId[m.id] = m
          }
        }
        return byId.values.sorted { $0.endedAt > $1.endedAt }
      },
      loadSession: { id in
        // Return local if present; otherwise fetch once from cloud, save locally, then return.
        let store = SessionStore()
        if let s = try? store.load(id: id) { return s }

        guard let uid = Auth.auth().currentUser?.uid else {
          throw NSError(domain: "History", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let db = Firestore.firestore()
        let doc = try await db.collection("users").document(uid)
          .collection("sessions").document(id.uuidString).getDocument()
        guard let d = doc.data() else {
          throw NSError(domain: "History", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing remote session"])
        }

        // Rehydrate your model (keeping it minimal; extend as you like)
        let s = Session(
          id: id,
          startedAt: (d["startedAt"] as? Timestamp)?.dateValue() ?? Date(),
          endedAt: (d["endedAt"] as? Timestamp)?.dateValue() ?? Date(),
          totalReps: d["totalReps"] as? Int ?? 0,
          durationSec: d["durationSec"] as? Double ?? 0,
          avgCadenceRPM: d["avgCadenceRPM"] as? Double ?? 0,
          bestCadence30sRPM: d["bestCadence30sRPM"] as? Double ?? 0,
          heightDeltaCM: d["heightDeltaCM"] as? Double ?? 0,
          percentClean: d["percentClean"] as? Double ?? 0,
          samples: [],  // you can hydrate a capped subset if you stored it
          events: []    // same here
        )
        try store.save(s)   // cache locally
        return s
      }
    )
  }
}
