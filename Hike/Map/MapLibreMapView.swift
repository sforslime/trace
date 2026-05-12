import SwiftUI
import MapLibre

struct MapLibreMapView: UIViewRepresentable {
    var styleURL: URL = MapStyle.default
    var showsUserLocation: Bool = true
    var initialCenter: CLLocationCoordinate2D?
    var initialZoom: Double = 13

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.showsUserLocation = showsUserLocation
        mapView.userTrackingMode = .follow
        mapView.compassView.isHidden = false
        if let center = initialCenter {
            mapView.setCenter(center, zoomLevel: initialZoom, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        if mapView.styleURL != styleURL {
            mapView.styleURL = styleURL
        }
        if mapView.showsUserLocation != showsUserLocation {
            mapView.showsUserLocation = showsUserLocation
        }
    }
}
