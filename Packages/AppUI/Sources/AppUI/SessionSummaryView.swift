//
//  SessionSummaryView.swift
//  AppUI
//
//  Created by Yerzhan Utkelbayev on 06/09/2025.
//

import SwiftUI
import Sessions

public struct SessionSummaryView: View {
  public let session: Session
  public var onDone: (() -> Void)?

  @State private var exportStatus: String?

  public init(session: Session, onDone: (() -> Void)? = nil) {
    self.session = session
    self.onDone = onDone
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Session Summary").font(.largeTitle).bold()
          Spacer()
          Button("Done") { onDone?() }.buttonStyle(.borderedProminent)
        }

        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.headline)

        // Big number
        Text("\(session.totalReps)")
          .font(.system(size: 96, weight: .black, design: .rounded))

        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
          GridRow {
            Label("Duration", systemImage: "clock")
            Text(formatDuration(session.durationSec))
          }
          GridRow {
            Label("Avg cadence", systemImage: "metronome")
            Text(String(format: "%.1f rpm", session.avgCadenceRPM))
          }
          GridRow {
            Label("Best 30s", systemImage: "timer")
            Text(String(format: "%.1f rpm", session.bestCadence30sRPM))
          }
          GridRow {
            Label("Height", systemImage: "arrow.up.and.down.circle")
            Text(String(format: "%.1f cm", session.heightDeltaCM))
          }
          GridRow {
            Label("Clean reps", systemImage: "checkmark.seal")
            Text(String(format: "%.0f %%", session.percentClean * 100))
          }
        }
        .font(.body)

        Divider().padding(.vertical, 8)

        Button {
          do {
            let url = try SessionStore().exportCSV(for: session)
            exportStatus = "Exported to: \(url.lastPathComponent)"
          } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
          }
        } label: {
          Label("Export CSV (dev)", systemImage: "square.and.arrow.up")
        }

        if let exportStatus {
          Text(exportStatus).font(.footnote).foregroundStyle(.secondary)
        }
      }
      .padding()
    }
    .navigationTitle("Summary")
  }

  private func formatDuration(_ sec: Double) -> String {
    let mins = Int(sec) / 60
    let s = Int(sec) % 60
    return String(format: "%dm %02ds", mins, s)
  }
}
