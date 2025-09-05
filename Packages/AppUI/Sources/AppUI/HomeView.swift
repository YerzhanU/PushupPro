//
//  HomeView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


import SwiftUI

public struct HomeView: View {
  @State private var showLive = false

  public init() {}

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Push-ups")
          .font(.largeTitle).bold()

        Button("Start Session") { showLive = true }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)

        // Quick link to saved sessions (M3)
        NavigationLink {
          HistoryView()
        } label: {
          Label("History", systemImage: "clock.arrow.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        HeightChip()
        ProTip()
        Spacer()
      }
      .padding()
      .navigationTitle("Home")
      .navigationDestination(isPresented: $showLive) {
        LiveSessionView() // ensure LiveSessionView is public in AppUI
      }
    }
  }
}

/// Quick access height control + auto indicator (copy unchanged for now)
public struct HeightChip: View {
  public init() {}
  public var body: some View {
    HStack {
      Image(systemName: "arrow.up.and.down.circle")
      Text("Height: Auto (10 cm)")
      Spacer()
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

/// Banner shown on first screen with the note about height.
public struct ProTip: View {
  public init() {}
  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lightbulb")
      Text("Pro tip: set your push-up height. It’s automatic by default, and you can adjust anytime.")
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
  }
}
