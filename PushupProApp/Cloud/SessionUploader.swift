//
//  SessionUploader.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import Foundation
import FirebaseFirestore
import Sessions

/// Writes one document per session under users/{uid}/sessions/{sessionId}
struct SessionUploader {
  func upload(session: Session, for uid: String) async throws {
    let db = Firestore.firestore()
    let doc = db.collection("users").document(uid)
      .collection("sessions").document(session.id.uuidString)

    let data: [String: Any] = [
      "id": session.id.uuidString,
      "startedAt": Timestamp(date: session.startedAt),
      "endedAt": Timestamp(date: session.endedAt),
      "totalReps": session.totalReps,
      "durationSec": session.durationSec,
      "avgCadenceRPM": session.avgCadenceRPM,
      "bestCadence30sRPM": session.bestCadence30sRPM,
      "heightDeltaCM": session.heightDeltaCM,
      "percentClean": session.percentClean
    ]
    try await doc.setData(data, merge: true)
  }
}
