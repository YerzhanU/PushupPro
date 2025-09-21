//
//  LocalSessionFilesystem.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 21/09/2025.
//


//
//  LocalSessionFilesystem.swift
//  PushupProApp
//

import Foundation
import Sessions

/// Direct file access to the app’s local Sessions store (Documents/Sessions/*).
/// We use this to REMOVE sessions after they’re imported to the account.
enum LocalSessionFilesystem {
  private static var fm: FileManager { .default }

  static var baseURL: URL {
    fm.urls(for: .documentDirectory, in: .userDomainMask).first!
      .appendingPathComponent("Sessions", isDirectory: true)
  }

  static var indexURL: URL { baseURL.appendingPathComponent("index.json", conformingTo: .json) }

  private static func makeDecoder() -> JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }

  private static func makeEncoder() -> JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.prettyPrinted]
    return e
  }

  static func loadAllMetas() -> [SessionMeta] {
    guard fm.fileExists(atPath: indexURL.path),
          let data = try? Data(contentsOf: indexURL),
          let metas = try? makeDecoder().decode([SessionMeta].self, from: data) else {
      return []
    }
    return metas.sorted { $0.startedAt > $1.startedAt }
  }

  static func writeMetas(_ metas: [SessionMeta]) throws {
    try fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
    let data = try makeEncoder().encode(metas)
    try data.write(to: indexURL, options: .atomic)
  }

  static func sessionURL(for id: UUID) -> URL {
    baseURL.appendingPathComponent("session-\(id.uuidString).json", conformingTo: .json)
  }

  /// Remove a single session file + its entry in index.json.
  static func delete(id: UUID) throws {
    var metas = loadAllMetas()
    metas.removeAll { $0.id == id }
    try? fm.removeItem(at: sessionURL(for: id))
    try writeMetas(metas)
  }

  /// Remove ALL sessions locally.
  static func deleteAll() throws {
    try? fm.removeItem(at: baseURL)
    try fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
    try writeMetas([])
  }
}
