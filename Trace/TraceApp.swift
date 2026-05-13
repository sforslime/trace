import SwiftData
import SwiftUI

@main
struct TraceApp: App {
    @State private var auth = AuthManager()
    @State private var recorder = HikeRecorder()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environment(auth)
                .environment(recorder)
        }
        .modelContainer(for: [Hike.self, HikeSample.self, Waypoint.self])
    }
}
