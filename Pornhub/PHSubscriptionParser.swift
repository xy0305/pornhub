import Foundation

struct PHSubscriptionPage {
    var videos: [PHVideo]
    var nextHref: String?
}

enum PHSubscriptionParser {
    static func parse(_ html: String, url: URL) throws -> PHSubscriptionPage {
        // This is a content gate, not an assumption based on local account/cookies.
        if PHParser.first(html, pattern: #"isLoggedInUser\s*=\s*([01])"#) == "0" || url.path.hasPrefix("/login") {
            throw PHSubscriptionError.signIn
        }
        guard PHParser.first(html, pattern: #"isLoggedInUser\s*=\s*([01])"#) == "1",
              let start = html.range(of: #"<div\b[^>]*class="[^"]*\bsubscriptionsVideosWrapper\b[^"]*"[^>]*>"#, options: .regularExpression) else {
            throw PHSubscriptionError.schema
        }
        // Balance the actual feed wrapper; never parse recommendations/footer cards.
        let tail = String(html[start.lowerBound...])
        let regex = try NSRegularExpression(pattern: #"</?div\b[^>]*>"#)
        var depth = 0
        var section: String?
        for match in regex.matches(in: tail, range: NSRange(tail.startIndex..., in: tail)) {
            guard let range = Range(match.range, in: tail) else { continue }
            depth += tail[range].hasPrefix("</") ? -1 : 1
            if depth == 0 { section = String(tail[..<range.upperBound]); break }
        }
        guard let section, section.contains("videoList") else { throw PHSubscriptionError.schema }
        let videos = PHParser.videos(in: section)
        let current = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value.flatMap(Int.init) ?? 1
        // Only follow a next-page link actually emitted by this endpoint.
        var next: String?
        for raw in PHParser.matches(html, pattern: #"href="([^"]+)""#) {
            guard var c = URLComponents(string: PHParser.absolute(raw)),
                  ["cn.pornhub.com", "www.pornhub.com", "pornhub.com"].contains(c.host ?? ""),
                  c.path == "/subscriptions",
                  c.queryItems?.first(where: { $0.name == "page" })?.value == String(current + 1) else { continue }
            c.scheme = "https"; c.host = "cn.pornhub.com"; c.fragment = nil
            next = c.url?.absoluteString; break
        }
        return PHSubscriptionPage(videos: videos, nextHref: next)
    }
}

enum PHSubscriptionError: LocalizedError {
    case signIn, schema
    var errorDescription: String? {
        switch self {
        case .signIn: return "请登录官网账号后查看订阅更新；当前会话未登录或已过期。"
        case .schema: return "订阅页面结构无法确认，未把推荐或本地缓存作为服务器订阅。请重试。"
        }
    }
}
