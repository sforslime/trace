import SwiftData
import SwiftUI

@main
struct HikeApp: App {
    @State private var recorder = HikeRecorder()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(recorder)
        }
        .modelContainer(for: [Hike.self, HikeSample.self, Waypoint.self])
    }
}
