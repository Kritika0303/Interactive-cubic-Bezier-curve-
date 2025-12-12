import SwiftUI

struct ContentView: View {
    @StateObject private var model = BezierModel()
    @StateObject private var motion = MotionManager()

    // Mapping sensitivity factors (tweak these)
    private let xSensitivity: CGFloat = 0.45
    private let ySensitivity: CGFloat = 0.45

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // update model size once
                if model.size != size {
                    model.size = size
                    model.layoutInitialPoints()
                }

                // Draw curve path sampled at small t increments
                var path = Path()
                let step: CGFloat = 0.01
                var first = true
                for tRaw in stride(from: 0.0 as CGFloat, through: 1.0 as CGFloat, by: step) {
                    let p = model.bezierPoint(t: tRaw)
                    if first {
                        path.move(to: p)
                        first = false
                    } else {
                        path.addLine(to: p)
                    }
                }
                context.stroke(path, with: .color(Color.green), lineWidth: 3)

                // Draw tangents at several points
                for tRaw in stride(from: 0.0 as CGFloat, through: 1.0 as CGFloat, by: 0.1) {
                    let p = model.bezierPoint(t: tRaw)
                    let d = model.bezierDerivative(t: tRaw)
                    let n = model.normalized(d)
                    let tangentLength: CGFloat = 30.0
                    var tangentPath = Path()
                    tangentPath.move(to: p)
                    tangentPath.addLine(to: CGPoint(x: p.x + n.dx * tangentLength, y: p.y + n.dy * tangentLength))
                    context.stroke(tangentPath, with: .color(Color.yellow), lineWidth: 2)
                }

                // Draw control points
                for (p, color) in [(model.P0, Color.white), (model.P1, Color.blue), (model.P2, Color.blue), (model.P3, Color.white)] {
                    let circle = Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
                    context.fill(circle, with: .color(color))
                }
            }
            .background(Color.black)
            .gesture(DragGesture(minimumDistance: 0).onChanged({ value in
                // Also allow dragging on-screen to move targets manually if desired
                let loc = value.location
                // map drag to targets (scale)
                model.targetP1 = CGPoint(x: loc.x * 0.6, y: loc.y * 0.6)
                model.targetP2 = CGPoint(x: model.size.width - loc.x * 0.6, y: model.size.height - loc.y * 0.6)
            }))
            .onAppear {
                // Map initial motion values to targets
                model.layoutInitialPoints()
                model.start()
                // motion start is automatic
                // subscribe to motion updates and map to targets
                setupMotionMapping()
            }
            .onDisappear {
                model.stop()
                motion.stop()
            }
        }
        .ignoresSafeArea()
    }

    private func setupMotionMapping() {
        // map motion pitch/roll/yaw -> targets periodically
        // We'll use a short Timer publisher to read current motion values
        // and update the model targets. This is separate from display link.
        let _ = Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                guard model.size.width > 0 else { return }

                // motion.pitch/roll/yaw are in radians roughly [-pi, pi] or narrower
                // We'll map pitch -> y, roll -> x (you can invert or adjust sensitivities)
                let pitch = CGFloat(motion.pitch) // up/down
                let roll = CGFloat(motion.roll)   // left/right
                let yaw = CGFloat(motion.yaw)     // additional factor if desired

                // center positions
                let centerX = model.size.width * 0.5
                let centerY = model.size.height * 0.5

                // Map roll/pitch to offsets
                let offsetX = roll * model.size.width * xSensitivity
                let offsetY = pitch * model.size.height * ySensitivity

                // targetP1 near left, targetP2 near right
                model.targetP1 = CGPoint(x: centerX * 0.6 + offsetX, y: centerY * 0.6 + offsetY)
                model.targetP2 = CGPoint(x: centerX * 1.4 - offsetX, y: centerY * 1.4 - offsetY)
            }
    }
}
