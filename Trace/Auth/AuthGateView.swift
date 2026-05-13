import SwiftUI

struct AuthGateView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        switch auth.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .signedOut:
            AuthView()
        case .signedIn:
            ContentView()
        }
    }
}
