//
//  CursorShakeDetector.swift
//  Frost
//
//  Detects rapid cursor shaking (left-right movement) to toggle blur.
//

import Foundation
import Cocoa

class CursorShakeDetector {

    // MARK: - Configuration

    private let timeWindow: TimeInterval = 0.5       // Detection window in seconds
    private let minDirectionChanges: Int = 3        // Minimum back-and-forth count
    private let minVelocity: CGFloat = 300          // Minimum pixels per second
    private let minMovementDistance: CGFloat = 50   // Minimum total movement distance

    // MARK: - Properties

    private var positions: [(point: CGPoint, time: Date)] = []
    private var monitor: Any?
    private var isEnabled: Bool = false

    var onShakeDetected: (() -> Void)?

    // MARK: - Public Methods

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self, self.isEnabled else { return }
            self.trackMovement(NSEvent.mouseLocation)
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        positions.removeAll()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            positions.removeAll()
        }
    }

    // MARK: - Movement Tracking

    private func trackMovement(_ point: CGPoint) {
        let now = Date()
        positions.append((point, now))

        // Remove old positions outside time window
        positions = positions.filter { now.timeIntervalSince($0.time) < timeWindow }

        // Check for shake pattern
        if detectShakePattern() {
            positions.removeAll()
            onShakeDetected?()
        }
    }

    // MARK: - Shake Detection

    private func detectShakePattern() -> Bool {
        guard positions.count >= 4 else { return false }

        var directionChanges = 0
        var lastDirection: CGFloat = 0
        var totalDistance: CGFloat = 0

        for i in 1..<positions.count {
            let dx = positions[i].point.x - positions[i - 1].point.x
            let distance = abs(dx)
            totalDistance += distance

            // Determine horizontal direction
            let direction: CGFloat = dx > 5 ? 1.0 : (dx < -5 ? -1.0 : 0)

            // Count direction changes (ignore small movements)
            if direction != 0 && lastDirection != 0 && direction != lastDirection {
                directionChanges += 1
            }

            if direction != 0 {
                lastDirection = direction
            }
        }

        // Check if we have enough direction changes
        guard directionChanges >= minDirectionChanges else { return false }

        // Check minimum movement distance
        guard totalDistance >= minMovementDistance else { return false }

        // Calculate velocity
        guard let firstTime = positions.first?.time,
              let lastTime = positions.last?.time else { return false }

        let timeElapsed = lastTime.timeIntervalSince(firstTime)
        guard timeElapsed > 0 else { return false }

        let velocity = totalDistance / CGFloat(timeElapsed)

        return velocity >= minVelocity
    }
}
