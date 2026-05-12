import SwiftUI

struct LibraryTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Your hikes")
                    .font(.headline)
                Text("Saved hikes and downloaded map regions will live here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryTabView()
}
