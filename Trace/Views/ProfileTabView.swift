import SwiftUI

struct ProfileTabView: View {
    @Environment(AuthManager.self) private var auth

    @State private var isSigningOut = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if case .signedIn(let user) = auth.state {
                    Section("Account") {
                        LabeledContent("Email", value: user.email ?? "—")
                        LabeledContent("User ID", value: String(user.id.uuidString.prefix(8)))
                            .font(.subheadline)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await signOut() }
                    } label: {
                        HStack {
                            if isSigningOut {
                                ProgressView()
                            }
                            Text("Sign out")
                        }
                    }
                    .disabled(isSigningOut)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func signOut() async {
        errorMessage = nil
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
