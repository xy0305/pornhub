import Foundation

/// Value-only pan state, shared by UIKit and executable regression tests.
struct PHAdjustmentPan {
    enum Axis { case horizontal, vertical }
    enum Side { case brightness, volume }
    private(set) var axis: Axis?
    private(set) var side: Side = .brightness
    private(set) var active = false
    private(set) var size = CGSize.zero
    private var last = CGPoint.zero
    private(set) var value: CGFloat = 0

    mutating func begin(origin: CGPoint, size: CGSize) {
        self = PHAdjustmentPan()
        active = size.width > 0 && size.height > 0
        self.size = size
        side = origin.x < size.width / 2 ? .brightness : .volume
    }

    /// Do not fail the recognizer in shouldBegin: UIKit calls that only once.
    /// Wait for 6pt displacement and a 15% dominant axis, then lock permanently.
    mutating func lock(translation: CGPoint, initial: CGFloat) -> Bool {
        guard active, axis == nil else { return false }
        let x = abs(translation.x), y = abs(translation.y)
        guard max(x, y) >= 6, max(x, y) >= min(x, y) * 1.15 else { return false }
        axis = x > y ? .horizontal : .vertical
        value = min(1, max(0, initial))
        last = translation // consume deadzone; direction lock itself never jumps
        return true
    }

    /// Incremental displacement is independent of event frequency/velocity.
    /// Clamp each step so reversing from a limit responds immediately.
    mutating func update(translation: CGPoint, size: CGSize) -> CGFloat? {
        guard active, self.size == size else { end(); return nil }
        guard axis == .vertical else { return nil }
        value = PHPlayerGesturePolicy.adjusted(initial: value, translation: translation.y - last.y, height: self.size.height)
        last = translation
        return value
    }

    mutating func end() { active = false; axis = nil; last = .zero }
}
