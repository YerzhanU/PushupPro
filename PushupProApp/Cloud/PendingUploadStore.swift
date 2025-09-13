//
//  PendingUploadStore.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import Foundation

/// Disk-backed queue of session IDs that still need an upload attempt.
final class PendingUploadStore {
  private let url: URL
  private var ids: Set<UUID> = []

  init(filename: String = "pending-session-uploads.json") {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    url = dir.appendingPathComponent(filename)
    load()
  }

  func enqueue(id: UUID) {
    ids.insert(id); save()
  }
  func remove(id: UUID) {
    ids.remove(id); save()
  }
  func all() -> [UUID] { Array(ids) }

  private func load() {
    guard let data = try? Data(contentsOf: url) else { return }
    if let arr = try? JSONDecoder().decode([UUID].self, from: data) {
      ids = Set(arr)
    }
  }

  private func save() {
    let arr = Array(ids)
    if let data = try? JSONEncoder().encode(arr) {
      try? data.write(to: url)
    }
  }
}
