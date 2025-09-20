//
//  HomeView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//


// Packages/AppUI/Sources/AppUI/HomeView.swift

import SwiftUI
import Sessions

public struct HomeView: View {
  // Existing factories
  private let makeLive: () -> LiveSessionView
  private let makeHistory: () -> AnyView

  // NEW: account button hook + state for icon fill
  private let onTapAccount: (() -> Void)?
  private let isSignedIn: Bool

  // Default initializer keeps existing callers working
  public init(
    makeLive: @escaping () -> LiveSessionView = { LiveSessionView() },
    makeHistory: @escaping () -> AnyView = { AnyView(HistoryView()) },
    onTapAccount: (() -> Void)? = nil,
    isSignedIn: Bool = false
  ) {
    self.makeLive = makeLive
    self.makeHistory = makeHistory
    self.onTapAccount = onTapAccount
    self.isSignedIn = isSignedIn
  }

  @State private var showLive = false

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Push-ups")
          .font(.largeTitle).bold()

        Button("Start Session") { showLive = true }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)

        NavigationLink {
          HistoryView()
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
      .navigationDestination(isPresented: $showLive) {
        makeLive()
      }
      // NEW: render the toolbar INSIDE this NavigationStack
      .toolbar {
        if let onTapAccount {
          ToolbarItem(placement: .topBarTrailing) {
            Button(action: onTapAccount) {
              Image(systemName: isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
            }
            .accessibilityLabel("Account")
          }
        }
      }
    }
  }
}

/// Tip banner (unchanged)
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
