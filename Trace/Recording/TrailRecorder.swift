import CoreLocation
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class TrailRecorder: NSObject {
    enum State {
        case idle
        case recording
    }

    private(set) var state: State = .idle
    private(set) var currentTrail: Trail?
    private(set) var elapsedSeconds: Int = 0
    private(set) var liveCoordinates: [CLLocationCoordinate2D] = []
    private(set) var destinationCoordinate: CLLocationCoordinate2D?
    private(set) var followedTrail: [CLLocationCoordinate2D] = []

    // Captured at end() so TrailTabView can present the summary sheet
    // after the recorder has already returned to .idle.
    var lastFinishedTrail: Trail?

    private let manager = CLLocationManager()
    private let stepCounter = StepCounter()
    private var modelContext: ModelContext?
    private var timer: Timer?
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func start() {
        guard state == .idle, let modelContext else { return }
        let trail = Trail(startedAt: .now)
        modelContext.insert(trail)
        currentTrail = trail
        state = .recording
        elapsedSeconds = 0
        lastLocation = nil
        liveCoordinates = []
        destinationCoordinate = nil
        followedTrail = []

        manager.startUpdatingLocation()

        stepCounter.start(from: trail.startedAt) { [weak self] steps in
            self?.currentTrail?.stepCount = steps
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let trail = self.currentTrail else { return }
                self.elapsedSeconds += 1
                trail.durationSeconds = self.elapsedSeconds
            }
        }
    }

    func end() {
        guard state == .recording, let trail = currentTrail else { return }
        manager.stopUpdatingLocation()
        stepCounter.stop()
        timer?.invalidate()
        timer = nil
        trail.endedAt = .now
        try? modelContext?.save()
        lastFinishedTrail = trail
        currentTrail = nil
        state = .idle
        elapsedSeconds = 0
        lastLocation = nil
        liveCoordinates = []
        destinationCoordinate = nil
        followedTrail = []
    }

    /// Starts a recording with another trail's path as a visual guide.
    /// The destination pin is set to the followed trail's end so the user
    /// has a clear target; the guide line itself is not persisted.
    func startFollowing(coordinates: [CLLocationCoordinate2D]) {
        guard state == .idle, !coordinates.isEmpty else { return }
        start()
        followedTrail = coordinates
        destinationCoordinate = coordinates.last
    }

    func pinDestination() {
        guard state == .recording,
              let trail = currentTrail,
              let location = lastLocation,
              let modelContext else { return }

        // Replace any prior destination so a trail has at most one.
        for existing in trail.waypoints where existing.isDestination {
            modelContext.delete(existing)
        }

        let pin = Waypoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            isDestination: true
        )
        pin.trail = trail
        modelContext.insert(pin)
        try? modelContext.save()

        destinationCoordinate = location.coordinate
    }
}

extension TrailRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let snapshots = locations
        Task { @MainActor in
            self.ingest(locations: snapshots)
        }
    }

    private func ingest(locations: [CLLocation]) {
        guard state == .recording, let trail = currentTrail, let modelContext else { return }
        for location in locations {
            // discard wildly inaccurate samples
            guard location.horizontalAccuracy > 0, location.horizontalAccuracy < 50 else { continue }

            // reject teleporting samples (>100 m/s vs last fix)
            if let last = lastLocation {
                let delta = location.distance(from: last)
                let dt = location.timestamp.timeIntervalSince(last.timestamp)
                if dt > 0, delta / dt > 100 { continue }
                trail.distanceMeters += delta
            }

            let sample = TrailSample(
                timestamp: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                altitude: location.altitude,
                speed: max(location.speed, 0)
            )
            sample.trail = trail
            modelContext.insert(sample)
            liveCoordinates.append(location.coordinate)
            lastLocation = location
        }
        try? modelContext.save()
    }
}
