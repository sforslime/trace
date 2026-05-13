import Foundation
import SwiftData

@Model
final class Waypoint {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var latitude: Double
    var longitude: Double
    var name: String?
    var note: String?
    var isPublic: Bool
    var isDestination: Bool
    var trail: Trail?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        latitude: Double,
        longitude: Double,
        name: String? = nil,
        note: String? = nil,
        isDestination: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.note = note
        self.isPublic = false
        self.isDestination = isDestination
    }
}
