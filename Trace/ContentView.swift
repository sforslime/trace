import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }

            TrailTabView()
                .tabItem { Label("Trail", systemImage: "figure.hiking") }

            LibraryTabView()
                .tabItem { Label("Library", systemImage: "books.vertical") }

            ProfileTabView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    ContentView()
}
