//
//  OnboardingView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 05/10/2025.
//


import SwiftUI

public struct OnboardingView: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("pp_hasSeenOnboarding") private var hasSeenOnboarding = false
  @State private var showFAQ = false

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Card(
            systemImage: "iphone.gen2.radiowaves.left.and.right",
            title: "Place your phone",
            bullets: [
              "Lay the phone screen-up on the floor, TrueDepth camera facing up.",
              "Position it near your head/chest — roughly **30–60 cm** away.",
              "Keep the area clear so the sensor sees you cleanly."
            ])

          Card(
            systemImage: "play.circle",
            title: "Start a session",
            bullets: [
              "Tap **Start Session** and begin push-ups.",
              "Rep count ticks with haptics; a live distance bar shows depth.",
              "Open **Advanced settings** under the bar to adjust height/smoothing."
            ])

          Card(
            systemImage: "trophy",
            title: "Leaderboards",
            bullets: [
              "Sign in to appear on **Global** and **Following** boards.",
              "Your daily, monthly, yearly and all-time totals update automatically.",
              "Follow others to see their progress in **Following**."
            ])
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
      }
      .navigationTitle("Quick Start")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            hasSeenOnboarding = true
            dismiss()
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 10) {
          Button {
            showFAQ = true
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "questionmark.circle")
              Text("Read full FAQ")
            }
          }
          .buttonStyle(.bordered)

          Button {
            hasSeenOnboarding = true
            dismiss()
          } label: {
            Text("Got it")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .padding(.horizontal)
          .padding(.bottom, 12)
        }
        .background(.thinMaterial)
      }
      .sheet(isPresented: $showFAQ) {
        FAQView()
      }
    }
  }

  // MARK: - Card
  private struct Card: View {
    let systemImage: String
    let title: String
    let bullets: [String]

    var body: some View {
      VStack(spacing: 20) {
        Image(systemName: systemImage)
          .symbolRenderingMode(.hierarchical)
          .font(.system(size: 56))
          .foregroundStyle(.tint)          // <-- fix: no `.accent`

        Text(title)
          .font(.title2).bold()
          .multilineTextAlignment(.center)

        VStack(alignment: .leading, spacing: 12) {
          ForEach(bullets, id: \.self) { line in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
              Text(LocalizedStringKey(line))
            }
          }
        }
        .frame(maxWidth: 600, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 8)
      }
      .frame(maxWidth: .infinity)
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color(.secondarySystemBackground))
      )
    }
  }
}
