import Foundation

@main
struct PHParserRegression {
    static func main() {
        do {
            try PHFixtureCheck.run()
            let qualityRows: [[String: Any]] = [
                ["format": "hls", "quality": "360", "defaultQuality": true, "videoUrl": "https://media.example/360"],
                ["format": "hls", "quality": "1080p", "videoUrl": "https://media.example/1080"],
                ["format": "hls", "quality": "720", "videoUrl": "https://media.example/720"],
                ["format": "hls", "quality": "2160", "videoUrl": "javascript:invalid"],
                ["format": "hls", "videoUrl": "https://media.example/auto"]
            ]
            let qualities = PHParser.qualities(from: qualityRows)
            precondition(qualities.map(\.height) == [1080, 720, 360, 0])
            precondition(qualities.last?.label == "自动")
            precondition(PHParser.qualities(from: nil).isEmpty)
            precondition(PHQualityPolicy.ranked(Array(qualities.reversed())).first?.height == 1080)
            precondition(PHQualityPolicy.ranked(qualities + qualities).count == 4)
            var intent = PHQualitySelection()
            precondition(intent.update(qualities, videoID: "a") == 0)
            intent.choose(qualities[2])
            precondition(intent.update(qualities, videoID: "a") == 2)
            var refreshed = qualities
            refreshed[2].url = URL(string: "https://media.example/renewed360")!
            precondition(intent.update(refreshed, videoID: "a") == 2)
            precondition(intent.update([], videoID: "a") == nil)
            precondition(intent.update(refreshed, videoID: "a") == 2)
            precondition(intent.update(refreshed, videoID: "b") == 0)
            precondition(!intent.manual)
            var missing = PHQualitySelection()
            precondition(missing.update([], videoID: "c") == nil)
            precondition(missing.update([qualities.last!], videoID: "c") == 0)
            precondition(missing.update(qualities, videoID: "c") == 0)
            precondition(missing.selected?.height == 1080)
            print("Highest-quality ranking, missing metadata, invalid URL, signed URL refresh and manual intent passed")
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
            let subscriptionsURL = URL(string: "https://cn.pornhub.com/subscriptions")!
            let anonymous = try String(contentsOfFile: root + "/subscriptions-anonymous.html", encoding: .utf8)
            do {
                _ = try PHSubscriptionParser.parse(anonymous, url: subscriptionsURL)
                preconditionFailure("Anonymous subscription gate accepted")
            } catch PHSubscriptionError.signIn { }
            let synthetic = try String(contentsOfFile: root + "/subscriptions-synthetic.html", encoding: .utf8)
            let feed = try PHSubscriptionParser.parse(synthetic, url: subscriptionsURL)
            precondition(feed.videos.map(\.vkey) == ["subscription1"])
            precondition(feed.nextHref == "https://cn.pornhub.com/subscriptions?page=2")
            let page2 = try PHSubscriptionParser.parse(synthetic, url: URL(string: feed.nextHref!)!)
            precondition(page2.nextHref == nil)
            do {
                _ = try PHSubscriptionParser.parse("<script>var isLoggedInUser = 1;</script><li data-video-vkey=\"unrelated\"><img alt=\"Not feed\"></li>", url: subscriptionsURL)
                preconditionFailure("Unknown subscription schema accepted")
            } catch PHSubscriptionError.schema { }
            print("Anonymous subscription gate and synthetic feed scope/pagination passed; real account not tested")
        } catch {
            fputs("fixture check failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
