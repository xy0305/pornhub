import Foundation

@main
struct PHParserRegression {
    static func main() {
        do {
            try PHFixtureCheck.run()
        } catch {
            fputs("fixture check failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
