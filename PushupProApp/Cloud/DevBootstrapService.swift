// DevBootstrapService.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore
import Sessions

/// One-time dev helpers to seed/repair leaderboard data.
final class DevBootstrapService {
  static let shared = DevBootstrapService()
  private init() {}

  private let db = Firestore.firestore()
  private let store = SessionStore() // used by the "local" variant if needed

  // Small aggregate type (visible to all methods)
  private struct Agg { var score: Int = 0; var lastAt: Date? = nil }

  // MARK: Public entry points

  /// One-time boost from *local* sessions (current month + all-time).
  @MainActor
  func boostFromLocalOnce() async throws {
    let (uid, flagRef) = try guardAndMarker(path: .sessionMarks("_devBoost_localToNow"))
    if try await flagRef.getDocument().exists {
      print("[DevBootstrap] Local boost already applied; skip.")
      return
    }

    let (sumAll, sumMonth) = try computeLocalSumsForCurrentMonthUTC()
    try await applyNonDecreasingRollup(uid: uid, periodKey: PeriodKey.allTime(),            targetScore: sumAll,   createFirstAt: nil)
    try await applyNonDecreasingRollup(uid: uid, periodKey: PeriodKey.monthly(Date()),      targetScore: sumMonth, createFirstAt: nil)

    try await flagRef.setData(donePayload(source: "localSessionsOneTimeBoost", all: sumAll, month: sumMonth), merge: true)
    print("[DevBootstrap] LOCAL applied allTime=\(sumAll) month=\(sumMonth)")
  }

  /// One-time boost from *cloud* sessions (current month + all-time).
  @MainActor
  func boostFromCloudOnce() async throws {
    let (uid, flagRef) = try guardAndMarker(path: .sessionMarks("_devBoost_cloudToNow"))
    if try await flagRef.getDocument().exists {
      print("[DevBootstrap] Cloud boost already applied; skip.")
      return
    }

    let now = Date()
    var cal = Calendar(identifier: .iso8601); cal.timeZone = .init(secondsFromGMT: 0)!
    let nowY = cal.component(.year, from: now)
    let nowM = cal.component(.month, from: now)

    let sessSnap = try await db.collection("users").document(uid).collection("sessions").getDocuments()
    var sumAll = 0, sumMonth = 0
    for d in sessSnap.documents {
      let reps = (d.get("totalReps") as? Int) ?? 0
      sumAll += reps
      if let ended = (d.get("endedAt") as? Timestamp)?.dateValue() {
        let y = cal.component(.year, from: ended), m = cal.component(.month, from: ended)
        if y == nowY && m == nowM { sumMonth += reps }
      }
    }

    try await applyNonDecreasingRollup(uid: uid, periodKey: PeriodKey.allTime(),       targetScore: sumAll,    createFirstAt: nil)
    try await applyNonDecreasingRollup(uid: uid, periodKey: PeriodKey.monthly(now),    targetScore: sumMonth,  createFirstAt: nil)

    try await flagRef.setData(donePayload(source: "cloudSessionsOneTimeBoost", all: sumAll, month: sumMonth), merge: true)
    print("[DevBootstrap] CLOUD boost applied allTime=\(sumAll) month=\(sumMonth)")
  }

  /// Historical backfill from CLOUD (day/month/year/all-time by actual session time).
  @MainActor
  func backfillFromCloudHistoricallyOnce(includeDaily: Bool = true,
                                         includeMonthly: Bool = true,
                                         includeYearly: Bool = true,
                                         includeAllTime: Bool = true) async throws {
    let (uid, flagRef) = try guardAndMarker(path: .sessionMarks("_devBackfill_cloudHistory_v1"))
    if try await flagRef.getDocument().exists {
      print("[DevBootstrap] Historical cloud backfill already applied; skip.")
      return
    }

    // 1) Read all sessions ordered by endedAt so we set firstAtScore to the correct instant.
    let sessSnap = try await db.collection("users").document(uid)
      .collection("sessions")
      .order(by: "endedAt") // single-field index is automatic
      .getDocuments()

    // 2) Accumulate per period (UTC)
    var daily:   [String: Agg] = [:]
    var monthly: [String: Agg] = [:]
    var yearly:  [String: Agg] = [:]
    var allAgg  = Agg()

    for d in sessSnap.documents {
      let reps = (d.get("totalReps") as? Int) ?? 0
      guard reps > 0 else { continue }
      let ended = (d.get("endedAt") as? Timestamp)?.dateValue()
        ?? (d.get("startedAt") as? Timestamp)?.dateValue()
        ?? Date()

      if includeDaily {
        let k = PeriodKey.daily(ended); var a = daily[k] ?? Agg()
        a.score += reps; a.lastAt = ended; daily[k] = a
      }
      if includeMonthly {
        let k = PeriodKey.monthly(ended); var a = monthly[k] ?? Agg()
        a.score += reps; a.lastAt = ended; monthly[k] = a
      }
      if includeYearly {
        let k = PeriodKey.yearly(ended); var a = yearly[k] ?? Agg()
        a.score += reps; a.lastAt = ended; yearly[k] = a
      }
      if includeAllTime {
        allAgg.score += reps; allAgg.lastAt = ended
      }
    }

    // 3) Upsert rollups + mirror leaderboard (respect non-decreasing & firstAtScore immutability)
    for (k, a) in daily   { try await upsertPeriod(uid: uid, key: k, agg: a) }
    for (k, a) in monthly { try await upsertPeriod(uid: uid, key: k, agg: a) }
    for (k, a) in yearly  { try await upsertPeriod(uid: uid, key: k, agg: a) }
    if includeAllTime {
      try await applyNonDecreasingRollup(uid: uid,
                                         periodKey: PeriodKey.allTime(),
                                         targetScore: allAgg.score,
                                         createFirstAt: allAgg.lastAt) // only set if creating
    }

    // 4) Done marker
    try await flagRef.setData([
      "doneAt": FieldValue.serverTimestamp(),
      "source": "historicalCloudBackfill",
      "dailyKeys": includeDaily ? Array(daily.keys) : [],
      "monthlyKeys": includeMonthly ? Array(monthly.keys) : [],
      "yearlyKeys": includeYearly ? Array(yearly.keys) : [],
      "allTime": allAgg.score
    ], merge: true)

    print("[DevBootstrap] Historical backfill complete. daily=\(daily.count) monthly=\(monthly.count) yearly=\(yearly.count) all=\(allAgg.score)")
  }

