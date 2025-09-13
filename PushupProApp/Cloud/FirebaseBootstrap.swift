//
//  FirebaseBootstrap.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import FirebaseCore
import FirebaseFirestore

enum FirebaseBootstrap {
  static func configureIfNeeded() {
    guard FirebaseApp.app() == nil else { return }
    FirebaseApp.configure()
    let db = Firestore.firestore()
    var settings = db.settings
    settings.cacheSettings = MemoryCacheSettings()
    db.settings = settings
    assert(Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           "GoogleService-Info.plist missing from app bundle")
  }
}
