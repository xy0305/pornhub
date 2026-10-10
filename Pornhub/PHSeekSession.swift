import Foundation

/// Pure seek interaction state, independent of UIKit and the playback engine.
struct PHSeekSession {
    private(set) var preview: Double?
    private(set) var pending = false
    private(set) var generation = 0
    var blocksProgress: Bool { preview != nil || pending }

    static func bounded(_ value: Double, duration: Double) -> Double? {
        guard value.isFinite, duration.isFinite, duration > 0 else { return nil }
        return min(max(value, 0), duration)
    }

    mutating func begin(value: Double, duration: Double) -> Bool {
        guard let value = Self.bounded(value, duration: duration) else { return false }
        generation += 1
        pending = false
        preview = value
        return true
    }

    mutating func move(value: Double, duration: Double) {
        guard preview != nil, !pending,
              let value = Self.bounded(value, duration: duration) else { return }
        preview = value
    }

    mutating func commit() -> (target: Double, generation: Int)? {
        guard let preview, !pending else { return nil }
        pending = true
        return (preview, generation)
    }

    @discardableResult
    mutating func finish(generation: Int) -> Bool {
        guard pending, self.generation == generation else { return false }
        preview = nil
        pending = false
        return true
    }

    mutating func cancel() {
        generation += 1
        preview = nil
        pending = false
    }
}
