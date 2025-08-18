//
//  DistanceSample.swift
//  Sensing
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import Foundation

/// One distance reading (cm) from camera to face/chest.
public struct DistanceSample: Sendable {
  public let cm: Double
  public let t: TimeInterval
  public init(cm: Double, t: TimeInterval) { self.cm = cm; self.t = t }
}

/// Async stream of distance samples.
public protocol DistanceProvider: AnyObject, Sendable {
  var samples: AsyncStream<DistanceSample> { get }
  func start() async throws
  func stop()
}
