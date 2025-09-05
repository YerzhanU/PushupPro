//
//  RepConfig.swift
//  RepEngine
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import Foundation

/// Minimal configuration for edge-triggered push-up detection.
/// Uses a single threshold = (rolling top) - heightDeltaCM.
public struct RepConfig: Sendable, Equatable {
  /// Required drop from the current top to count a rep (cm).
  public var heightDeltaCM: Double
  /// How close to the current top you must get to re-arm the next rep (cm).
  public var rearmEpsCM: Double
  /// Reject reps faster than this (seconds) to avoid chatter.
  public var minRepDuration: Double
  /// Low-pass smoothing factor (0..1). Higher = less smoothing.
  public var smoothingAlpha: Double
  /// Clamp raw cm into this range (guards against AR spikes).
  public var clampMinCM: Double
  public var clampMaxCM: Double
  /// Top decays by this many cm per second when you’re not near the top.
  public var topDecayPerSec: Double

  public init(
    heightDeltaCM: Double = 4.0,
    rearmEpsCM: Double = 0.5,
    minRepDuration: Double = 0.7,
    smoothingAlpha: Double = 0.25,
    clampMinCM: Double = 0.3,
    clampMaxCM: Double = 8.0,
    topDecayPerSec: Double = 0.6
  ) {
    self.heightDeltaCM = heightDeltaCM
    self.rearmEpsCM = rearmEpsCM
    self.minRepDuration = minRepDuration
    self.smoothingAlpha = smoothingAlpha
    self.clampMinCM = clampMinCM
    self.clampMaxCM = clampMaxCM
    self.topDecayPerSec = topDecayPerSec
  }
}

/// Events emitted by the detector.
public enum RepEvent: Sendable, Equatable {
  case rep(count: Int)
  case warningTooFast
}

/// Telemetry for the UI/debug overlay.
public struct RepTelemetry: Sendable {
  public enum Phase: String, Sendable { case up, down, rearming }

  /// Smoothed, clamped cm sample.
  public let smoothedCM: Double
  /// The single threshold used for counting: threshold = topCM - heightDeltaCM.
  public let targetBottomCM: Double
  /// Current rolling top used to compute the threshold.
  public let topCM: Double
  /// Simple phase hint for the UI.
  public let phase: Phase
  /// Whether we’re currently armed to count the next rep.
  public let armed: Bool

  public init(
    smoothedCM: Double = .nan,
    targetBottomCM: Double = .nan,
    topCM: Double = .nan,
    phase: Phase = .up,
    armed: Bool = false
  ) {
    self.smoothedCM = smoothedCM
    self.targetBottomCM = targetBottomCM
    self.topCM = topCM
    self.phase = phase
    self.armed = armed
  }
}
