//
//  SyntheticDepthProvider.swift
//  Sensing
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import Foundation
import QuartzCore

public final class SyntheticDepthProvider: DistanceProvider {
  private var timer: Timer?
  private var stream: AsyncStream<DistanceSample>!
  private var cont: AsyncStream<DistanceSample>.Continuation?

  public init() {
    stream = AsyncStream { [weak self] c in self?.cont = c }
  }

  public var samples: AsyncStream<DistanceSample> { stream }

  public func start() async throws {
    let start = CACurrentMediaTime()              // monotonic start time
    timer = .scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
      let elapsed = CACurrentMediaTime() - start  // seconds since start
      let cm = 10 + 5 * sin(elapsed * 2 * .pi * 0.5) // 0.5 Hz: 10cm ±5cm
      self?.cont?.yield(.init(cm: cm, t: CACurrentMediaTime()))
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  public func stop() { timer?.invalidate(); timer = nil }
}

extension SyntheticDepthProvider: @unchecked Sendable {}
