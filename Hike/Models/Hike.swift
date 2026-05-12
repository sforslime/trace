import Foundation
import SwiftData

@Model
final class Hike {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var title: String?
    var distanceMeters: Double
    var stepCount: Int
    var durationSeconds: Int
    var isPublished: Bool
    var isSynced: Bool

    @Relationship(deleteRule: .cascade, inverse: \HikeSample.hike)
    var samples: [HikeSample] = []

    @Relationship(deleteRule: .cascade, inverse: \Waypoint.hike)
    var waypoints: [Waypoint] = []

    init(id: UUID = UUID(), startedAt: Date = .now) {
        self.id = id
        self.startedAt = startedAt
        self.distanceMeters = 0
        self.stepCount = 0
        self.durationSeconds = 0
        self.isPublished = false
        self.isSynced = false
    }
}
