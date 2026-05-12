import SwiftData
import SwiftUI

struct HikeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HikeRecorder.self) private var recorder

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Hike")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            recorder.attach(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch recorder.state {
        case .idle:
            idle
        case .recording:
            recording
        }
    }

    private var idle: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Ready to hike")
                .font(.title2.weight(.semibold))
            Text("Records your trail, steps, distance, and pace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                recorder.start()
            } label: {
                Text("Start hike")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recording: some View {
        VStack(spacing: 0) {
            statsGrid
                .padding(.top, 32)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                recorder.end()
            } label: {
                Text("End hike")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private var statsGrid: some View {
        let hike = recorder.currentHike
        return Grid(horizontalSpacing: 24, verticalSpacing: 24) {
            GridRow {
                stat("Distance", formatDistance(hike?.distanceMeters ?? 0))
                stat("Time", formatDuration(recorder.elapsedSeconds))
            }
            GridRow {
                stat("Steps", "\(hike?.stepCount ?? 0)")
                stat("Pace", formatPace(meters: hike?.distanceMeters ?? 0, seconds: recorder.elapsedSeconds))
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
