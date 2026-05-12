import SwiftUI

struct MapTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Shared map")
                    .font(.headline)
                Text("MapLibre + published trails go here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Map")
        }
    }
}

#Preview {
    MapTabView()
}
