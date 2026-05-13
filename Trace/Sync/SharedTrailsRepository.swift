import CoreLocation
import Foundation
import Observation
import Supabase

struct PublishedTrail: Identifiable, Decodable {
    let id: UUID
    let userId: UUID
    let title: String?
    let destinationLng: Double?
    let destinationLat: Double?
    let destinationName: String?
    let coordinates: [CLLocationCoordinate2D]

    var destination: CLLocationCoordinate2D? {
        guard let destinationLng, let destinationLat else { return nil }
        return CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLng)
    }

    private struct LineStringGeo: Decodable {
        let type: String
        let coordinates: [[Double]]
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case destinationLng = "destination_lng"
        case destinationLat = "destination_lat"
        case destinationName = "destination_name"
        case trailGeojson = "trail_geojson"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        destinationLng = try c.decodeIfPresent(Double.self, forKey: .destinationLng)
        destinationLat = try c.decodeIfPresent(Double.self, forKey: .destinationLat)
        destinationName = try c.decodeIfPresent(String.self, forKey: .destinationName)

        let geo = try c.decode(LineStringGeo.self, forKey: .trailGeojson)
        coordinates = geo.coordinates.compactMap {
            guard $0.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        }
    }
}

@Observable
@MainActor
final class SharedTrailsRepository {
    enum Status: Equatable {
        case idle
        case loading
        case error(String)
    }

    private(set) var trails: [PublishedTrail] = []
    private(set) var status: Status = .idle

    private var inFlight = false

    /// Fetches published trails whose geometry intersects the given bbox.
    /// Caller is responsible for debouncing rapid region changes.
    func refresh(minLng: Double, minLat: Double, maxLng: Double, maxLat: Double) async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }

        status = .loading
        do {
            let params = BBoxParams(
                minLng: minLng,
                minLat: minLat,
                maxLng: maxLng,
                maxLat: maxLat
            )
            let response: [PublishedTrail] = try await Supa.client
                .rpc("hikes_in_bbox", params: params)
                .execute()
                .value
            trails = response
            status = .idle
        } catch {
            status = .error(error.localizedDescription)
        }
    }
}

private struct BBoxParams: Encodable {
    let minLng: Double
    let minLat: Double
    let maxLng: Double
    let maxLat: Double

    enum CodingKeys: String, CodingKey {
        case minLng = "min_lng"
        case minLat = "min_lat"
        case maxLng = "max_lng"
        case maxLat = "max_lat"
    }
}
