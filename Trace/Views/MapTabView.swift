import SwiftUI
import CoreLocation

struct MapTabView: View {
    @State private var location = LocationManager()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
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
            MapLibreMapView()
                .ignoresSafeArea(edges: .bottom)
        @unknown default:
            permissionRequest
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
