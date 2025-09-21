//
//  UnifiedHistoryScreen.swift
//  PushupProApp
//

import SwiftUI
import FirebaseAuth
import Sessions
import AppUI

/// Single merged history list (Account + On device).
/// Both sources are ON by default; a toolbar Filter lets you toggle them.
/// Resolves the current UID at fetch-time so it updates right after sign-in.
struct UnifiedHistoryScreen: View {
  @State private var showAccount: Bool = true
  @State private var showDevice:  Bool = true

  // Rebuild the inner HistoryView whenever auth user or filters change
  private var userKey: String {
    let u = Auth.auth().currentUser
    return (u?.isAnonymous ?? true) ? "unsigned" : (u?.uid ?? "unsigned")
  }

  var body: some View {
    HistoryView(client: makeClient())
      .id("\(userKey)-A\(showAccount ? 1 : 0)-D\(showDevice ? 1 : 0)")
      .toolbar {
        Menu {
          Toggle("Account", isOn: $showAccount)
          Toggle("On device", isOn: $showDevice)
        } label: {
          Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
      }
  }

  // MARK: - HistoryClient (merged, resolves UID at fetch-time)

  private func makeClient() -> HistoryClient {
    // Capture filter toggles for @Sendable closures; view refresh is driven by .id above
    let includeAccount = showAccount
    let includeDevice  = showDevice

    @Sendable
    func mergedMetas() async throws -> [SessionMeta] {
      var out: [SessionMeta] = []

      // Local metas
      if includeDevice {
        let local = SessionStore()
        let lm = try local.loadAllMetas(limit: 500)
        out.append(contentsOf: lm)
      }

      // Cloud metas (resolve current uid at call time)
      if includeAccount {
        if let u = Auth.auth().currentUser, !u.isAnonymous {
          let cloud = CloudSessionStore()
          let cm = try await cloud.fetchMetas(uid: u.uid, limit: 500)
          out.append(contentsOf: cm)
        }
      }

      // Dedupe by id; prefer newer
      var seen: [UUID: SessionMeta] = [:]
      for m in out {
        if let prev = seen[m.id] {
          seen[m.id] = (m.endedAt, m.startedAt) > (prev.endedAt, prev.startedAt) ? m : prev
        } else {
          seen[m.id] = m
        }
      }

      return seen.values.sorted { $0.startedAt > $1.startedAt }
    }

    @Sendable
    func loadSession(_ id: UUID) async throws -> Session {
      // Local first
      do {
        let local = SessionStore()
        if let s = try? local.load(id: id) { return s }
      }

      // Cloud if available and included
      if includeAccount, let u = Auth.auth().currentUser, !u.isAnonymous {
        let cloud = CloudSessionStore()
        let s = try await cloud.fetchSession(uid: u.uid, id: id)
        // Cache for offline
        let local = SessionStore()
        try? local.save(s)
        return s
      }

      throw NSError(domain: "UnifiedHistory", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Session not found in selected sources"])
    }

    return HistoryClient(
      fetchMetas: { try await mergedMetas() },
      loadSession: { id in try await loadSession(id) }
    )
  }
}
