//
//  FAQView.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 05/10/2025.
//

import SwiftUI

public struct FAQView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var showQuickStart = false

  public init() {}

  public var body: some View {
    NavigationStack {
      List {
        // Quick-Start entry
        Section {
          Button {
            showQuickStart = true
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "sparkles.rectangle.stack")
              Text("View Quick Start")
              Spacer()
              Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
        }

        Section("Quick Basics") {
          Disclosure("How should I place the phone?") {
            Text("""
            Lay the phone **screen-up** on the floor with the front TrueDepth camera facing up.
            Place it at **head level** — roughly in line with your **forehead** — about **30–60 cm** away.
            Keep the long edge roughly parallel to your shoulders. Use a hard, flat surface and keep the phone steady.
            """)
          }
          Disclosure("How are reps detected?") {
            Text("""
            We track distance to your face via the TrueDepth camera. A rep counts when you go
            **below your target height** and then return to the top with sufficient tempo.
            """)
          }
          Disclosure("Where are my sessions saved?") {
            Text("""
            Sessions always save on your device. If you sign in, they also sync to your account and appear on leaderboards.
            You can import existing local sessions to your account from Account.
            """)
          }
        }

        Section("Leaderboards & Social") {
          Disclosure("Why am I not on the Global board?") {
            Text("Only signed-in users appear on Global. Sign in and complete at least one session.")
          }
          Disclosure("Following vs Followers") {
            Text("""
            Follow is one-way. Your **Following** board shows those you follow (plus you).
            **Followers** shows people who follow you (plus you).
            """)
          }
          Disclosure("Periods (Today / Month / Year / All-time)") {
            Text("""
            Periods roll over in **UTC**. We compare by score, then by the **earliest time** you reached it.
            """)
          }
        }

        Section("Privacy") {
          Disclosure("Do you store face data?") {
            Text("""
            No. We never store images or raw face geometry. Only numeric distances and session stats
            are saved; cloud sync stores workout data tied to your account.
            """)
          }
        }
      }
      .navigationTitle("Instructions & FAQ")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(isPresented: $showQuickStart) {
        OnboardingView()
      }
    }
  }
}

private struct Disclosure: View {
  let title: String
  let content: () -> Text

  init(_ title: String, @ViewBuilder content: @escaping () -> Text) {
    self.title = title
    self.content = content
  }

  var body: some View {
    DisclosureGroup(title) {
      content().padding(.vertical, 6)
    }
  }
}
