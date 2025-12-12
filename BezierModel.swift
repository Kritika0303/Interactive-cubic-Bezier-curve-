import Foundation
import SwiftUI
import Combine

final class BezierModel: ObservableObject {
    // Control points
    @Published var P0: CGPoint = .zero
    @Published var P1: CGPoint = .zero
    @Published var P2: CGPoint = .zero
    @Published var P3: CGPoint = .zero

    // velocities
    private var v1 = CGVector(dx: 0, dy: 0)
    private var v2 = CGVector(dx: 0, dy: 0)

    // targets (updated from motion manager)
    var targetP1: CGPoint = .zero
    var targetP2: CGPoint = .zero

    // physics constants (tune these)
    var k: CGFloat = 0.12       // spring constant
    var damping: CGFloat = 0.14 // damping

    // display link
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    // screen / layout size (set by view)
    var size: CGSize = .zero {
        didSet {
            layoutInitialPoints()
        }
    }

    func layoutInitialPoints() {
        // Setup endpoints and default control points relative to size
        let w = size.width
        let h = size.height

        guard w > 0 && h > 0 else { return }

        P0 = CGPoint(x: w * 0.1, y: h * 0.5)
        P3 = CGPoint(x: w * 0.9, y: h * 0.5)

        // initial dynamic points
        if P1 == .zero && P2 == .zero {
            P1 = CGPoint(x: w * 0.3, y: h * 0.25)
            P2 = CGPoint(x: w * 0.7, y: h * 0.75)
            targetP1 = P1
            targetP2 = P2
        }
    }

    // start CADisplayLink
    func start() {
        lastTimestamp = 0
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp }
        let dt = CGFloat(min(link.timestamp - lastTimestamp, 1.0 / 30.0)) // clamp dt
        lastTimestamp = link.timestamp

        // update physics for P1 and P2
        updatePoint(&P1, &v1, target: targetP1, dt: dt)
        updatePoint(&P2, &v2, target: targetP2, dt: dt)

        // publish changes
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private func updatePoint(_ p: inout CGPoint, _ v: inout CGVector, target: CGPoint, dt: CGFloat) {
        // acceleration = -k * (pos - target) - damping * v
        let ax = -k * (p.x - target.x) - damping * v.dx
        let ay = -k * (p.y - target.y) - damping * v.dy

        v.dx += ax * dt
        v.dy += ay * dt

        p.x += v.dx * dt * 60.0 * 0.016 // scaled to feel similar across rates
        p.y += v.dy * dt * 60.0 * 0.016
    }

    // MARK: - Bézier math (manual)
    func bezierPoint(t: CGFloat) -> CGPoint {
        let u = 1 - t
        let u3 = u * u * u
        let u2t = 3 * u * u * t
        let ut2 = 3 * u * t * t
        let t3 = t * t * t

        let x = u3 * P0.x + u2t * P1.x + ut2 * P2.x + t3 * P3.x
        let y = u3 * P0.y + u2t * P1.y + ut2 * P2.y + t3 * P3.y
        return CGPoint(x: x, y: y)
    }

    func bezierDerivative(t: CGFloat) -> CGVector {
        let u = 1 - t
        // B'(t) = 3(1-t)^2(P1 - P0) + 6(1-t)t(P2 - P1) + 3t^2(P3 - P2)
        let x = 3 * u * u * (P1.x - P0.x) + 6 * u * t * (P2.x - P1.x) + 3 * t * t * (P3.x - P2.x)
        let y = 3 * u * u * (P1.y - P0.y) + 6 * u * t * (P2.y - P1.y) + 3 * t * t * (P3.y - P2.y)
        return CGVector(dx: x, dy: y)
    }

    func normalized(_ v: CGVector) -> CGVector {
        let mag = sqrt(v.dx * v.dx + v.dy * v.dy)
        if mag == 0 { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: v.dx / mag, dy: v.dy / mag)
    }
}
