//
//  SessionRecorder.swift
//  Sessions
//
//  Created by Yerzhan Utkelbayev on 06/09/2025.
//

import Foundation

public final class SessionRecorder: @unchecked Sendable {
  private(set) public var startedAt: Date?
  private(set) public var startT: TimeInterval?
  private(set) public var heightDeltaCM: Double = 0

  private var samples: [Sample] = []
  private var events: [RepEventDTO] = []
  private var lastSampleWriteT: Double?

  public init() {}

  public func start(heightDeltaCM: Double, startDate: Date = .now) {
    self.startedAt = startDate
    self.startT = nil           // will initialize on first record()
    self.heightDeltaCM = heightDeltaCM
    self.samples.removeAll(keepingCapacity: true)
    self.events.removeAll(keepingCapacity: true)
    self.lastSampleWriteT = nil
  }

  /// Record a (possibly downsampled) telemetry sample.
  public func record(sampleCM cm: Double, threshold: Double, armed: Bool, t: TimeInterval, minInterval: Double = 0.3) {
    guard startedAt != nil else { return }
    if startT == nil { startT = t }
    let rel = max(0, t - (startT ?? t))

    if let last = lastSampleWriteT, (rel - last) < minInterval {
      return
    }
    samples.append(.init(t: rel, cm: cm, threshold: threshold, armed: armed))
    lastSampleWriteT = rel
  }

  /// Record a rep or warning event.
  public func record(event kind: RepEventKind, t: TimeInterval) {
    guard startedAt != nil else { return }
    if startT == nil { startT = t }
    let rel = max(0, t - (startT ?? t))
    events.append(.init(t: rel, kind: kind))
  }

  public func finish(endDate: Date = .now) -> Session {
    let start = startedAt ?? endDate
    let dur = max(0, endDate.timeIntervalSince(start))
    let total = events.filter { $0.kind == .rep }.count
    let avgRPM = dur > 0 ? (Double(total) / (dur / 60.0)) : 0

    // Best 30s cadence
    let repTimes = events.filter { $0.kind == .rep }.map { $0.t }.sorted()
    var best30Count = 0
    var j = 0
    for i in 0..<repTimes.count {
      let windowStart = repTimes[i]
      while j < repTimes.count && repTimes[j] - windowStart <= 30.0 { j += 1 }
      best30Count = max(best30Count, j - i)
    }
    let best30RPM = Double(best30Count) * 2.0

    let warnings = events.filter { $0.kind == .warningTooFast }.count
    let percentClean = total > 0 ? max(0, 1.0 - Double(warnings) / Double(total)) : 1.0

    let session = Session(
      startedAt: start,
      endedAt: endDate,
      totalReps: total,
      durationSec: dur,
      avgCadenceRPM: avgRPM,
      bestCadence30sRPM: best30RPM,
      heightDeltaCM: heightDeltaCM,
      percentClean: percentClean,
      samples: samples,
      events: events
    )

    // Reset for next use
    self.startedAt = nil
    self.startT = nil
    self.samples.removeAll()
    self.events.removeAll()
    self.lastSampleWriteT = nil

    return session
  }
}