  // MARK: - Helpers

  private enum MarkerPath { case sessionMarks(String) }

  private func guardAndMarker(path: MarkerPath) throws -> (uid: String, flagRef: DocumentReference) {
    guard let u = Auth.auth().currentUser, !u.isAnonymous else {
      throw NSError(domain: "DevBootstrap", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Sign in to run this action."])
    }
    let uid = u.uid
    let flagRef: DocumentReference
    switch path {
    case .sessionMarks(let id):
      flagRef = db.collection("users").document(uid).collection("sessionMarks").document(id)
    }
    return (uid, flagRef)
  }

  private func donePayload(source: String, all: Int, month: Int) -> [String: Any] {
    [
      "doneAt": FieldValue.serverTimestamp(),
      "source": source,
      "allTime": all,
      "monthKey": PeriodKey.monthly(Date()),
      "month": month
    ]
  }

  /// Upsert a period rollup and mirror to leaderboard (accepts Agg to match call sites).
  private func upsertPeriod(uid: String, key: String, agg: Agg) async throws {
    try await applyNonDecreasingRollup(uid: uid,
                                       periodKey: key,
                                       targetScore: agg.score,
                                       createFirstAt: agg.lastAt)
  }

  /// Set rollup score to at least `targetScore` (never decrease).
  /// - If the doc does not exist and `createFirstAt` is provided, set `firstAtScore` to that time.
  /// - If the doc exists, we only bump `score` and never change `firstAtScore`.
  /// Mirrors to global leaderboard with the same values.
  private func applyNonDecreasingRollup(uid: String,
                                        periodKey: String,
                                        targetScore: Int,
                                        createFirstAt: Date?) async throws {
    let rollRef = db.collection("users").document(uid).collection("rollups").document(periodKey)

    let existing = try await rollRef.getDocument()
    if existing.exists {
      let old = (existing.get("score") as? Int) ?? 0
      let newScore = max(old, targetScore)
      try await rollRef.setData([
        "score": newScore,
        "updatedAt": FieldValue.serverTimestamp()
      ], merge: true)
    } else {
      var data: [String: Any] = [
        "score": targetScore,
        "updatedAt": FieldValue.serverTimestamp()
      ]
      if let at = createFirstAt { data["firstAtScore"] = Timestamp(date: at) }
      try await rollRef.setData(data, merge: true)
    }

    // Mirror to leaderboard
    let roll = try await rollRef.getDocument()
    let score = (roll.get("score") as? Int) ?? targetScore
    let first = roll.get("firstAtScore") as? Timestamp

    let lbRef = db.collection("leaderboards").document("global")
      .collection("periods").document(periodKey)
      .collection("entries").document(uid)

    var payload: [String: Any] = [
      "score": score,
      "updatedAt": FieldValue.serverTimestamp()
    ]
    if let first { payload["firstAtScore"] = first }
    try await lbRef.setData(payload, merge: true)
  }

  // ---- local sums helper (used by boostFromLocalOnce)
  private func computeLocalSumsForCurrentMonthUTC() throws -> (all: Int, month: Int) {
    let metas = try store.loadAllMetas(limit: 10_000)
    var totalAll = 0
    var totalMonth = 0

    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!

    let now = Date()
    let nowY = cal.component(.year, from: now)
    let nowM = cal.component(.month, from: now)

    for m in metas {
      guard let s = try? store.load(id: m.id) else { continue }
      totalAll += s.totalReps
      let y  = cal.component(.year, from: s.endedAt)
      let mm = cal.component(.month, from: s.endedAt)
      if y == nowY && mm == nowM {
        totalMonth += s.totalReps
      }
    }
    return (totalAll, totalMonth)
  }
}
