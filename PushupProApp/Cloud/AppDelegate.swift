//
//  AppDelegate.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import UIKit
import FirebaseCore
import FirebaseFirestore

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

    assert(Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           "Missing GoogleService-Info.plist in app target")

    FirebaseApp.configure()

    // Optional cache config (safe after configure)
    let db = Firestore.firestore()
    let settings = db.settings
    settings.cacheSettings = MemoryCacheSettings()
    db.settings = settings

    print("Firebase configured at launch:", FirebaseApp.app() != nil)
    return true
  }
}
