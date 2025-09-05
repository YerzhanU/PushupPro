//
//  HistoryView.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 06/09/2025.
//

//
//  HistoryView.swift
//  AppUI
//

import SwiftUI
import Sessions

public struct HistoryView: View {
  @State private var metas: [SessionMeta] = []
  @State private var selected: Sessions.Session?   // qualify to avoid any type clashes
  private let store = SessionStore()

  public init() {}

  public var body: some View {
    List {
      ForEach(metas, id: \.id) { m in               // use the non-binding initializer
        Button {
          do { selected = try store.load(id: m.id) } catch { /* ignore for now */ }
        } label: {
          HStack {
            VStack(alignment: .leading) {
              // Date + time inline
              Text(m.startedAt, style: .date) + Text(" ") + Text(m.startedAt, style: .time)
              Text("\(m.totalReps) reps • \(String(format: "%.1f", m.heightDeltaCM)) cm")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
          }
        }
      }

      if metas.isEmpty {
        Text("No sessions yet").foregroundStyle(.secondary)
      }
    }
    .navigationTitle("History")
    .onAppear { refresh() }
    .navigationDestination(item: $selected) { (s: Sessions.Session) in
      SessionSummaryView(session: s)
    }
  }

  private func refresh() {
    metas = (try? store.loadAllMetas(limit: 50)) ?? []
  }
}
