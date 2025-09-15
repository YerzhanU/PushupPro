//
//  HomeView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI

public struct HomeView: View {
  // FACTORIES (app can inject Live + History)
  private let makeLive: () -> LiveSessionView
  private let makeHistory: () -> AnyView

  @State private var showLive = false
  @State private var showHistory = false

  public init(
    makeLive: @escaping () -> LiveSessionView = { LiveSessionView() },
    makeHistory: @escaping () -> AnyView = { AnyView(HistoryView()) }
  ) {
    self.makeLive = makeLive
    self.makeHistory = makeHistory
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Push-ups").font(.largeTitle).bold()

        Button("Start Session") { showLive = true }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)

        Button {
          showHistory = true
        } label: {
          Label("History", systemImage: "clock.arrow.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        ProTip()
        Spacer()
      }
      .padding()
      .navigationTitle("Home")
      .navigationDestination(isPresented: $showLive) { makeLive() }
      .navigationDestination(isPresented: $showHistory) { makeHistory() }
    }
  }
}

/// Small banner with a general tip.
public struct ProTip: View {
  public init() {}
  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lightbulb")
      Text("Your sessions sync to the cloud (when signed in). Open History to review them anytime.")
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
  }
}
