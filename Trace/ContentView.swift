import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TrailSyncManager.self) private var sync

    var body: some View {
        VStack(spacing: 0) {
            if case let .error(message) = sync.status {
                SyncErrorBanner(message: message) {
                    Task { await sync.syncPending() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            TabView {
                MapTabView()
                    .tabItem { Label("Map", systemImage: "map") }

                TrailTabView()
                    .tabItem { Label("Trail", systemImage: "figure.hiking") }

                LibraryTabView()
                    .tabItem { Label("Library", systemImage: "books.vertical") }

                ProfileTabView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
        }
        .animation(.snappy, value: sync.status)
        .onAppear {
            sync.attach(modelContext: modelContext)
            Task { await sync.syncPending() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await sync.syncPending() }
            }
        }
    }
}

private struct SyncErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text("Couldn't sync your trails")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Retry", action: onRetry)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.red)
    }
}
