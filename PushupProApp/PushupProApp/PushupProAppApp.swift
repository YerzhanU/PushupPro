//
//  PushupProAppApp.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//

import SwiftUI
import FirebaseCore

@main
struct PushupProAppApp: App {
    init() {
      FirebaseApp.configure()
    }

    var body: some Scene {
      WindowGroup {
        RootView()
      }
    }
}
