//
//  LeaderboardScreen.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 03/10/2025.
//


// LeaderboardScreen.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LeaderboardScreen: View {
  var onTapSignIn: (() -> Void)? = nil

  @State private var scope: LBScope = .global
  @State private var period: LBPeriod = .todayUTC
  @State private var query: String = ""
  @State private var rows: [LeaderboardEntry] = []
  @State private var searchingUser: LeaderboardEntry?
  @State private var loading = false
  @State private var errorMessage: String?

  // Following state to control the plus icon
  @State private var followingUids: Set<String> = []
  @State private var followTask: Task<Void, Never>? = nil

  @State private var showAccountSheet = false

  private let svc = LeaderboardService()
  private var signedIn: Bool {
    guard let u = Auth.auth().currentUser else { return false }
    return !u.isAnonymous
  }
  private var myUid: String? { Auth.auth().currentUser?.uid }

  var body: some View {
    NavigationStack {
      Group {
        if signedIn { contentSignedIn }
        else {
          SignInPrompt {
            if let onTapSignIn { onTapSignIn() } else { showAccountSheet = true }
          }
        }
      }
      .navigationTitle("Leaderboard")
      .toolbar {
        if signedIn {
          ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
          }
        }
      }
      .sheet(isPresented: $showAccountSheet) { AccountSheet() }
      .alert("Error",
             isPresented: Binding(get: { errorMessage != nil },
                                  set: { if !$0 { errorMessage = nil } })) {
        Button("OK") { errorMessage = nil }
      } message: { Text(errorMessage ?? "") }
      .task {
        if signedIn {
          await load()
          startFollowingListener()
        }
      }
      .onChange(of: scope) { _ in if signedIn { Task { await load() } } }
      .onChange(of: period) { _ in if signedIn { Task { await load() } } }
      .onChange(of: signedIn) { isIn in
        if isIn { startFollowingListener() } else { stopFollowingListener() }
      }
      .onDisappear { stopFollowingListener() }
    }
  }

  private func startFollowingListener() {
    stopFollowingListener()
    followTask = Task {
      do {
        for try await list in FollowsService.followingUids() {
          await MainActor.run { self.followingUids = Set(list) }
        }
      } catch {
        await MainActor.run { self.errorMessage = error.localizedDescription }
      }
    }
  }
  private func stopFollowingListener() {
    followTask?.cancel()
    followTask = nil
  }

  // MARK: - Signed-in UI
  private var contentSignedIn: some View {
    VStack(spacing: 8) {
      Picker("Scope", selection: $scope) {
        Text("Global").tag(LBScope.global)
        Text("Following").tag(LBScope.following)
        Text("Followers").tag(LBScope.followers)
        Text("Me").tag(LBScope.me)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      Picker("Period", selection: $period) {
        Text("Today").tag(LBPeriod.todayUTC)
        Text("Month").tag(LBPeriod.thisMonthUTC)
        Text("Year").tag(LBPeriod.thisYearUTC)
        Text("All-time").tag(LBPeriod.allTime)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      HStack {
        TextField("Search @handle", text: $query)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)
          .textFieldStyle(.roundedBorder)
        Button { Task { await searchHandle() } } label: {
          Image(systemName: "magnifyingglass")
        }.disabled(query.isEmpty)
      }
      .padding(.horizontal)

      List {
        if let hit = searchingUser {
          Section("Search result") {
            NavigationLink { ProfileScreen(uid: hit.uid) } label: {
              LeaderboardRow(
                entry: hit,
                rank: nil,
                emphasizeMe: hit.uid == myUid,
                showFollowButton: scope != .me,
                isFollowing: followingUids.contains(hit.uid),
                onFollow: { await follow(uid: hit.uid) }
              )
            }
          }
        }
        Section(header: Text(sectionTitle)) {
          ForEach(Array(rows.enumerated()), id: \.1.id) { (idx, e) in
            NavigationLink { ProfileScreen(uid: e.uid) } label: {
              LeaderboardRow(
                entry: e,
                rank: idx + 1,
                emphasizeMe: e.uid == myUid,
                showFollowButton: scope != .me,
                isFollowing: followingUids.contains(e.uid),
                onFollow: { await follow(uid: e.uid) }
              )
            }
          }
        }
      }
      .overlay { if loading { ProgressView() } }
    }
  }

  private func follow(uid: String) async {
    do {
      try await FollowsService.follow(uid)
      // Optimistic: hide the button right away
      followingUids.insert(uid)
    } catch { errorMessage = error.localizedDescription }
  }

  private var sectionTitle: String {
    switch scope {
    case .global: "Global — \(label(period))"
    case .following: "Following — \(label(period))"
    case .followers: "Followers — \(label(period))"
    case .me: "Me — \(label(period))"
    }
  }
  private func label(_ p: LBPeriod) -> String {
    switch p {
    case .todayUTC: "Today"
    case .thisMonthUTC: "This Month"
    case .thisYearUTC: "This Year"
    case .allTime: "All-time"
    }
  }

  // MARK: - Data
  private func load() async {
    loading = true; defer { loading = false }
    do {
      switch scope {
      case .global:
        var list = try await svc.global(period: period)
        if let myUid, !list.contains(where: { $0.uid == myUid }) {
          if let me = try await svc.me(period: period).first {
            list.append(me); list.sort(by: sortEntries)
          }
        }
        rows = list
      case .following: rows = try await svc.following(period: period)
      case .followers: rows = try await svc.followers(period: period)
      case .me:        rows = try await svc.me(period: period)
      }
    } catch { errorMessage = error.localizedDescription }
  }

  private func sortEntries(_ a: LeaderboardEntry, _ b: LeaderboardEntry) -> Bool {
    if a.score != b.score { return a.score > b.score }
    switch (a.firstAtScore, b.firstAtScore) {
    case let (a?, b?): return a < b
    case (nil, _?):    return false
    case (_?, nil):    return true
    default:           return a.uid < b.uid
    }
  }

  private func searchHandle() async {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { searchingUser = nil; return }
    do {
      let db = Firestore.firestore()
      let hDoc = try await db.collection("handles").document(q).getDocument()
      guard hDoc.exists, let uid = hDoc.get("uid") as? String else { searchingUser = nil; return }
      async let roll = db.collection("users").document(uid).collection("rollups").document(period.key).getDocument()
      async let prof = db.collection("users").document(uid).getDocument()
      let r = try await roll; let p = try await prof
      searchingUser = LeaderboardEntry(
        uid: uid,
        score: (r.get("score") as? Int) ?? 0,
        firstAtScore: (r.get("firstAtScore") as? Timestamp)?.dateValue(),
        displayName: (p.get("displayName") as? String)
          ?? (uid == myUid ? (Auth.auth().currentUser?.displayName ??
              Auth.auth().currentUser?.email?.components(separatedBy: "@").first) : nil),
        handle: p.get("handle") as? String,
        photoURL: (p.get("photoURL") as? String)
          ?? (uid == myUid ? Auth.auth().currentUser?.photoURL?.absoluteString : nil)
      )
    } catch { errorMessage = error.localizedDescription }
  }
}

