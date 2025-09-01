//
//  Haptics.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 01/09/2025.
//


import UIKit

@MainActor
public enum Haptics {
  private static let impact = UIImpactFeedbackGenerator(style: .rigid)

  public static func repTick() {
    impact.prepare()
    impact.impactOccurred(intensity: 1.0)
  }

  public static func warning() {
    let gen = UINotificationFeedbackGenerator()
    gen.notificationOccurred(.warning)
  }
}
