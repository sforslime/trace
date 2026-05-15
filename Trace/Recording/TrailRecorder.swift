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
    private(set) var currentHeading: CLHeading?

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
        manager.headingFilter = 5
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
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }

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
        manager.stopUpdatingHeading()
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
        currentHeading = nil
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

    /// Live navigation hint while following another user's trail.
    /// Nil unless recording, following, and we have a fresh location fix.
    var guidance: FollowGuidance? {
        guard state == .recording,
              !followedTrail.isEmpty,
              let user = lastLocation else { return nil }

        let targetIndex = nextTargetIndex(from: user.coordinate)
        let target = followedTrail[targetIndex]
        let distance = user.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        let bearingToTarget = bearing(from: user.coordinate, to: target)

        let headingDeg = currentHeading?.trueHeading ?? currentHeading?.magneticHeading
        let relative: Double?
        if let headingDeg, headingDeg >= 0 {
            // Normalize to -180...180 (right positive, left negative).
            var diff = (bearingToTarget - headingDeg)
                .truncatingRemainder(dividingBy: 360)
            if diff > 180 { diff -= 360 }
            if diff < -180 { diff += 360 }
            relative = diff
        } else {
            relative = nil
        }

        let arrived = targetIndex == followedTrail.count - 1 && distance < 8
        return FollowGuidance(
            direction: .arrived, // resolved inside the init
            distanceMeters: distance,
            relativeBearingDegrees: relative,
            absoluteBearingDegrees: bearingToTarget,
            hasHeading: relative != nil,
            arrived: arrived
        )
    }

    private func nextTargetIndex(from user: CLLocationCoordinate2D) -> Int {
        // Find the closest point on the followed trail, then walk forward until
        // we're at least ~20 m beyond the user so the hint pulls you toward the
        // next bit of trail, not to a point you're already standing on.
        guard !followedTrail.isEmpty else { return 0 }
        let nearestIndex = followedTrail.indices.min(by: { a, b in
            distanceSquared(user, followedTrail[a]) < distanceSquared(user, followedTrail[b])
        }) ?? followedTrail.count - 1

        let userLoc = CLLocation(latitude: user.latitude, longitude: user.longitude)
        var i = nearestIndex
        while i < followedTrail.count - 1 {
            let p = followedTrail[i]
            let d = userLoc.distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude))
            if d >= 20 { return i }
            i += 1
        }
        return followedTrail.count - 1
    }

    private func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    private func distanceSquared(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = a.latitude - b.latitude
        let dLon = a.longitude - b.longitude
        return dLat * dLat + dLon * dLon
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

struct FollowGuidance {
    enum Direction: String {
        case arrived
        case straightAhead
        case bearRight
        case bearLeft
        case turnRight
        case turnLeft
        case turnAround
        /// Heading isn't available (e.g. simulator) — fall back to a cardinal direction.
        case headTo
    }

    let direction: Direction
    let instruction: String
    let distanceMeters: Double
    let relativeBearingDegrees: Double?
    let absoluteBearingDegrees: Double

    init(
        direction: Direction,
        distanceMeters: Double,
        relativeBearingDegrees: Double?,
        absoluteBearingDegrees: Double,
        hasHeading: Bool,
        arrived: Bool
    ) {
        let resolvedDirection: Direction
        let instruction: String
        if arrived {
            resolvedDirection = .arrived
            instruction = "You're at the end"
        } else if hasHeading, let r = relativeBearingDegrees {
            let mag = abs(r)
            if mag < 15 {
                resolvedDirection = .straightAhead
                instruction = "Straight ahead"
            } else if mag < 60 {
                resolvedDirection = r > 0 ? .bearRight : .bearLeft
                instruction = r > 0 ? "Bear right" : "Bear left"
            } else if mag < 150 {
                resolvedDirection = r > 0 ? .turnRight : .turnLeft
                instruction = r > 0 ? "Turn right" : "Turn left"
            } else {
                resolvedDirection = .turnAround
                instruction = "Turn around"
            }
        } else {
            resolvedDirection = .headTo
            instruction = "Head \(Self.cardinal(for: absoluteBearingDegrees))"
        }

        self.direction = resolvedDirection
        self.instruction = instruction
        self.distanceMeters = distanceMeters
        self.relativeBearingDegrees = relativeBearingDegrees
        self.absoluteBearingDegrees = absoluteBearingDegrees
    }

    private static func cardinal(for bearing: Double) -> String {
        let labels = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
        let normalized = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let idx = Int(((normalized + 22.5) / 45).rounded(.down)) % 8
        return labels[idx]
    }
}

extension TrailRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let snapshots = locations
        Task { @MainActor in
            self.ingest(locations: snapshots)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let snapshot = newHeading
        Task { @MainActor in
            guard self.state == .recording, snapshot.headingAccuracy >= 0 else { return }
            self.currentHeading = snapshot
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