// MARK: - Row
private struct LeaderboardRow: View {
  let entry: LeaderboardEntry
  var rank: Int? = nil
  var emphasizeMe = false
  var showFollowButton = false
  var isFollowing = false
  var onFollow: (() async -> Void)? = nil

  @State private var working = false

  var body: some View {
    HStack(spacing: 12) {
      if let rank { Text("#\(rank)").monospaced().frame(width: 44, alignment: .trailing) }

      AsyncImage(url: URL(string: entry.photoURL ?? "")) { img in
        img.resizable().scaledToFill()
      } placeholder: { Color.gray.opacity(0.2) }
      .frame(width: 36, height: 36).clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.displayName ?? "User").fontWeight(emphasizeMe ? .bold : .regular)
        if let handle = entry.handle {
          Text("@\(handle)").foregroundStyle(.secondary).font(.caption)
        }
      }

      Spacer()
      Text("\(entry.score)").font(.headline).monospaced()

      // Show follow button only if allowed AND not already following
      if showFollowButton, !isFollowing,
         let me = Auth.auth().currentUser, !me.isAnonymous, me.uid != entry.uid {
        Button {
          guard let onFollow else { return }
          Task {
            working = true
            await onFollow()
            working = false
          }
        } label: {
          if working { ProgressView() } else { Image(systemName: "person.badge.plus") }
        }
        .buttonStyle(.borderless)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Gate
private struct SignInPrompt: View {
  let onTap: () -> Void
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "person.crop.circle.badge.exclamationmark")
        .font(.system(size: 56))
        .foregroundStyle(.secondary)
      Text("Sign in to see leaderboards")
        .font(.title3).bold()
      Text("Create an account or sign in to compare your reps with others.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
      Button("Sign in") { onTap() }
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
