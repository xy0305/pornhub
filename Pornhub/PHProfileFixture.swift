#if DEBUG
import Foundation

actor PHProfileFixture {
    private static var failed = false
    static func load(url: URL, page: Int) async throws -> PHProfilePage {
        let order = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "o" })?.value ?? "mr"
        // A delayed request proves a superseded response cannot overwrite selection.
        try await Task.sleep(nanoseconds: order == "mv" ? 1_500_000_000 : 100_000_000)
        if order == "lg", !failed {
            failed = true
            throw URLError(.timedOut)
        }
        let base = "/model/fixture/videos"
        let html = """
        <title>Fixture Author</title><div class="subFilters">
        <ul class="dropDownFilter"><li><a href="\(base)">Uploaded</a></li></ul>
        <ul id="subFilterListVideos">
        <li><a href="\(base)">Most Recent</a></li>
        <li><a href="\(base)?o=mv">Most Viewed</a></li>
        <li><a href="\(base)?o=tr">Top Rated</a></li>
        <li><a href="\(base)?o=lg">Longest</a></li></ul>
        <li data-video-vkey="\(order)\(page)"><img alt="Fixture \(order) page \(page)"></li>
        \(page == 1 ? "<a href=\"\(base)?o=\(order)&amp;page=2\">2</a>" : "")
        </div>
        """
        return PHProfileFilters.parse(html: html, href: url.absoluteString, page: page, url: url)
    }
}
#endif
