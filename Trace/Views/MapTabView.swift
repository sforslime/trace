import CoreLocation
import MapLibre
import SwiftUI

struct MapTabView: View {
    @State private var location = LocationManager()
    @State private var sharedTrails = SharedTrailsRepository()
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedTrail: PublishedTrail?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedTrail) { trail in
            PublishedTrailDetailView(trail: trail)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch location.authorizationStatus {
        case .notDetermined:
            permissionRequest
        case .denied, .restricted:
            permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            MapLibreMapView(
                sharedTrails: sharedTrails.trails.map(renderable),
                onRegionChange: scheduleFetch,
                onSharedTrailTap: handleSharedTrailTap
            )
            .ignoresSafeArea(edges: .bottom)
        @unknown default:
            permissionRequest
        }
    }

    private func renderable(_ trail: PublishedTrail) -> SharedTrailRender {
        SharedTrailRender(
            id: trail.id,
            coordinates: trail.coordinates,
            destination: trail.destination
        )
    }

    private func handleSharedTrailTap(_ id: UUID) {
        selectedTrail = sharedTrails.trails.first { $0.id == id }
    }

    private func scheduleFetch(bounds: MLNCoordinateBounds) {
        let minLng = bounds.sw.longitude
        let minLat = bounds.sw.latitude
        let maxLng = bounds.ne.longitude
        let maxLat = bounds.ne.latitude

        let lngSpan = maxLng - minLng
        let latSpan = maxLat - minLat
        guard lngSpan > 0, lngSpan < 90, latSpan > 0, latSpan < 90 else { return }

        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await sharedTrails.refresh(
                minLng: minLng,
                minLat: minLat,
                maxLng: maxLng,
                maxLat: maxLat
            )
        }
    }

    private var permissionRequest: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Show your position on the map")
                .font(.headline)
            Text("Trace uses your location to draw your trail and center the map on where you are.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Allow location") {
                location.requestWhenInUsePermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Location is off")
                .font(.headline)
            Text("Enable location for Trace in Settings to see the map.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                location.openSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MapTabView()
}
