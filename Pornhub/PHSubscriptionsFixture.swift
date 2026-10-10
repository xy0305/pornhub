#if DEBUG
import Foundation

actor PHSubscriptionsFixture {
    static let shared = PHSubscriptionsFixture()
    private var account = "A"
    private var didFail = false
    func setAccount(_ value: String) { account = value }
    static func load(url: URL) async throws -> PHSubscriptionPage { try await shared.response(url: url) }
    private func response(url: URL) async throws -> PHSubscriptionPage {
        let owner = account
        if !didFail { didFail = true; throw URLError(.timedOut) }
        if owner == "anonymous" {
            return try PHSubscriptionParser.parse("<script>var isLoggedInUser = 0;</script>", url: url)
        }
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value ?? "1"
        try await Task.sleep(nanoseconds: page == "2" ? 2_000_000_000 : 100_000_000)
        let next = page == "1" ? "<a href=\"/subscriptions?page=2\">Next</a>" : ""
        let html = """
        <script>var isLoggedInUser = 1;</script>
        <div class="subscriptionsVideosWrapper mobile"><div class="sectionWrap populated">
        <ul class="videoList clearfix"><li data-video-vkey="\(owner)\(page)"><img alt="Subscription fixture \(owner) page \(page)"></li></ul>
        </div></div>\(next)
        <li data-video-vkey="outside"><img alt="Not a subscription"></li>
        """
        return try PHSubscriptionParser.parse(html, url: url)
    }
}
#endif
