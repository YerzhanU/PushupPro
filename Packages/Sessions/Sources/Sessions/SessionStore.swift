//
//  SessionStore.swift
//  Sessions
//
//  Created by Yerzhan Utkelbayev on 06/09/2025.
//

//
//  SessionStore.swift
//  Sessions
//

import Foundation

public final class SessionStore {
  private let fm = FileManager.default
  private let baseURL: URL
  private let indexURL: URL

  public init() {
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    baseURL = docs.appendingPathComponent("Sessions", isDirectory: true)
    indexURL = baseURL.appendingPathComponent("index.json")
    try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
    if !fm.fileExists(atPath: indexURL.path) {
      try? Data("[]".utf8).write(to: indexURL)
    }
  }

  private func sessionURL(for id: UUID) -> URL {
    baseURL.appendingPathComponent("session-\(id.uuidString).json")
  }

  // MARK: Save / Load

  public func save(_ session: Session) throws {
    let data = try JSONEncoder.iso8601().encode(session)
    try data.write(to: sessionURL(for: session.id), options: .atomic)

    var metas = try loadAllMetas()
    let meta = SessionMeta(id: session.id, startedAt: session.startedAt, endedAt: session.endedAt, totalReps: session.totalReps, heightDeltaCM: session.heightDeltaCM)
    metas.removeAll { $0.id == meta.id }
    metas.append(meta)
    metas.sort { $0.startedAt > $1.startedAt }
    let mdata = try JSONEncoder.iso8601().encode(metas)
    try mdata.write(to: indexURL, options: .atomic)
  }

  public func load(id: UUID) throws -> Session {
    let data = try Data(contentsOf: sessionURL(for: id))
    return try JSONDecoder.iso8601().decode(Session.self, from: data)
  }

  public func loadAllMetas(limit: Int = 50) throws -> [SessionMeta] {
    guard fm.fileExists(atPath: indexURL.path) else { return [] }
    let data = try Data(contentsOf: indexURL)
    var metas = try JSONDecoder.iso8601().decode([SessionMeta].self, from: data)
    metas.sort { $0.startedAt > $1.startedAt }
    if metas.count > limit { metas = Array(metas.prefix(limit)) }
    return metas
  }

  // MARK: Export

  public func exportCSV(for session: Session, filename: String = "export-latest.csv") throws -> URL {
    var csv = "t_sec,cm,threshold,armed\n"
    for s in session.samples {
      csv.append(String(format: "%.3f,%.3f,%.3f,%@\n", s.t, s.cm, s.threshold, s.armed ? "true" : "false"))
    }
    let url = baseURL.appendingPathComponent(filename)
    try csv.data(using: .utf8)!.write(to: url, options: .atomic)
    return url
  }
}

private extension JSONEncoder {
  static func iso8601() -> JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.prettyPrinted]   // removed .withoutEscapingSlashes
    return e
  }
}
private extension JSONDecoder {
  static func iso8601() -> JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }
}
