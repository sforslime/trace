import CoreLocation
import SwiftData
import SwiftUI

struct LibraryTabView: View {
    @Query(
        filter: #Predicate<Trail> { $0.endedAt != nil },
        sort: [SortDescriptor(\Trail.startedAt, order: .reverse)]
    )
    private var trails: [Trail]

    var body: some View {
        NavigationStack {
            Group {
                if trails.isEmpty {
                    emptyState
                } else {
                    List(trails) { trail in
                        NavigationLink {
                            TrailDetailView(trail: trail, presentation: .review)
                        } label: {
                            TrailRow(trail: trail)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No trails yet")
                .font(.headline)
            Text("Trails you record will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TrailRow: View {
    let trail: Trail

    private var coordinates: [CLLocationCoordinate2D] {
        trail.samples
            .sorted { $0.timestamp < $1.timestamp }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        HStack(spacing: 12) {
            TrailThumbnail(coordinates: coordinates)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(trail.title?.isEmpty == false ? trail.title! : defaultTitle)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(formatDistance(trail.distanceMeters))
                    Text("•")
                    Text(formatDuration(trail.durationSeconds))
                    if trail.waypoints.contains(where: { $0.isDestination }) {
                        Text("•")
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text(trail.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var defaultTitle: String {
        "Trail on \(trail.startedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func formatDistance(_ meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.2f km", meters / 1000)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
