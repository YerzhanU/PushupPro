//
//  UnifiedHistoryScreen.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 15/09/2025.
//


import SwiftUI
import FirebaseAuth
import Sessions
import AppUI

struct UnifiedHistoryScreen: View {
  var body: some View {
    HistoryView(client: makeClient())
  }

  private func makeClient() -> HistoryClient {
    let local = SessionStore()
    let cloud = CloudSessionStore()
    let uid = Auth.auth().currentUser?.uid

    // Merge metas (cloud + local) newest-first, dedupe by id (prefer cloud copy when both exist).
    func mergedMetas() async throws -> [SessionMeta] {
      let localMetas = (try? local.loadAllMetas(limit: 200)) ?? []
      guard let uid else { return localMetas } // no user → local only

      let cloudMetas = try await cloud.fetchMetas(uid: uid, limit: 200)

      // Dedupe by id, preferring cloud
      var map = [UUID: SessionMeta]()
      for m in localMetas { map[m.id] = m }
      for m in cloudMetas { map[m.id] = m } // overwrite with cloud if present

      // Sort newest first
      return map.values.sorted(by: { $0.startedAt > $1.startedAt })
    }

    // Load session local-first, fallback to cloud, optionally cache to local.
    func loadSession(_ id: UUID) async throws -> Session {
      if let s = try? local.load(id: id) { return s }
      guard let uid else { throw NSError(domain: "UnifiedHistory", code: 401,
                                         userInfo: [NSLocalizedDescriptionKey: "Not signed in"]) }
      let s = try await cloud.fetchSession(uid: uid, id: id)
      // Optionally cache cloud session into local store so it’s available offline:
      try? local.save(s)
      return s
    }

    return HistoryClient(
      fetchMetas: { try await mergedMetas() },
      loadSession: { id in try await loadSession(id) }
    )
  }
}
