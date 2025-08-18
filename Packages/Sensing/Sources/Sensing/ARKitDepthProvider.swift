//
//  ARKitDepthProvider.swift
//  Sensing
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


#if canImport(ARKit)
import ARKit
import Foundation
import QuartzCore

public final class ARKitDepthProvider: NSObject, DistanceProvider, ARSessionDelegate {
  private let session = ARSession()
  private var stream: AsyncStream<DistanceSample>!
  private var cont: AsyncStream<DistanceSample>.Continuation?
  private var last: Double?

  public override init() {
    super.init()
    stream = AsyncStream { [weak self] c in self?.cont = c }
    session.delegate = self
  }

  public var samples: AsyncStream<DistanceSample> { stream }

  public func start() async throws {
    guard ARFaceTrackingConfiguration.isSupported else {
      throw NSError(domain: "Sensing", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "TrueDepth not supported"])
    }
    let cfg = ARFaceTrackingConfiguration()
    cfg.isWorldTrackingEnabled = false
    session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
  }

  public func stop() { session.pause() }

  // ARSessionDelegate is nonisolated; this matches the requirement.
  public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    for a in anchors {
      guard let face = a as? ARFaceAnchor else { continue }
      let meters = Double(-face.transform.columns.3.z)
      let cm = meters * 100.0

      // lightweight low-pass
      let smoothed: Double = {
        guard let last else { return cm }
        let alpha = 0.25
        return last + alpha * (cm - last)
      }()
      last = smoothed

      cont?.yield(.init(cm: smoothed, t: CACurrentMediaTime()))
    }
  }
}

// We promise we’ll use this on the main thread / safely.
// This silences Swift 6’s Sendable warning when capturing the existential.
extension ARKitDepthProvider: @unchecked Sendable {}
#endif
