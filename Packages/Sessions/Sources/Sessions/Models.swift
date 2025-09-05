//
//  Models.swift
//  Sessions
//
//  Created by Yerzhan Utkelbayev on 06/09/2025.
//


//
//  Models.swift
//  Sessions
//

import Foundation

public struct Sample: Codable, Sendable {
  public let t: Double        // seconds since session start
  public let cm: Double       // smoothed cm
  public let threshold: Double
  public let armed: Bool

  public init(t: Double, cm: Double, threshold: Double, armed: Bool) {
    self.t = t; self.cm = cm; self.threshold = threshold; self.armed = armed
  }
}

public enum RepEventKind: String, Codable, Sendable {
  case rep
  case warningTooFast
}

public struct RepEventDTO: Codable, Sendable {
  public let t: Double
  public let kind: RepEventKind
  public init(t: Double, kind: RepEventKind) { self.t = t; self.kind = kind }
}

public struct Session: Codable, Sendable, Identifiable, Hashable {
  public let id: UUID
  public let startedAt: Date
  public let endedAt: Date

  public let totalReps: Int
  public let durationSec: Double
  public let avgCadenceRPM: Double
  public let bestCadence30sRPM: Double
  public let heightDeltaCM: Double
  public let percentClean: Double

  public let samples: [Sample]
  public let events: [RepEventDTO]

  public init(
    id: UUID = UUID(),
    startedAt: Date,
    endedAt: Date,
    totalReps: Int,
    durationSec: Double,
    avgCadenceRPM: Double,
    bestCadence30sRPM: Double,
    heightDeltaCM: Double,
    percentClean: Double,
    samples: [Sample],
    events: [RepEventDTO]
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.totalReps = totalReps
    self.durationSec = durationSec
    self.avgCadenceRPM = avgCadenceRPM
    self.bestCadence30sRPM = bestCadence30sRPM
    self.heightDeltaCM = heightDeltaCM
    self.percentClean = percentClean
    self.samples = samples
    self.events = events
  }

  // ✅ Custom Equatable/Hashable: compare & hash by id only
  public static func == (lhs: Session, rhs: Session) -> Bool { lhs.id == rhs.id }
  public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct SessionMeta: Codable, Sendable, Identifiable {
  public let id: UUID
  public let startedAt: Date
  public let endedAt: Date
  public let totalReps: Int
  public let heightDeltaCM: Double

  public init(id: UUID, startedAt: Date, endedAt: Date, totalReps: Int, heightDeltaCM: Double) {
    self.id = id; self.startedAt = startedAt; self.endedAt = endedAt
    self.totalReps = totalReps; self.heightDeltaCM = heightDeltaCM
  }
}
