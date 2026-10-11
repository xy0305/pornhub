import Foundation
import CoreGraphics

@main struct GestureRegression {
    static func main() {
        let size = CGSize(width: 844, height: 390)
        var pan = PHAdjustmentPan()
        pan.begin(origin: CGPoint(x: 80, y: 220), size: size)
        precondition(pan.side == .brightness)
        precondition(!pan.lock(translation: CGPoint(x: 2, y: -4), initial: 0.5))
        precondition(!pan.lock(translation: CGPoint(x: 12, y: -12), initial: 0.5))
        precondition(pan.lock(translation: CGPoint(x: 2, y: -20), initial: 0.5))
        precondition(pan.axis == .vertical && pan.value == 0.5)
        precondition(!pan.lock(translation: CGPoint(x: 100, y: 1), initial: 0))
        let first = pan.update(translation: CGPoint(x: 700, y: -51.2), size: size)!
        precondition(abs(first - 0.6) < 0.00001 && pan.side == .brightness)
        precondition(pan.update(translation: CGPoint(x: 700, y: -10000), size: size) == 1)
        let reverse = pan.update(translation: CGPoint(x: 700, y: -9968.8), size: size)!
        precondition(abs(reverse - 0.9) < 0.00001) // no saturated overscroll debt
        precondition(pan.update(translation: CGPoint(x: 0, y: 10000), size: size) == 0)
        pan.end()
        precondition(!pan.active && pan.axis == nil)
        precondition(pan.update(translation: .zero, size: size) == nil)
        pan.begin(origin: CGPoint(x: 422, y: 100), size: size)
        precondition(pan.side == .volume)
        precondition(pan.lock(translation: CGPoint(x: 40, y: 5), initial: 0.8))
        precondition(pan.axis == .horizontal)
        precondition(pan.update(translation: CGPoint(x: 0, y: -200), size: size) == nil)
        pan.end() // same path for cancelled and ended; no stale axis on next begin
        pan.begin(origin: CGPoint(x: 700, y: 100), size: size)
        precondition(pan.lock(translation: CGPoint(x: 0, y: -10), initial: 0.4))
        precondition(pan.update(translation: CGPoint(x: 0, y: -100), size: CGSize(width: 390, height: 844)) == nil)
        precondition(!pan.active)
        // One large displacement == many small displacements away from limits.
        var a = PHAdjustmentPan(), b = PHAdjustmentPan()
        for i in [0, 1] {
            if i == 0 { a.begin(origin: .zero, size: size); _ = a.lock(translation: CGPoint(x: 0, y: -10), initial: 0.3) }
            else { b.begin(origin: .zero, size: size); _ = b.lock(translation: CGPoint(x: 0, y: -10), initial: 0.3) }
        }
        let one = a.update(translation: CGPoint(x: 0, y: -100), size: size)!
        for y in stride(from: -20, through: -100, by: -10) { _ = b.update(translation: CGPoint(x: 0, y: y), size: size) }
        precondition(abs(one - b.value) < 0.00001)
        print("Production gesture state: threshold, axis/half lock, no lock jump, increment/frequency/clamp/reverse, end/cancel reset, rotation cancellation passed")
    }
}
