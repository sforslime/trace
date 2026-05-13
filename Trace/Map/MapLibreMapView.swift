import SwiftUI
import MapLibre

struct MapLibreMapView: UIViewRepresentable {
    var styleURL: URL = MapStyle.default
    var showsUserLocation: Bool = true
    var followsUser: Bool = true
    var zoom: Double? = nil
    var breadcrumb: [CLLocationCoordinate2D] = []
    var destination: CLLocationCoordinate2D? = nil
    var fitBounds: [CLLocationCoordinate2D]? = nil
    var interactive: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.showsUserLocation = showsUserLocation
        mapView.userTrackingMode = followsUser ? .follow : .none
        mapView.compassView.isHidden = false
        mapView.delegate = context.coordinator
        mapView.allowsZooming = interactive
        mapView.allowsScrolling = interactive
        mapView.allowsRotating = interactive
        mapView.allowsTilting = interactive
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

        if let zoom, context.coordinator.lastAppliedZoom != zoom {
            mapView.setZoomLevel(zoom, animated: true)
            context.coordinator.lastAppliedZoom = zoom
        }

        if let fitBounds, context.coordinator.lastFitBoundsSignature != Self.signature(of: fitBounds) {
            context.coordinator.applyFit(coordinates: fitBounds, on: mapView)
        }

        context.coordinator.updatePolyline(coordinates: breadcrumb)
        context.coordinator.updateDestination(destination, on: mapView)
    }

    private static func signature(of coords: [CLLocationCoordinate2D]) -> String {
        guard let first = coords.first, let last = coords.last else { return "" }
        return "\(coords.count)-\(first.latitude),\(first.longitude)-\(last.latitude),\(last.longitude)"
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapView?
        var lastAppliedZoom: Double?
        var lastFitBoundsSignature: String?
        private var polylineSource: MLNShapeSource?
        private var destinationAnnotation: MLNPointAnnotation?
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
                updateDestination(parent.destination, on: mapView)
                if let bounds = parent.fitBounds {
                    applyFit(coordinates: bounds, on: mapView)
                }
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

        func updateDestination(_ coord: CLLocationCoordinate2D?, on mapView: MLNMapView) {
            if let existing = destinationAnnotation {
                mapView.removeAnnotation(existing)
                destinationAnnotation = nil
            }
            guard let coord else { return }
            let pin = MLNPointAnnotation()
            pin.coordinate = coord
            pin.title = "Destination"
            mapView.addAnnotation(pin)
            destinationAnnotation = pin
        }

        func applyFit(coordinates: [CLLocationCoordinate2D], on mapView: MLNMapView) {
            guard coordinates.count >= 2 else { return }
            var coords = coordinates
            let padding = UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40)
            mapView.setVisibleCoordinates(
                &coords,
                count: UInt(coords.count),
                edgePadding: padding,
                animated: false
            )
            lastFitBoundsSignature = MapLibreMapView.signature(of: coordinates)
        }
    }
}
