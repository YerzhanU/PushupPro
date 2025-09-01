//
//  RepConfig.swift
//  RepEngine
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import Foundation

/// Configuration for rep detection.
/// In this mode, `manualBottomCM` is treated as the required *delta* (cm) you must descend
/// from the current TOP to count a rep.
public struct RepConfig: Sendable, Equatable {
  public var useAutoHeight: Bool
  /// Required descent *delta* from the current top (cm). Acts as "height".
  public var manualBottomCM: Double
  /// How much higher than the last top you must rise to arm the next rep (cm).
  public var topRearmEpsCM: Double
  /// Unused by this algorithm but kept for tuning/compatibility.
  public var hysteresisCM: Double
  public var minBottomHold: Double
  public var minRepDuration: Double
  public var minSwingForCalibration: Double
  /// Debug-only: for the overlay ticks (top gate = required delta, bottom gate = 0).
  public var gateAboveCM: Double
  public var gateBelowCM: Double

  public init(
    useAutoHeight: Bool = true,
    manualBottomCM: Double = 10,   // required descent from TOP to count
    topRearmEpsCM: Double = 0.5,   // how much higher than last TOP to re-arm
    hysteresisCM: Double = 1.5,
    minBottomHold: Double = 0.0,   // not used now (edge-triggered), keep 0
    minRepDuration: Double = 0.6,  // reject ultra-fast chatter
    minSwingForCalibration: Double = 5.0,
    gateAboveCM: Double = 1.0,
    gateBelowCM: Double = 0.0
  ) {
    self.useAutoHeight = useAutoHeight
    self.manualBottomCM = manualBottomCM
    self.topRearmEpsCM = topRearmEpsCM
    self.hysteresisCM = hysteresisCM
    self.minBottomHold = minBottomHold
    self.minRepDuration = minRepDuration
    self.minSwingForCalibration = minSwingForCalibration
    self.gateAboveCM = gateAboveCM
    self.gateBelowCM = gateBelowCM
  }
}

/// Detector output events.
public enum RepEvent: Sendable, Equatable {
  case started
  case rep(count: Int)
  case warningTooShallow
  case warningTooFast
  case ended
}

/// Lightweight status for drawing debug UI.
public struct RepTelemetry: Sendable {
  public enum Phase: String, Sendable { case calibrating, above, bottomHold, ascending }

  public let smoothedCM: Double
  /// For this algorithm, `targetBottomCM` is the dynamic threshold: TOP - heightDelta.
  public let targetBottomCM: Double
  public let phase: Phase

  // Debug fields
  public let calibrated: Bool
  public let topEst: Double?
  public let botEst: Double?
  public let gateAboveCM: Double
  public let gateBelowCM: Double
  /// Shown as the gray tick at (target + hysteresisCM). Here we encode TOP + rearmEps as (target + (heightDelta + rearmEps)).
  public let hysteresisCM: Double
  /// True when we are armed (have a valid TOP and are waiting to go DOWN).
  public let metTopGate: Bool
  /// Not used in edge-triggered mode (kept for UI layout).
  public let holdElapsed: Double
  /// Current swing from TOP: (TOP - current cm), non-negative.
  public let swingCM: Double

  public init(
    smoothedCM: Double = .nan,
    targetBottomCM: Double = .nan,
    phase: Phase = .calibrating,
    calibrated: Bool = false,
    topEst: Double? = nil,
    botEst: Double? = nil,
    gateAboveCM: Double = 1.0,
    gateBelowCM: Double = 0.0,
    hysteresisCM: Double = 1.5,
    metTopGate: Bool = false,
    holdElapsed: Double = 0,
    swingCM: Double = 0
  ) {
    self.smoothedCM = smoothedCM
    self.targetBottomCM = targetBottomCM
    self.phase = phase
    self.calibrated = calibrated
    self.topEst = topEst
    self.botEst = botEst
    self.gateAboveCM = gateAboveCM
    self.gateBelowCM = gateBelowCM
    self.hysteresisCM = hysteresisCM
    self.metTopGate = metTopGate
    self.holdElapsed = holdElapsed
    self.swingCM = swingCM
  }
}
