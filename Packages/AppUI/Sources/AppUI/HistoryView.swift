//
//  HistoryView.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 06/09/2025.
//

import SwiftUI
import Sessions

public struct HistoryView: View {
  private let client: HistoryClient

  @State private var metas: [SessionMeta] = []
  @State private var selected: Session?
  @State private var isLoading = false
  @State private var error: String?

  public init(client: HistoryClient = .localOnly()) {
    self.client = client
  }

  public var body: some View {
    List {
      ForEach(metas) { m in
        Button {
          Task { await open(id: m.id) }
        } label: {
          HStack {
            VStack(alignment: .leading) {
              Text(m.startedAt, style: .date) + Text(" ") + Text(m.startedAt, style: .time)
              Text("\(m.totalReps) reps • \(String(format: "%.1f", m.heightDeltaCM)) cm")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
          }
        }
      }
      if metas.isEmpty && !isLoading {
        Text("No sessions yet").foregroundStyle(.secondary)
      }
    }
    .overlay {
      if isLoading {
        ProgressView().controlSize(.large)
      } else if let error {
        VStack(spacing: 8) {
          Text("Couldn’t load history").bold()
          Text(error).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
          Button("Retry") { Task { await refresh() } }
        }
        .padding()
      }
    }
    .navigationTitle("History")
    .refreshable { await refresh() }
    .task { await refresh() }
    .navigationDestination(item: $selected) { s in
      SessionSummaryView(session: s)
    }
  }

  @MainActor
  private func refresh() async {
    isLoading = true; error = nil
    do {
      let list = try await client.fetchMetas()
      metas = list
    } catch {
      self.error = error.localizedDescription
    }
    isLoading = false
  }

  private func open(id: UUID) async {
    do {
      let s = try await client.loadSession(id)
      await MainActor.run { selected = s }
    } catch {
      await MainActor.run { self.error = error.localizedDescription }
    }
  }
}
