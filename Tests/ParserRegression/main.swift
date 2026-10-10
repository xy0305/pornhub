import Foundation

@main
struct PHParserRegression {
    static func main() {
        do {
            try PHFixtureCheck.run()
            let root = ProcessInfo.processInfo.environment["PH_FIXTURES"]!
            for (name, href, codes, sources) in [
                ("model", "/model/lovely-asuna/videos", ["", "mv", "tr", "lg"], 1),
                ("pornstar", "/pornstar/lana-rhoades/videos", ["", "mv", "tr", "lg"], 2),
                ("pornstar-upload", "/pornstar/lana-rhoades/videos/upload", ["", "mv", "tr", "lg"], 2),
                ("channel", "/channels/brazzers/videos", ["", "ra", "vi"], 0)
            ] {
                let html = try String(contentsOfFile: root + "/profile-" + name + ".html", encoding: .utf8)
                let options = PHProfileFilters.choices(in: html, href: href, sorts: true)
                let actual = options.map { URLComponents(string: $0.href)!.queryItems?.first(where: { $0.name == "o" })?.value ?? "" }
                precondition(actual == codes, "\(name) codes \(actual)")
                precondition(PHProfileFilters.choices(in: html, href: href, sorts: false).count == sources)
                for option in options {
                    let url = PHProfileFilters.requestURL(href: option.href, page: 2)
                    let q = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
                    precondition(q.filter { $0.name == "page" }.count == 1)
                    precondition(q.first { $0.name == "page" }?.value == "2")
                    precondition(url.path == URL(string: option.href)!.path)
                }
            }
            precondition(PHProfileFilters.choices(in: "<a href=\"/video?o=mv\">global</a>", href: "/users/none", sorts: true).isEmpty)
            precondition(PHProfileFilters.videoEntry(in: "<a href=\"/model/a/videos\">Videos</a>", href: "/model/a") != nil)
            precondition(PHProfileFilters.videoEntry(in: "<a href=\"/model/b/videos\">Videos</a>", href: "/model/a") == nil)
            print("Official author sorting fixtures, type filters and pagination passed")
        } catch {
            fputs("fixture check failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
