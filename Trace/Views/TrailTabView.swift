import SwiftData
import SwiftUI

struct TrailTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TrailRecorder.self) private var recorder

    @State private var summaryTrail: Trail?

    var body: some View {
        ZStack(alignment: .top) {
            MapLibreMapView(
                followsUser: true,
                zoom: recorder.state == .recording ? 17 : 14,
                breadcrumb: recorder.liveCoordinates,
                destination: recorder.destinationCoordinate
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if recorder.state == .recording {
                    statsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()

                if recorder.state == .recording {
                    HStack(spacing: 12) {
                        pinButton
                        endButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                } else {
                    startButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
            .animation(.snappy, value: recorder.state)
        }
        .onAppear {
            recorder.attach(modelContext: modelContext)
        }
        .onChange(of: recorder.lastFinishedTrail) { _, newTrail in
            if let newTrail {
                summaryTrail = newTrail
                recorder.lastFinishedTrail = nil
            }
        }
        .sheet(item: $summaryTrail) { trail in
            TrailDetailView(trail: trail, presentation: .summary)
        }
    }

    private var statsCard: some View {
        let trail = recorder.currentTrail
        return HStack(spacing: 0) {
            stat("Distance", formatDistance(trail?.distanceMeters ?? 0))
            divider
            stat("Time", formatDuration(recorder.elapsedSeconds))
            divider
            stat("Pace", formatPace(meters: trail?.distanceMeters ?? 0, seconds: recorder.elapsedSeconds))
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 28)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var pinButton: some View {
        Button {
            recorder.pinDestination()
        } label: {
            Label(
                recorder.destinationCoordinate == nil ? "Pin destination" : "Repin",
                systemImage: "mappin.and.ellipse"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private var endButton: some View {
        Button {
            recorder.end()
        } label: {
            Text("End")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
    }

    private var startButton: some View {
        Button {
            recorder.start()
        } label: {
            Text("Start a new trail")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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
