import Foundation

@main
struct SeekRegression {
    static func main() {
        var s = PHSeekSession()
        precondition(!s.blocksProgress)
        for duration in [0.0, -1.0, Double.nan, Double.infinity] {
            precondition(!s.begin(value: 10, duration: duration))
        }
        precondition(!s.begin(value: .nan, duration: 100))
        precondition(!s.begin(value: .infinity, duration: 100))
        precondition(s.begin(value: -20, duration: 100))
        precondition(s.preview == 0 && s.blocksProgress)
        s.move(value: 150, duration: 100)
        precondition(s.preview == 100)
        s.move(value: .nan, duration: 100)
        precondition(s.preview == 100)
        let first = s.commit()!
        precondition(first.target == 100 && s.pending && s.blocksProgress)
        precondition(s.commit() == nil) // duplicate touch-end cannot seek twice
        s.move(value: 20, duration: 100)
        precondition(s.preview == 100) // pending seek holds its target
        precondition(!s.finish(generation: first.generation - 1))
        precondition(s.blocksProgress)
        precondition(s.finish(generation: first.generation))
        precondition(!s.blocksProgress && s.preview == nil)
        precondition(!s.finish(generation: first.generation))
        precondition(s.begin(value: 30, duration: 100))
        let old = s.commit()!
        s.cancel() // cancel, reset, quality/fullscreen switch invalidate callbacks
        precondition(!s.finish(generation: old.generation) && !s.blocksProgress)
        precondition(s.begin(value: 40, duration: 200))
        let latest = s.commit()!
        precondition(!s.finish(generation: old.generation) && s.blocksProgress)
        precondition(s.finish(generation: latest.generation))
        s.move(value: 99, duration: 100)
        precondition(s.preview == nil && s.commit() == nil)
        precondition(s.begin(value: 75, duration: 100))
        s.cancel() // touchCancel must not commit
        precondition(s.commit() == nil && !s.blocksProgress)
        print("PASS: seek bounds, unavailable metadata, preview hold, commit-once, cancellation, generation isolation, completion/failure recovery")
    }
}
