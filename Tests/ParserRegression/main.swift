import Foundation

do {
    try PHFixtureCheck.run()
} catch {
    fputs("fixture check failed: \(error)\n", stderr)
    exit(1)
}
