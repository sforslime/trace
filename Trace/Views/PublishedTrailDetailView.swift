import SwiftUI

struct PublishedTrailDetailView: View {
    let trail: PublishedTrail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber
            content
        }
        .presentationDetents([.fraction(0.35), .medium])
        .presentationDragIndicator(.hidden)
    }

    private var grabber: some View {
        Capsule()
            .fill(.tertiary)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statsRow
            if let destinationName = trail.destinationName, !destinationName.isEmpty {
                destinationRow(destinationName)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle)
                .font(.title3)
                .fontWeight(.semibold)
            Text("by \(trail.authorLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 24) {
            stat("Distance", formatDistance(trail.distanceMeters))
            stat("Duration", formatDuration(trail.durationSeconds))
        }
    }

    private func destinationRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
            Text(name)
                .font(.subheadline)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }

    private var displayTitle: String {
        if let title = trail.title, !title.isEmpty { return title }
        return "Trail"
    }

    private func formatDistance(_ meters: Double?) -> String {
        guard let meters else { return "—" }
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private func formatDuration(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
