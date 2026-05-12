import SwiftData
import SwiftUI

struct HikeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HikeRecorder.self) private var recorder

    var body: some View {
        ZStack(alignment: .top) {
            MapLibreMapView(
                followsUser: true,
                zoom: recorder.state == .recording ? 17 : 14,
                breadcrumb: recorder.liveCoordinates
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
                actionButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .animation(.snappy, value: recorder.state)
        }
        .onAppear {
            recorder.attach(modelContext: modelContext)
        }
    }

    private var statsCard: some View {
        let hike = recorder.currentHike
        return HStack(spacing: 0) {
            stat("Distance", formatDistance(hike?.distanceMeters ?? 0))
            divider
            stat("Time", formatDuration(recorder.elapsedSeconds))
            divider
            stat("Pace", formatPace(meters: hike?.distanceMeters ?? 0, seconds: recorder.elapsedSeconds))
            divider
            stat("Steps", "\(hike?.stepCount ?? 0)")
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

    @ViewBuilder
    private var actionButton: some View {
        if recorder.state == .recording {
            Button {
                recorder.end()
            } label: {
                Text("End hike")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        } else {
            Button {
                recorder.start()
            } label: {
                Text("Start hike")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
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
