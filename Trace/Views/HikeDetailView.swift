import CoreLocation
import SwiftData
import SwiftUI

struct HikeDetailView: View {
    enum Presentation {
        case summary  // sheet right after a hike ends
        case review   // pushed from Library
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var hike: Hike
    var presentation: Presentation = .review

    @State private var showDeleteConfirm = false

    private var coordinates: [CLLocationCoordinate2D] {
        hike.samples
            .sorted { $0.timestamp < $1.timestamp }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var destination: CLLocationCoordinate2D? {
        guard let pin = hike.waypoints.first(where: { $0.isDestination }) else { return nil }
        return CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mapPreview
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    TextField("Hike title", text: titleBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.weight(.semibold))

                    statsBlock
                }
                .padding(16)
            }
            .navigationTitle(presentation == .summary ? "Hike complete" : "Hike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if presentation == .summary {
                        Button("Done") {
                            try? modelContext.save()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    } else {
                        Menu {
                            Button("Delete hike", systemImage: "trash", role: .destructive) {
                                showDeleteConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                if presentation == .summary {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Discard", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete this hike?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteHike() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The trail, samples, and waypoints will be removed.")
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { hike.title ?? "" },
            set: { hike.title = $0.isEmpty ? nil : $0 }
        )
    }

    private var mapPreview: some View {
        MapLibreMapView(
            showsUserLocation: false,
            followsUser: false,
            breadcrumb: coordinates,
            destination: destination,
            fitBounds: coordinates,
            interactive: true
        )
    }

    private var statsBlock: some View {
        VStack(spacing: 0) {
            row("Distance", formatDistance(hike.distanceMeters))
            Divider()
            row("Duration", formatDuration(hike.durationSeconds))
            Divider()
            row("Average pace", formatPace(meters: hike.distanceMeters, seconds: hike.durationSeconds))
            Divider()
            row("Started", hike.startedAt.formatted(date: .abbreviated, time: .shortened))
            if let endedAt = hike.endedAt {
                Divider()
                row("Ended", endedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if destination != nil {
                Divider()
                row("Destination", "Pinned")
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func deleteHike() {
        modelContext.delete(hike)
        try? modelContext.save()
        dismiss()
    }

    private func formatDistance(_ meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.2f km", meters / 1000)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private func formatPace(meters: Double, seconds: Int) -> String {
        guard meters > 50, seconds > 0 else { return "—" }
        let kmh = (meters / Double(seconds)) * 3.6
        return String(format: "%.1f km/h", kmh)
    }
}
