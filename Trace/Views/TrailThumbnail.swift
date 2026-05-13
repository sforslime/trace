import CoreLocation
import SwiftUI

struct TrailThumbnail: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Canvas { context, size in
            guard coordinates.count >= 2 else { return }

            let minLat = coordinates.map(\.latitude).min()!
            let maxLat = coordinates.map(\.latitude).max()!
            let minLng = coordinates.map(\.longitude).min()!
            let maxLng = coordinates.map(\.longitude).max()!

            let latRange = max(maxLat - minLat, 0.0001)
            let lngRange = max(maxLng - minLng, 0.0001)

            let pad: Double = 6
            let drawWidth = size.width - 2 * pad
            let drawHeight = size.height - 2 * pad

            func project(_ coord: CLLocationCoordinate2D) -> CGPoint {
                let x = pad + ((coord.longitude - minLng) / lngRange) * drawWidth
                let y = pad + ((maxLat - coord.latitude) / latRange) * drawHeight
                return CGPoint(x: x, y: y)
            }

            var path = Path()
            path.move(to: project(coordinates[0]))
            for coord in coordinates.dropFirst() {
                path.addLine(to: project(coord))
            }

            context.stroke(
                path,
                with: .color(.blue),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
