import SwiftData
import SwiftUI

@main
struct TraceApp: App {
    @State private var auth = AuthManager()
    @State private var recorder = TrailRecorder()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environment(auth)
                .environment(recorder)
        }
        .modelContainer(for: [Trail.self, TrailSample.self, Waypoint.self])
    }
}
