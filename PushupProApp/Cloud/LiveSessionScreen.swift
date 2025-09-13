//
//  LiveSessionScreen.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import SwiftUI
import AppUI
import Sessions

struct LiveSessionScreen: View {
  @StateObject private var auth = CloudAuth.shared

  var body: some View {
    LiveSessionView { session in
      guard let uid = auth.uid else { return } // not signed in → skip upload
      Task {
        do { try await SessionUploader().upload(session: session, for: uid) }
        catch { print("Cloud upload failed:", error.localizedDescription) }
      }
    }
  }
}
