import CoreMotion
import Foundation

final class StepCounter {
    private let pedometer = CMPedometer()
    private var isRunning = false

    func start(from startDate: Date, onUpdate: @escaping @MainActor (Int) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        guard !isRunning else { return }
        isRunning = true
        pedometer.startUpdates(from: startDate) { data, _ in
            guard let data else { return }
            let steps = data.numberOfSteps.intValue
            Task { @MainActor in
                onUpdate(steps)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        pedometer.stopUpdates()
    }
}
