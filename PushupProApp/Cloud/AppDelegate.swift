//
//  AppDelegate.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import UIKit
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

final class AppDelegate: NSObject, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {

    // Ensure the plist is present
    assert(Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           "Missing GoogleService-Info.plist in app target")

    FirebaseApp.configure()

    // Optional Firestore cache config (safe after configure)
    let db = Firestore.firestore()
    var settings = db.settings
    settings.cacheSettings = MemoryCacheSettings()
    db.settings = settings

    print("Firebase configured at launch:", FirebaseApp.app() != nil)
    return true
  }

  // Google Sign-In redirect handler
  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // If this URL is for Google, GIDSignIn will consume it and return true.
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return false
  }
}
