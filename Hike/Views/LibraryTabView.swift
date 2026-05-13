import CoreLocation
import SwiftData
import SwiftUI

struct LibraryTabView: View {
    @Query(
        filter: #Predicate<Hike> { $0.endedAt != nil },
        sort: [SortDescriptor(\Hike.startedAt, order: .reverse)]
    )
    private var hikes: [Hike]

    var body: some View {
        NavigationStack {
            Group {
                if hikes.isEmpty {
                    emptyState
                } else {
                    List(hikes) { hike in
                        NavigationLink {
                            HikeDetailView(hike: hike, presentation: .review)
                        } label: {
                            HikeRow(hike: hike)
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
            Text("No hikes yet")
                .font(.headline)
            Text("Hikes you record will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HikeRow: View {
    let hike: Hike

    private var coordinates: [CLLocationCoordinate2D] {
        hike.samples
            .sorted { $0.timestamp < $1.timestamp }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        HStack(spacing: 12) {
            HikeThumbnail(coordinates: coordinates)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(hike.title?.isEmpty == false ? hike.title! : defaultTitle)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(formatDistance(hike.distanceMeters))
                    Text("•")
                    Text(formatDuration(hike.durationSeconds))
                    if hike.waypoints.contains(where: { $0.isDestination }) {
                        Text("•")
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text(hike.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var defaultTitle: String {
        "Hike on \(hike.startedAt.formatted(date: .abbreviated, time: .omitted))"
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
