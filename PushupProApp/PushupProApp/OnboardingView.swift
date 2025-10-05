//
//  OnboardingView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 05/10/2025.
//


// OnboardingView.swift
import SwiftUI

public struct OnboardingView: View {
  public init() {}

  // State
  @Environment(\.dismiss) private var dismiss
  @AppStorage("pp_hasSeenOnboarding") private var hasSeenOnboarding = false
  @State private var page = 0
  @State private var showFAQ = false

  public var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Paged cards
        TabView(selection: $page) {
          Card(
            systemImage: "iphone.gen3",
            title: "Place the phone on the floor",
            bullets: [
              "Screen facing up, camera near your head/chest (≈ 30–60 cm).",
              "Keep the TrueDepth camera unobstructed.",
              "You’ll see a live distance bar; green tick = rep."
            ]
          ).tag(0)

          Card(
            systemImage: "faceid",
            title: "TrueDepth powers tracking",
            bullets: [
              "We measure distance to your face/chest at ≥30 Hz.",
              "No face images are stored; only numeric samples."
            ]
          ).tag(1)

          Card(
            systemImage: "play.circle.fill",
            title: "Start Session = auto counting",
            bullets: [
              "Correct-depth reps tick with haptics.",
              "Too fast/too shallow = flagged."
            ]
          ).tag(2)

          Card(
            systemImage: "slider.horizontal.3",
            title: "Tune your height & sensitivity",
            bullets: [
              "Tap “Advanced settings” in a session.",
              "Set push-up height; adjust smoothing & re-arm."
            ]
          ).tag(3)

          Card(
            systemImage: "trophy.fill",
            title: "History & Leaderboard",
            bullets: [
              "History shows all your sessions.",
              "Sign in to appear on Global/Following leaderboards."
            ]
          ).tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(maxHeight: .infinity)

        // Controls
        HStack {
          Button("Skip") { finish() }
            .opacity(page < 4 ? 1 : 0)

          Spacer()

          Button(page < 4 ? "Next" : "Got it") {
            if page < 4 { withAnimation { page += 1 } }
            else { finish() }
          }
          .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
      }
      .navigationTitle("Quick Start")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("FAQ") { showFAQ = true }
        }
      }
      .sheet(isPresented: $showFAQ) { FAQView() }
    }
  }

  private func finish() {
    hasSeenOnboarding = true
    dismiss()
  }
}

// MARK: - Card

private struct Card: View {
  let systemImage: String
  let title: String
  let bullets: [String]

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Image(systemName: systemImage)
          .font(.system(size: 56))
          .foregroundStyle(.tint)              // <- fix for .accent
          .padding(.top, 24)

        Text(title)
          .font(.title2).bold()
          .multilineTextAlignment(.center)

        VStack(alignment: .leading, spacing: 12) {
          ForEach(bullets, id: \.self) { line in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
              Text(line)
            }
          }
        }
        .frame(maxWidth: 600, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 24)
      }
      .frame(maxWidth: .infinity)
    }
  }
}
