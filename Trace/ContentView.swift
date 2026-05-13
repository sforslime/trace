import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TrailSyncManager.self) private var sync

    var body: some View {
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
