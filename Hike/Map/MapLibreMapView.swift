import SwiftUI
import MapLibre

struct MapLibreMapView: UIViewRepresentable {
    var styleURL: URL = MapStyle.default
    var showsUserLocation: Bool = true
    var followsUser: Bool = true
    var zoom: Double? = nil
    var breadcrumb: [CLLocationCoordinate2D] = []

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.showsUserLocation = showsUserLocation
        mapView.userTrackingMode = followsUser ? .follow : .none
        mapView.compassView.isHidden = false
        mapView.delegate = context.coordinator
        context.coordinator.parent = self
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.parent = self

        if mapView.styleURL != styleURL {
            mapView.styleURL = styleURL
        }

        let desiredMode: MLNUserTrackingMode = followsUser ? .follow : .none
        if mapView.userTrackingMode != desiredMode {
            mapView.userTrackingMode = desiredMode
        }

        // apply zoom only on transitions so we don't fight the user's pinch
        if let zoom, context.coordinator.lastAppliedZoom != zoom {
            mapView.setZoomLevel(zoom, animated: true)
            context.coordinator.lastAppliedZoom = zoom
        }

        context.coordinator.updatePolyline(coordinates: breadcrumb)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapView?
        var lastAppliedZoom: Double?
        private var polylineSource: MLNShapeSource?
        private var styleLoaded = false

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            let source = MLNShapeSource(identifier: "breadcrumb", shape: nil, options: nil)
            style.addSource(source)
            polylineSource = source

            let layer = MLNLineStyleLayer(identifier: "breadcrumb-line", source: source)
            layer.lineColor = NSExpression(forConstantValue: UIColor.systemBlue)
            layer.lineWidth = NSExpression(forConstantValue: 5)
            layer.lineCap = NSExpression(forConstantValue: "round")
            layer.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(layer)

            styleLoaded = true

            if let parent {
                updatePolyline(coordinates: parent.breadcrumb)
            }
        }

        func updatePolyline(coordinates: [CLLocationCoordinate2D]) {
            guard let polylineSource, styleLoaded else { return }
            guard coordinates.count >= 2 else {
                polylineSource.shape = nil
                return
            }
            var coords = coordinates
            polylineSource.shape = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
        }
    }
}
