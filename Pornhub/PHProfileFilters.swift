import Foundation

struct PHProfileChoice: Identifiable, Hashable {
    var id: String { href }
    let title: String
    let href: String
}

struct PHProfilePage {
    var profile: PHProfile
    var sorts: [PHProfileChoice]
    var sources: [PHProfileChoice]
    var nextPage: Int?
    var requestURL: URL
}

enum PHProfileFilters {
    // Discover capabilities from this author's HTML, never borrow global /video filters.
    static func choices(in html: String, href: String, sorts: Bool) -> [PHProfileChoice] {
        let pattern = sorts ? #"<ul\b[^>]*(?:id="subFilterListVideos"|class="subFilterList"[^>]*data-filter="o")[^>]*>(.*?)</ul>"# : #"<ul\b[^>]*class="dropDownFilter"[^>]*>(.*?)</ul>"#
        guard let section = PHParser.first(html, pattern: pattern),
              let base = URL(string: PHParser.absolute(href)) else { return [] }
        let root = base.path.split(separator: "/").prefix(2).joined(separator: "/")
        var result: [PHProfileChoice] = []
        for (link, label) in PHParser.pairMatches(section, pattern: #"<a\b[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#) {
            guard var c = URLComponents(string: PHParser.absolute(link)),
                  c.host == "cn.pornhub.com" || c.host == "www.pornhub.com" || c.host == "pornhub.com",
                  c.path == "/" + root || c.path.hasPrefix("/" + root + "/") else { continue }
            c.scheme = "https"; c.host = "cn.pornhub.com"; c.fragment = nil
            c.queryItems = c.queryItems?.filter { $0.name != "page" }
            let code = c.queryItems?.first(where: { $0.name == "o" })?.value ?? ""
            let title: String
            if sorts {
                let labels = ["": "最新", "mr": "最新", "mv": "最多次观看", "tr": "最高分", "lg": "最长"]
                let channelLabels = ["": "最新", "vi": "最多次观看", "ra": "最高分"]
                guard let mapped = (base.path.hasPrefix("/channels/") ? channelLabels : labels)[code] else { continue }
                title = mapped
            } else {
                let raw = PHParser.clean(label)
                title = ["Uploaded": "上传的视频", "Tagged": "被标记的视频" ][raw] ?? raw
            }
            guard let url = c.url, !title.isEmpty else { continue }
            let choice = PHProfileChoice(title: title, href: url.absoluteString)
            if !result.contains(choice) { result.append(choice) }
        }
        return result
    }

    static func videoEntry(in html: String, href: String) -> String? {
        guard let base = URL(string: PHParser.absolute(href)),
              base.path.split(separator: "/").count == 2 else { return nil }
        let expected = base.path + "/videos"
        // Follow only an actual same-author link; do not manufacture an endpoint.
        for link in PHParser.matches(html, pattern: #"href="([^"]+)""#) {
            guard let c = URLComponents(string: PHParser.absolute(link)),
                  c.path == expected, c.query == nil,
                  ["cn.pornhub.com", "www.pornhub.com", "pornhub.com"].contains(c.host ?? "") else { continue }
            return requestURL(href: link, page: 1).absoluteString
        }
        return nil
    }

    static func requestURL(href: String, page: Int) -> URL {
        var c = URLComponents(string: PHParser.absolute(href))!
        c.fragment = nil
        var q = c.queryItems ?? []
        q.removeAll { $0.name == "page" }
        if page > 1 { q.append(URLQueryItem(name: "page", value: String(page))) }
        c.queryItems = q.isEmpty ? nil : q
        return c.url!
    }

    static func parse(html: String, href: String, page: Int, url: URL) -> PHProfilePage {
        var profile = PHParser.profile(in: html, href: href)
        // Omit a featured/shorties section before the uploaded/tagged listing.
        let listing = html.range(of: #"<div class="subFilters">"#).map { String(html[$0.lowerBound...]) } ?? html
        let parsed = PHParser.page(in: listing, current: page)
        profile.videos = parsed.videos
        return PHProfilePage(profile: profile, sorts: choices(in: html, href: href, sorts: true),
                             sources: choices(in: html, href: href, sorts: false),
                             nextPage: parsed.nextPage, requestURL: url)
    }
}
