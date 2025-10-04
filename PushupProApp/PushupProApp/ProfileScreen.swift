//
//  ProfileScreen.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 04/10/2025.
//


// ProfileScreen.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileScreen: View {
  let uid: String

  @State private var displayName: String?
  @State private var handle: String?
  @State private var photoURL: String?
  @State private var isFollowing = false
  @State private var loading = true
  @State private var err: String?
  @State private var period: LBPeriod = .todayUTC
  @State private var score: Int = 0

  private let db = Firestore.firestore()
  private var isMe: Bool { Auth.auth().currentUser?.uid == uid }

  var body: some View {
    VStack(spacing: 16) {
      header
      Picker("Period", selection: $period) {
        Text("Today").tag(LBPeriod.todayUTC)
        Text("Month").tag(LBPeriod.thisMonthUTC)
        Text("Year").tag(LBPeriod.thisYearUTC)
        Text("All-time").tag(LBPeriod.allTime)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      GroupBox {
        HStack {
          Text("Reps").font(.headline)
          Spacer()
          Text("\(score)").font(.title2).monospaced()
        }
      }
      .padding(.horizontal)

      Spacer()
    }
    .navigationTitle(displayName ?? "Profile")
    .navigationBarTitleDisplayMode(.inline)
    .overlay { if loading { ProgressView() } }
    .task { await loadAll() }
    .onChange(of: period) { _ in Task { await loadRollup() } }
    .alert("Error", isPresented: Binding(get: { err != nil }, set: { if !$0 { err = nil } })) {
      Button("OK", role: .cancel) { err = nil }
    } message: { Text(err ?? "") }
  }

  private var header: some View {
    HStack(spacing: 16) {
      AsyncImage(url: URL(string: photoURL ?? "")) { img in
        img.resizable().scaledToFill()
      } placeholder: { Color.gray.opacity(0.2) }
      .frame(width: 64, height: 64).clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(displayName ?? "User").font(.title3).bold()
        if let h = handle { Text("@\(h)").foregroundStyle(.secondary) }
      }
      Spacer()
      if !isMe, let me = Auth.auth().currentUser, !me.isAnonymous {
        Button(isFollowing ? "Unfollow" : "Follow") {
          Task {
            do {
              if isFollowing { try await FollowsService.unfollow(uid) }
              else { try await FollowsService.follow(uid) }
              isFollowing.toggle()
            } catch { err = error.localizedDescription }
          }
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(.horizontal)
  }

  private func loadAll() async {
    loading = true; defer { loading = false }
    do {
      let prof = try await ProfileService.shared.loadProfile(uid: uid)
      displayName = prof.displayName
      handle = prof.handle
      photoURL = prof.photoURL
      if !isMe {
        isFollowing = (try? await FollowsService.isFollowing(uid)) ?? false
      }
      await loadRollup()
    } catch { err = error.localizedDescription }
  }

  private func loadRollup() async {
    do {
      let doc = try await db.collection("users").document(uid)
        .collection("rollups").document(period.key).getDocument()
      score = (doc.get("score") as? Int) ?? 0
    } catch { err = error.localizedDescription }
  }
}
