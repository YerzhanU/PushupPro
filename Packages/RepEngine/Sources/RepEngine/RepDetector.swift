//
//  RepDetector.swift
//  RepEngine
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import Foundation

/// Edge-triggered with FIXED TOP:
/// - Calibrate TOP (max cm) for the first `calibSeconds`, then freeze it.
/// - Count 1 rep the first time cm crosses <= (TOP - heightDelta).
/// - Re-arm only when cm goes back up to within `topRearmEpsCM` of TOP.
public struct RepDetector {
  public private(set) var count = 0
  public private(set) var telemetry = RepTelemetry()

  private var cfg: RepConfig

  // Smoothing
  private var lastCM: Double?
  private let alpha = 0.25

  // Fixed-TOP calibration
  private let calibSeconds: Double = 2.0
  private var t0: TimeInterval?
  private var fixedTopCM: Double?     // frozen TOP after calibration

  // Edge-trigger state
  private var armedForDown = false    // waiting to go DOWN past threshold
  private var lastRepTime: TimeInterval?

  public init(config: RepConfig = .init()) { self.cfg = config }

  public mutating func reset(config: RepConfig? = nil) {
    if let c = config { self.cfg = c }
    count = 0
    lastCM = nil
    t0 = nil
    fixedTopCM = nil
    armedForDown = false
    lastRepTime = nil
    telemetry = RepTelemetry()
  }

  public mutating func ingest(cm rawCM: Double, t: TimeInterval) -> [RepEvent] {
    guard rawCM.isFinite else { return [] }

    // Smooth the signal
    let cm: Double = {
      guard let last = lastCM else { lastCM = rawCM; return rawCM }
      let v = last + alpha * (rawCM - last)
      lastCM = v
      return v
    }()

    // Establish session start and calibrate TOP (max) for a short window
    if t0 == nil { t0 = t }
    if fixedTopCM == nil {
      fixedTopCM = cm
    }
    if let start = t0, (t - start) < calibSeconds {
      fixedTopCM = max(fixedTopCM ?? cm, cm)          // observe TOP during calibration
    }
    // After calib window, TOP is frozen
    let top = fixedTopCM ?? cm

    // Dynamic threshold = TOP - required descent (height setting)
    let heightDelta = max(0, cfg.manualBottomCM)
    let thresholdDown = top - heightDelta

    // Arm when we're near TOP (within eps)
    if !armedForDown, cm >= (top - cfg.topRearmEpsCM) {
      armedForDown = true
    }

    var events: [RepEvent] = []

    // Edge: first crossing below threshold
    if armedForDown && cm <= thresholdDown {
      if (lastRepTime.map { t - $0 >= cfg.minRepDuration } ?? true) {
        count += 1
        events.append(.rep(count: count))
        lastRepTime = t
      } else {
        events.append(.warningTooFast)
      }
      armedForDown = false
    }

    // Telemetry for the overlay:
    // - targetBottomCM = threshold
    // - topEst = TOP (fixed)
    // - hysteresisCM is re-arm tick offset from target (target + (height - rearmNearTop))
    let rearmOffsetFromTarget = max(0.001, heightDelta - cfg.topRearmEpsCM)
    let swing = max(0, top - cm)

    telemetry = RepTelemetry(
      smoothedCM: cm,
      targetBottomCM: thresholdDown,
      phase: armedForDown ? .above : .ascending,  // simple phase for display
      calibrated: true,
      topEst: top,
      botEst: nil,
      gateAboveCM: heightDelta,            // TOP = target + height
      gateBelowCM: 0.0,                    // no extra dip beyond threshold
      hysteresisCM: rearmOffsetFromTarget, // target + (height - eps) → near-TOP
      metTopGate: armedForDown,
      holdElapsed: 0,
      swingCM: swing
    )

    return events
  }
}
