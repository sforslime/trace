import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AuthManager {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(User)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.signedOut, .signedOut):
                return true
            case let (.signedIn(a), .signedIn(b)):
                return a.id == b.id
            default:
                return false
            }
        }
    }

    private(set) var state: State = .loading

    init() {
        // authStateChanges emits an initialSession event on subscription,
        // so we don't need a separate "fetch current session" step. The
        // task lives for the app's lifetime — AuthManager is held in
        // @State at the Scene root, so no deinit cleanup is needed.
        Task { @MainActor [weak self] in
            for await change in Supa.client.auth.authStateChanges {
                guard let self else { return }
                self.apply(event: change.event, session: change.session)
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Supa.client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await Supa.client.auth.signUp(email: email, password: password)
        // session is non-nil when email confirmation is disabled or already complete.
        // nil means the user needs to confirm their email before signing in.
        return response.session != nil
    }

    func signOut() async throws {
        try await Supa.client.auth.signOut()
    }

    private func apply(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            if let user = session?.user {
                state = .signedIn(user)
            } else {
                state = .signedOut
            }
        case .signedOut, .userDeleted:
            state = .signedOut
        default:
            break
        }
    }
}
