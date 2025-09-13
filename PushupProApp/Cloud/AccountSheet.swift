//
//  AccountSheet.swift
//  PushupProApp
//
//  Created by Yerzhan Utkelbayev on 13/09/2025.
//


import SwiftUI

struct AccountSheet: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var auth = CloudAuth.shared

  @State private var email = ""
  @State private var password = ""
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        if let e = auth.email {
          // Signed in
          Label(e, systemImage: "person.crop.circle")

          Button("Sign out") {
            do {
              try auth.signOut()
              dismiss()
            } catch let err {
              errorMessage = err.localizedDescription
            }
          }
        } else {
          // Not signed in
          TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)

          SecureField("Password", text: $password)

          HStack {
            Button("Sign in") {
              Task { await signIn() }
            }
            .buttonStyle(.borderedProminent)

            Button("Sign up") {
              Task { await signUp() }
            }
            .buttonStyle(.bordered)
          }
        }

        if let msg = errorMessage {
          Text(msg)
            .foregroundStyle(.red)
        }
      }
      .navigationTitle("Account")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  // MARK: - Actions
  @MainActor
  private func signIn() async {
    do {
      try await auth.signIn(email: email, password: password)
      errorMessage = nil
      dismiss()
    } catch let err {
      errorMessage = err.localizedDescription
    }
  }

  @MainActor
  private func signUp() async {
    do {
      try await auth.signUp(email: email, password: password)
      errorMessage = nil
      dismiss()
    } catch let err {
      errorMessage = err.localizedDescription
    }
  }
}
