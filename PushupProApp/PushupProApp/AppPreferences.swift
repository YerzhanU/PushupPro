//
//  AppPreferences.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import Foundation

public struct AppPreferences: Codable {
  public var autoHeight = true
  public var targetHeightCM: Int = 10
  public var hapticsEnabled = true
}
