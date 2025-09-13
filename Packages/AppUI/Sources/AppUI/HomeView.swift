//
//  HomeView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI

public struct HomeView: View {
  // Factory for building the live screen; default keeps existing behavior working.
  private let makeLive: () -> LiveSessionView
  @State private var showLive = false

  public init(makeLive: @escaping () -> LiveSessionView = { LiveSessionView() }) {
    self.makeLive = makeLive
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Push-ups")
          .font(.largeTitle).bold()

        Button("Start Session") { showLive = true }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)

        // Quick link to saved sessions
        NavigationLink {
          HistoryView()
        } label: {
          Label("History", systemImage: "clock.arrow.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        // Tip now points users to the in-session gear
        ProTip()

        Spacer()
      }
      .padding()
      .navigationTitle("Home")
      .navigationDestination(isPresented: $showLive) {
        makeLive()  // <- app injects LiveSessionView with callback
      }
    }
  }
}

/// Small banner with a general tip (no height controls here anymore).
public struct ProTip: View {
  public init() {}
  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lightbulb")
      Text("You can fine-tune push-up detection (height, re-arm, smoothing) inside a session via the gear icon.")
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
  }
}
