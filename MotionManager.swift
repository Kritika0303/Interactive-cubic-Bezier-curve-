import Foundation
import CoreMotion
import Combine

final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    @Published var pitch: Double = 0.0  // rotation around x-axis
    @Published var roll: Double = 0.0   // rotation around y-axis
    @Published var yaw: Double = 0.0    // rotation around z-axis

    init(updateInterval: TimeInterval = 1.0 / 60.0) {
        manager.deviceMotionUpdateInterval = updateInterval
        start()
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let m = motion else { return }

            // Using attitude (pitch, roll, yaw)
            // Convert to degrees if needed or keep radians. We'll use radians here.
            let attitude = m.attitude
            DispatchQueue.main.async {
                self?.pitch = attitude.pitch
                self?.roll = attitude.roll
                self?.yaw = attitude.yaw
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
