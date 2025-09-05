//
//  RepDetector.swift
//  RepEngine
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import Foundation

/// Single-threshold, edge-triggered detector.
/// - Maintain a rolling TOP (max) with gentle decay over time.
/// - Count once when cm first crosses below (TOP - heightDeltaCM).
/// - Re-arm only after cm returns close to TOP (within rearmEpsCM).
public struct RepDetector {
  public private(set) var count = 0
  public private(set) var telemetry = RepTelemetry()

  private var cfg: RepConfig

  // Smoothed/clamped input
  private var lastCM: Double?
  private var lastT: TimeInterval?

  // Rolling top & arming
  private var topCM: Double?
  private var armed = false
  private var lastRepTime: TimeInterval?

  public init(config: RepConfig = .init()) { self.cfg = config }

  public mutating func reset(config: RepConfig? = nil) {
    if let c = config { self.cfg = c }
    count = 0
    telemetry = RepTelemetry()
    lastCM = nil
    lastT = nil
    topCM = nil
    armed = false
    lastRepTime = nil
  }

  public mutating func ingest(cm raw: Double, t: TimeInterval) -> [RepEvent] {
    guard raw.isFinite else { return [] }

    // Clamp
    let clamped = min(max(raw, cfg.clampMinCM), cfg.clampMaxCM)

    // Smooth
    let cm: Double = {
      guard let last = lastCM else { lastCM = clamped; lastT = t; return clamped }
      let v = last + cfg.smoothingAlpha * (clamped - last)
      lastCM = v
      lastT = t
      return v
    }()

    // Init top/armed on first sample
    if topCM == nil {
      topCM = cm
      armed = true
    }

    // Update rolling TOP with gentle decay
    var top = topCM!
    let dt = max(0, (lastT.map { t - $0 } ?? 0))
    if cm > top { top = cm }                    // follow you going up immediately
    else { top = max(cm, top - cfg.topDecayPerSec * dt) } // decay towards cm slowly
    topCM = top

    // Threshold
    let threshold = top - cfg.heightDeltaCM

    // Arming rule: near top?
    if !armed, cm >= (top - cfg.rearmEpsCM) {
      armed = true
    }

    var events: [RepEvent] = []

    // Edge: first crossing below threshold → count once
    if armed, cm <= threshold {
      if (lastRepTime.map { t - $0 >= cfg.minRepDuration } ?? true) {
        count += 1
        events.append(.rep(count: count))
        lastRepTime = t
      } else {
        events.append(.warningTooFast)
      }
      armed = false
    }

    // Publish telemetry
    telemetry = RepTelemetry(
      smoothedCM: cm,
      targetBottomCM: threshold,
      topCM: top,
      phase: armed ? .up : .rearming,
      armed: armed
    )

    return events
  }
}
