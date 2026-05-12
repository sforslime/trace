import SwiftUI

struct HikeTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "figure.hiking")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No hike in progress")
                    .font(.headline)
                Text("Recording UI, GPS tracking, and stats land here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Hike")
        }
    }
}

#Preview {
    HikeTabView()
}
