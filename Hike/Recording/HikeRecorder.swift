import CoreLocation
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class HikeRecorder: NSObject {
    enum State {
        case idle
        case recording
    }

    private(set) var state: State = .idle
    private(set) var currentHike: Hike?
    private(set) var elapsedSeconds: Int = 0
    private(set) var liveCoordinates: [CLLocationCoordinate2D] = []

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
        let hike = Hike(startedAt: .now)
        modelContext.insert(hike)
        currentHike = hike
        state = .recording
        elapsedSeconds = 0
        lastLocation = nil
        liveCoordinates = []

        manager.startUpdatingLocation()

        stepCounter.start(from: hike.startedAt) { [weak self] steps in
            self?.currentHike?.stepCount = steps
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let hike = self.currentHike else { return }
                self.elapsedSeconds += 1
                hike.durationSeconds = self.elapsedSeconds
            }
        }
    }

    func end() {
        guard state == .recording, let hike = currentHike else { return }
        manager.stopUpdatingLocation()
        stepCounter.stop()
        timer?.invalidate()
        timer = nil
        hike.endedAt = .now
        try? modelContext?.save()
        currentHike = nil
        state = .idle
        elapsedSeconds = 0
        lastLocation = nil
        liveCoordinates = []
    }
}

extension HikeRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let snapshots = locations
        Task { @MainActor in
            self.ingest(locations: snapshots)
        }
    }

    private func ingest(locations: [CLLocation]) {
        guard state == .recording, let hike = currentHike, let modelContext else { return }
        for location in locations {
            // discard wildly inaccurate samples
            guard location.horizontalAccuracy > 0, location.horizontalAccuracy < 50 else { continue }

            // reject teleporting samples (>100 m/s vs last fix)
            if let last = lastLocation {
                let delta = location.distance(from: last)
                let dt = location.timestamp.timeIntervalSince(last.timestamp)
                if dt > 0, delta / dt > 100 { continue }
                hike.distanceMeters += delta
            }

            let sample = HikeSample(
                timestamp: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                altitude: location.altitude,
                speed: max(location.speed, 0)
            )
            sample.hike = hike
            modelContext.insert(sample)
            liveCoordinates.append(location.coordinate)
            lastLocation = location
        }
        try? modelContext.save()
    }
}
