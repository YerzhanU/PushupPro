//
//  ARKitDepthProvider.swift
//  Sensing
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


//  ARKitDepthProvider.swift
//  Sensing

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
  }

  public var samples: AsyncStream<DistanceSample> { stream }

  /// ARKit must be started on the main thread.
  @MainActor
  public func start() async throws {
    print("ARKitDepthProvider: session run")
    guard ARFaceTrackingConfiguration.isSupported else {
      throw NSError(domain: "Sensing", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "TrueDepth not supported on this device"])
    }

    session.delegate = self
    session.delegateQueue = .main

    let cfg = ARFaceTrackingConfiguration()
    cfg.isWorldTrackingEnabled = false
    cfg.isLightEstimationEnabled = false

    session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
  }

  public func stop() {
    Task { @MainActor in
      self.session.pause()
    }
  }

  // MARK: - ARSessionDelegate

  public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    processAnchors(anchors)
  }

  public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    processAnchors(anchors)
  }

  // MARK: - Private

  private func processAnchors(_ anchors: [ARAnchor]) {
    guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

    // z is negative in front of camera; take absolute and convert to cm
    let zMeters = Double(face.transform.columns.3.z)
    let cm = abs(zMeters) * 100.0

    // lightweight low-pass to calm jitter
    let smoothed: Double = {
      guard let last else { return cm }
      let alpha = 0.25
      return last + alpha * (cm - last)
    }()
    last = smoothed

    cont?.yield(DistanceSample(cm: smoothed, t: CACurrentMediaTime()))
  }
    
    // Add to ARKitDepthProvider
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
      #if DEBUG
      print("AR tracking:", camera.trackingState)
      #endif
    }

    public func sessionWasInterrupted(_ session: ARSession) {
      #if DEBUG
      print("AR session interrupted")
      #endif
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
      #if DEBUG
      print("AR session interruption ended – resetting")
      session.run(ARFaceTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
      #endif
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
      #if DEBUG
      print("AR session failed:", error.localizedDescription)
      #endif
    }

}

// Keep ARKit calls on main; we can mark as unchecked Sendable.
extension ARKitDepthProvider: @unchecked Sendable {}
#endif
