//
//  HistoryClient.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 15/09/2025.
//


//
//  HistoryClient.swift
//  AppUI
//

import Foundation
import Sessions

/// A tiny “port” that lets the app provide history data without AppUI knowing about Firebase.
public struct HistoryClient: Sendable {
  public var fetchMetas: @Sendable () async throws -> [SessionMeta]
  public var loadSession: @Sendable (_ id: UUID) async throws -> Session

  public init(
    fetchMetas: @escaping @Sendable () async throws -> [SessionMeta],
    loadSession: @escaping @Sendable (_ id: UUID) async throws -> Session
  ) {
    self.fetchMetas = fetchMetas
    self.loadSession = loadSession
  }
}

public extension HistoryClient {
  /// Default: local-only (keeps package working if the app doesn’t inject anything).
  static func localOnly() -> HistoryClient {
    .init(
      fetchMetas: {
        // Create store INSIDE the @Sendable closure to avoid capturing a non-Sendable reference.
        let store = SessionStore()
        // If your API throws, just let it throw; the caller handles it.
        return try store.loadAllMetas(limit: 200)
      },
      loadSession: { id in
        // Same idea here—new store per call, no shared capture.
        let store = SessionStore()
        return try store.load(id: id)
      }
    )
  }
}
