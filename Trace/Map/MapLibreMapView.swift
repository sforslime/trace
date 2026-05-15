import SwiftUI
import MapLibre

struct SharedTrailRender: Identifiable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
    let destination: CLLocationCoordinate2D?
}

struct MapLibreMapView: UIViewRepresentable {
    var styleURL: URL = MapStyle.default
    var showsUserLocation: Bool = true
    var followsUser: Bool = true
    var zoom: Double? = nil
    var breadcrumb: [CLLocationCoordinate2D] = []
    var destination: CLLocationCoordinate2D? = nil
    var fitBounds: [CLLocationCoordinate2D]? = nil
    var interactive: Bool = true
    var sharedTrails: [SharedTrailRender] = []
    var followedTrail: [CLLocationCoordinate2D] = []
    var onRegionChange: ((MLNCoordinateBounds) -> Void)? = nil
    var onSharedTrailTap: ((UUID) -> Void)? = nil

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

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        // Defer to MLN's own double-tap-to-zoom so we don't fire on the first tap of a double.
        for existing in mapView.gestureRecognizers ?? [] {
            if let dt = existing as? UITapGestureRecognizer, dt.numberOfTapsRequired == 2 {
                tap.require(toFail: dt)
            }
        }
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.parent = self

        if mapView.styleURL != styleURL {
            mapView.styleURL = styleURL
        }

        // followsUser is applied once in makeUIView; we don't re-enforce it
        // here, so a user pan/zoom isn't snapped back on the next SwiftUI update.

        if let zoom, context.coordinator.lastAppliedZoom != zoom {
            mapView.setZoomLevel(zoom, animated: true)
            context.coordinator.lastAppliedZoom = zoom
        }

        if let fitBounds, context.coordinator.lastFitBoundsSignature != Self.signature(of: fitBounds) {
            context.coordinator.applyFit(coordinates: fitBounds, on: mapView)
        }

        context.coordinator.updateSharedTrails(trails: sharedTrails)
        context.coordinator.updateFollowedTrail(coordinates: followedTrail)
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
        private var sharedTrailsSource: MLNShapeSource?
        private var sharedDestinationsSource: MLNShapeSource?
        private var followedTrailSource: MLNShapeSource?
        private var destinationAnnotation: MLNPointAnnotation?
        private var styleLoaded = false
        private var lastSharedTrailsSignature: String?
        private var lastFollowedTrailSignature: String?

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            let sharedSource = MLNShapeSource(identifier: "shared-trails", shape: nil, options: nil)
            style.addSource(sharedSource)
            sharedTrailsSource = sharedSource

            let sharedLayer = MLNLineStyleLayer(identifier: "shared-trails-line", source: sharedSource)
            sharedLayer.lineColor = NSExpression(forConstantValue: UIColor.systemGray.withAlphaComponent(0.7))
            sharedLayer.lineWidth = NSExpression(forConstantValue: 3)
            sharedLayer.lineCap = NSExpression(forConstantValue: "round")
            sharedLayer.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(sharedLayer)

            let destSource = MLNShapeSource(identifier: "shared-destinations", shape: nil, options: nil)
            style.addSource(destSource)
            sharedDestinationsSource = destSource

            let destLayer = MLNCircleStyleLayer(identifier: "shared-destinations-circle", source: destSource)
            destLayer.circleRadius = NSExpression(forConstantValue: 6)
            destLayer.circleColor = NSExpression(forConstantValue: UIColor.systemGray.withAlphaComponent(0.9))
            destLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            destLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)
            style.addLayer(destLayer)

            let followedSource = MLNShapeSource(identifier: "followed-trail", shape: nil, options: nil)
            style.addSource(followedSource)
            followedTrailSource = followedSource

            let followedLayer = MLNLineStyleLayer(identifier: "followed-trail-line", source: followedSource)
            followedLayer.lineColor = NSExpression(forConstantValue: UIColor.systemTeal)
            followedLayer.lineWidth = NSExpression(forConstantValue: 4)
            followedLayer.lineOpacity = NSExpression(forConstantValue: 0.85)
            followedLayer.lineCap = NSExpression(forConstantValue: "round")
            followedLayer.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(followedLayer)

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
                updateSharedTrails(trails: parent.sharedTrails)
                updateFollowedTrail(coordinates: parent.followedTrail)
                updatePolyline(coordinates: parent.breadcrumb)
                updateDestination(parent.destination, on: mapView)
                if let bounds = parent.fitBounds {
                    applyFit(coordinates: bounds, on: mapView)
                }
            }

            if let parent {
                parent.onRegionChange?(mapView.visibleCoordinateBounds)
            }
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            parent?.onRegionChange?(mapView.visibleCoordinateBounds)
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended, let mapView = gr.view as? MLNMapView else { return }
            let point = gr.location(in: mapView)
            // Generous hit area for thin lines and small circles.
            let touchRect = CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)
            let layers: Set<String> = ["shared-destinations-circle", "shared-trails-line"]
            let features = mapView.visibleFeatures(in: touchRect, styleLayerIdentifiers: layers)
            for feature in features {
                if let idString = feature.attribute(forKey: "trail_id") as? String,
                   let uuid = UUID(uuidString: idString) {
                    parent?.onSharedTrailTap?(uuid)
                    return
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

        func updateFollowedTrail(coordinates: [CLLocationCoordinate2D]) {
            guard let followedTrailSource, styleLoaded else { return }
            let signature = MapLibreMapView.signature(of: coordinates)
            guard signature != lastFollowedTrailSignature else { return }
            lastFollowedTrailSignature = signature

            guard coordinates.count >= 2 else {
                followedTrailSource.shape = nil
                return
            }
            var coords = coordinates
            followedTrailSource.shape = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
        }

        func updateSharedTrails(trails: [SharedTrailRender]) {
            guard let sharedTrailsSource, let sharedDestinationsSource, styleLoaded else { return }

            let signature = trails.reduce(into: "") { acc, t in
                acc += "[\(t.id.uuidString):\(t.coordinates.count)"
                if let d = t.destination { acc += "/\(d.latitude),\(d.longitude)" }
                acc += "]"
            }
            guard signature != lastSharedTrailsSignature else { return }
            lastSharedTrailsSignature = signature

            let lineFeatures = trails.compactMap { t -> MLNPolylineFeature? in
                guard t.coordinates.count >= 2 else { return nil }
                var coords = t.coordinates
                let feature = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
                feature.attributes = ["trail_id": t.id.uuidString]
                return feature
            }
            sharedTrailsSource.shape = MLNShapeCollectionFeature(shapes: lineFeatures)

            let destFeatures = trails.compactMap { t -> MLNPointFeature? in
                guard let d = t.destination else { return nil }
                let pt = MLNPointFeature()
                pt.coordinate = d
                pt.attributes = ["trail_id": t.id.uuidString]
                return pt
            }
            sharedDestinationsSource.shape = MLNShapeCollectionFeature(shapes: destFeatures)
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
