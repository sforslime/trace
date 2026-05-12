import Foundation

// OpenFreeMap is a community-funded free vector tile server (no API key).
// Liberty has hill shading + terrain, which matters for a hiking app.
enum MapStyle {
    static let liberty = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    static let positron = URL(string: "https://tiles.openfreemap.org/styles/positron")!
    static let bright = URL(string: "https://tiles.openfreemap.org/styles/bright")!

    static let `default` = liberty
}
