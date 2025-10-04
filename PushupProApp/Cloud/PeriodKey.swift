//
//  PeriodKey.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 04/10/2025.
//


import Foundation

enum PeriodKey {
  private static var calUTC: Calendar = {
    var c = Calendar(identifier: .iso8601)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }()

  static func daily(_ date: Date) -> String {
    let c = calUTC
    let y = c.component(.year, from: date)
    let m = c.component(.month, from: date)
    let d = c.component(.day, from: date)
    return String(format: "daily:%04d-%02d-%02d", y, m, d)
  }

  static func monthly(_ date: Date) -> String {
    let c = calUTC
    let y = c.component(.year, from: date)
    let m = c.component(.month, from: date)
    return String(format: "monthly:%04d-%02d", y, m)
  }

  static func yearly(_ date: Date) -> String {
    let y = calUTC.component(.year, from: date)
    return "yearly:\(y)"
  }

  static func allTime() -> String { "allTime" }
}
