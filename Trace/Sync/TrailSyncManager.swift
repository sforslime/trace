import Foundation
import Observation
import SwiftData
import Supabase

@Observable
@MainActor
final class TrailSyncManager {
    enum Status: Equatable {
        case idle
        case working
        case error(String)
    }

    private(set) var status: Status = .idle

    private var modelContext: ModelContext?
    private var inFlight = false

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Drains the pending-trails queue. Safe to call repeatedly — no-op if a
    /// sync is already in flight. Stops at the first failure and will retry
    /// next time it's invoked (on trail-end, app-foreground, or sign-in).
    func syncPending() async {
        guard !inFlight, let modelContext else { return }
        inFlight = true
        defer { inFlight = false }

        status = .working

        let descriptor = FetchDescriptor<Trail>(
            predicate: #Predicate { $0.endedAt != nil && !$0.isSynced },
            sortBy: [SortDescriptor(\.startedAt)]
        )

        let pending: [Trail]
        do {
            pending = try modelContext.fetch(descriptor)
        } catch {
            status = .error(error.localizedDescription)
            return
        }

        guard !pending.isEmpty else {
            status = .idle
            return
        }

        for trail in pending {
            do {
                try await upload(trail: trail)
                trail.isSynced = true
                try? modelContext.save()
            } catch {
                status = .error(error.localizedDescription)
                return
            }
        }

        status = .idle
    }

    private func upload(trail: Trail) async throws {
        let sortedSamples = trail.samples.sorted { $0.timestamp < $1.timestamp }
        let coords = sortedSamples.map { [$0.longitude, $0.latitude] }

        guard coords.count >= 2 else { return }
        guard let endedAt = trail.endedAt else { return }

        let destination = trail.waypoints.first { $0.isDestination }

        let params = UploadTrailParams(
            trailId: trail.id,
            startedAt: trail.startedAt,
            endedAt: endedAt,
            coords: coords,
            distanceMeters: trail.distanceMeters,
            stepCount: trail.stepCount,
            durationSeconds: trail.durationSeconds,
            title: trail.title,
            destinationLng: destination?.longitude,
            destinationLat: destination?.latitude,
            destinationName: destination?.name
        )

        try await Supa.client
            .rpc("upload_trail", params: params)
            .execute()
    }
}

private struct UploadTrailParams: Encodable {
    let trailId: UUID
    let startedAt: Date
    let endedAt: Date
    let coords: [[Double]]
    let distanceMeters: Double
    let stepCount: Int
    let durationSeconds: Int
    let title: String?
    let destinationLng: Double?
    let destinationLat: Double?
    let destinationName: String?

    enum CodingKeys: String, CodingKey {
        case trailId = "trail_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case coords
        case distanceMeters = "distance_meters"
        case stepCount = "step_count"
        case durationSeconds = "duration_seconds"
        case title
        case destinationLng = "destination_lng"
        case destinationLat = "destination_lat"
        case destinationName = "destination_name"
    }
}
