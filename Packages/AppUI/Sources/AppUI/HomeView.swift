//
//  HomeView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 18/08/2025.
//

import SwiftUI
import Sessions

public struct HomeView: View {
  // Existing factories
  private let makeLive: () -> LiveSessionView
  private let makeHistory: () -> AnyView

  // Account button hook + state for icon fill
  private let onTapAccount: (() -> Void)?
  private let isSignedIn: Bool

  // Defaults keep existing callers working
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

  // MARK: - State
  @State private var showLive = false
  @AppStorage("pp_hasSeenOnboarding") private var hasSeenOnboarding = false
  @State private var showOnboarding = false
  @State private var showFAQ = false

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Push-ups")
          .font(.largeTitle).bold()

        Button("Start Session") { showLive = true }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)

        // History (use injected factory)
        NavigationLink {
          makeHistory()
        } label: {
          Label("History", systemImage: "clock.arrow.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        // NEW: Instructions & FAQ
        Button {
          showFAQ = true
        } label: {
          Label("Instructions & FAQ", systemImage: "questionmark.circle")
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
      // Toolbar INSIDE this NavigationStack
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
      // Auto-show Quick Start on first launch
      .task {
        if !hasSeenOnboarding {
          // small delay for smoother presentation after first frame
          try? await Task.sleep(nanoseconds: 200_000_000)
          showOnboarding = true
        }
      }
      // Sheets
      .sheet(isPresented: $showOnboarding) { OnboardingView() }
      .sheet(isPresented: $showFAQ) { FAQView() }
    }
  }
}

/// Tip banner
public struct ProTip: View {
  public init() {}
  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lightbulb")
      Text("You can fine-tune detection in-session via **Advanced settings** under the distance bar.")
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
  }
}
