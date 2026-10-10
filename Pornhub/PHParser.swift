import Foundation

enum PHParser {
    static let origin = "https://cn.pornhub.com"

    static func absolute(_ href: String) -> String {
        let value = decode(href).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return value }
        if value.hasPrefix("//") { return "https:" + value }
        if value.hasPrefix("/") { return origin + value }
        return origin + "/" + value
    }

    static func videos(in html: String) -> [PHVideo] {
        var items: [PHVideo] = []
        var seen = Set<String>()
        for block in slices(html, open: "<li", close: "</li>", requiring: "data-video-vkey=") {
            guard let video = video(fromListItem: block), seen.insert(video.vkey).inserted else { continue }
            items.append(video)
        }
        if items.isEmpty {
            items = playlistChunkVideos(in: html)
        }
        return items
    }

    static func playlistChunkVideos(in html: String) -> [PHVideo] {
        var items: [PHVideo] = []
        var seen = Set<String>()
        for block in slices(html, open: "<li", close: "</li>", requiring: "viewkey=") {
            guard let href = first(block, pattern: #"href="([^"]*viewkey=[^"]+)""#),
                  let vkey = first(href, pattern: #"viewkey=([A-Za-z0-9]+)"#),
                  seen.insert(vkey).inserted else { continue }
            let title = clean(first(block, pattern: #"alt="([^"]+)""#)
                ?? first(block, pattern: #"class="playlistRedesign__video__title"[^>]*>([^<]+)"#)
                ?? "片单视频")
            let thumb = decode(first(block, pattern: #"src="([^"]+)""#) ?? "")
            let duration = clean(first(block, pattern: #"class="[^"]*duration[^"]*"[^>]*>([^<]+)"#) ?? "")
            items.append(PHVideo(
                vkey: vkey,
                videoID: vkey,
                title: title.isEmpty ? "片单视频" : title,
                thumb: thumb,
                preview: "",
                duration: duration,
                views: "",
                author: "",
                authorURL: "",
                verified: block.contains("verified")
            ))
        }
        return items
    }

    static func video(fromListItem block: String) -> PHVideo? {
        guard let vkey = first(block, pattern: #"data-video-vkey="([^"]+)""#) else { return nil }
        let title = clean(first(block, pattern: #"class="thumbnailTitle"[^>]*>(.*?)</a>"#)
            ?? first(block, pattern: #"alt="([^"]+)""#)
            ?? "")
        guard !title.isEmpty else { return nil }
        let thumb = decode(first(block, pattern: #"<img[^>]+src="([^"]+)""#) ?? "")
        let preview = decode(first(block, pattern: #"data-webm="([^"]+)""#) ?? "")
        let duration = clean(first(block, pattern: #"class="[^"]*\btime\b[^"]*"[^>]*>([^<]+)"#) ?? "")
        let views = clean(first(block, pattern: #"class="videoViews"[^>]*>(.*?)</div>"#) ?? "")
        let authorURL = decode(first(block, pattern: #"<a class="uploaderLink" href="([^"]+)""#) ?? "")
        let author = clean(first(block, pattern: #"<a class="uploaderLink"[^>]*>(.*?)</a>"#) ?? "")
        let id = first(block, pattern: #"data-video-id="(\d+)""#) ?? vkey
        return PHVideo(
            vkey: vkey,
            videoID: id,
            title: title,
            thumb: thumb,
            preview: preview,
            duration: duration,
            views: views,
            author: author,
            authorURL: authorURL,
            verified: block.contains("badge-verified") || block.contains("hasBadge")
        )
    }

    static func page(in html: String, current: Int) -> PHPage {
        let items = videos(in: html)
        let pages = Set(matches(html, pattern: #"(?:[?&]|&amp;)page=(\d+)"#).compactMap(Int.init))
        let next = pages.contains(current + 1) ? current + 1 : (items.isEmpty ? nil : nil)
        return PHPage(videos: items, nextPage: next)
    }

    static func chips(in html: String) -> [PHChip] {
        guard let start = html.range(of: "trendingNowWrapper") else { return [] }
        let chunk = String(html[start.lowerBound...].prefix(12_000))
        var items: [PHChip] = []
        var seen = Set<String>()
        let pattern = #"<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>"#
        for pair in pairMatches(chunk, pattern: pattern) {
            let title = clean(pair.1)
            let href = decode(pair.0)
            guard !title.isEmpty, seen.insert(title).inserted else { continue }
            let icon = href.contains("/shorties") ? "play.fill" : nil
            items.append(PHChip(title: title, href: href, systemImage: icon))
            if items.count >= 16 { break }
        }
        return items
    }

    static func detail(in html: String, fallback: PHVideo) -> PHVideoDetail {
        let blob = flashvarsJSON(in: html)
        let object = blob.flatMap { jsonObject($0) } ?? [:]
        let title = string(object["video_title"]) ?? fallback.title
        let duration = int(object["video_duration"]) ?? 0
        let related = string(object["related_url"]) ?? ""
        let qualities = qualities(from: object["mediaDefinitions"])
        let tags = categoryPills(in: html)
        let views = clean(first(html, pattern: #"([0-9][0-9.,]*[KMB]?)\s*次观看"#) ?? fallback.views)
        let rating = clean(first(html, pattern: #"class="percent"[^>]*>([^<]+)"#)
            ?? first(html, pattern: #"class="ratingPercent"[^>]*>([^<]+)"#)
            ?? "")
        var video = fallback
        video.title = title.isEmpty ? fallback.title : title
        if video.videoID == video.vkey, let id = string(object["video_id"]) ?? first(html, pattern: #"data-video-id="(\d+)""#) {
            video.videoID = id
        }
        return PHVideoDetail(
            video: video,
            qualities: qualities,
            tags: tags,
            viewsText: views,
            ratingText: rating,
            durationSeconds: duration,
            relatedURL: related
        )
    }

    static func qualities(from value: Any?) -> [PHQuality] {
        guard let rows = value as? [[String: Any]] else { return [] }
        var items: [PHQuality] = []
        var seen = Set<String>()
        for row in rows {
            guard string(row["format"]) == "hls", let raw = string(row["videoUrl"]), let url = URL(string: raw) else { continue }
            let label = string(row["quality"]).flatMap { $0.isEmpty ? nil : $0 } ?? "\(int(row["height"]) ?? 0)"
            guard !label.isEmpty, label != "0", seen.insert(label).inserted else { continue }
            items.append(PHQuality(
                label: label + "p",
                height: int(row["height"]) ?? Int(label) ?? 0,
                url: url,
                isDefault: bool(row["defaultQuality"])
            ))
        }
        return items.sorted { $0.height > $1.height }
    }

    static func categoryPills(in html: String) -> [PHChip] {
        guard let range = html.range(of: "videoCtaPill") else { return [] }
        let chunk = String(html[range.lowerBound...].prefix(20_000))
        var items: [PHChip] = []
        var seen = Set<String>()
        let pattern = #"<a[^>]+href="([^"]+)"[^>]*class="[^"]*item"[^>]*>\s*<span>([^<]+)</span>"#
        for pair in pairMatches(chunk, pattern: pattern) {
            let title = clean(pair.1)
            guard !title.isEmpty, seen.insert(title).inserted else { continue }
            items.append(PHChip(title: title, href: decode(pair.0), systemImage: nil))
        }
        if items.isEmpty {
            let fallback = #"<a href="(/video\?c=\d+)"[^>]*>\s*<span>([^<]+)</span>"#
            for pair in pairMatches(chunk, pattern: fallback) {
                let title = clean(pair.1)
                guard !title.isEmpty, seen.insert(title).inserted else { continue }
                items.append(PHChip(title: title, href: decode(pair.0), systemImage: nil))
            }
        }
        return items
    }

    static func related(from data: Data) -> [PHVideo] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var items: [PHVideo] = []
        var seen = Set<String>()
        for key in ["related", "more", "mostViewed", "topRated"] {
            guard let rows = object[key] as? [Any] else { continue }
            for row in rows {
                guard let values = row as? [Any], values.count >= 9, let video = relatedVideo(values), seen.insert(video.vkey).inserted else { continue }
                items.append(video)
            }
        }
        return items
    }

    static func relatedVideo(_ values: [Any]) -> PHVideo? {
        let thumb = string(values[0]) ?? ""
        let title = clean(string(values[1]) ?? "")
        let duration = string(values[2]) ?? ""
        let href = string(values[4]) ?? ""
        let views = values.count > 5 ? formatCount(values[5]) : ""
        let preview = values.count > 6 ? (string(values[6]) ?? "") : ""
        let author = values.count > 7 ? (string(values[7]) ?? "") : ""
        let authorURL = values.count > 8 ? path(string(values[8]) ?? "") : ""
        guard let vkey = first(href, pattern: #"viewkey=([A-Za-z0-9]+)"#), !title.isEmpty else { return nil }
        let flags = values.count > 10 ? values[10] as? [String: Any] : nil
        let verified = bool(flags?["hasCheckmark"])
        let betterThumb = string(flags?["highResThumb"]) ?? thumb
        return PHVideo(
            vkey: vkey,
            videoID: vkey,
            title: title,
            thumb: betterThumb,
            preview: preview,
            duration: duration,
            views: views,
            author: author,
            authorURL: authorURL,
            verified: verified
        )
    }

    static func categories(in html: String) -> [PHCategory] {
        var items: [PHCategory] = []
        for block in slices(html, open: #"<li class="catPic""#, close: "</li>", requiring: "data-category=") {
            let id = first(block, pattern: #"data-category="(\d+)""#) ?? ""
            let title = clean(first(block, pattern: #"<strong>([^<]+)</strong>"#) ?? "")
            let count = clean(first(block, pattern: #"<var>([^<]+)</var>"#) ?? "")
            let thumb = decode(first(block, pattern: #"src="([^"]+)""#) ?? "")
            let href = decode(first(block, pattern: #"href="([^"]+)""#) ?? "/video?c=\(id)")
            guard !title.isEmpty else { continue }
            items.append(PHCategory(categoryID: id, title: title, count: count, thumb: thumb, href: href))
        }
        return items
    }

    static func performers(in html: String) -> [PHPerformer] {
        var items: [PHPerformer] = []
        var seen = Set<String>()
        if let list = first(html, pattern: #"search-list='(\[.*?\])'"#) ?? first(html, pattern: #"search-list="(\[.*?\])""#),
           let data = decode(list).data(using: .utf8),
           let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for row in rows {
                guard let href = string(row["href"]), let name = string(row["value"]), !name.isEmpty else { continue }
                let avatar = string(row["avatar"]) ?? ""
                guard seen.insert(href).inserted else { continue }
                items.append(PHPerformer(name: name, href: href, avatar: avatar, rank: "", verified: true))
            }
        }
        for block in slices(html, open: "<div class=\"pornstarWrap\"", close: "</div>", requiring: "/pornstar/") {
            guard let href = first(block, pattern: #"href="([^"]+)""#) else { continue }
            guard seen.insert(href).inserted else { continue }
            let avatar = decode(first(block, pattern: #"src="([^"]+)""#) ?? "")
            let name = clean(first(block, pattern: #"alt="([^"]+)""#) ?? first(block, pattern: #"class="performerNameInfo">(.*?)</div>"#) ?? "")
            let rank = clean(first(block, pattern: #"class="rank_number">([^<]+)"#) ?? "")
            guard !name.isEmpty else { continue }
            items.append(PHPerformer(name: name, href: decode(href), avatar: avatar, rank: rank, verified: block.contains("verified")))
        }
        return items
    }

    static func gifs(in html: String) -> [PHGIF] {
        var items: [PHGIF] = []
        var seen = Set<String>()
        for block in slices(html, open: "<li", close: "</li>", requiring: "href=\"/gif/") {
            guard let href = first(block, pattern: #"href="(/gif/\d+)""#), seen.insert(href).inserted else { continue }
            let id = href.split(separator: "/").last.map(String.init) ?? href
            let title = clean(first(block, pattern: #"title="([^"]+)""#) ?? first(block, pattern: #"alt="([^"]+)""#) ?? "动图")
            let still = decode(first(block, pattern: #"src="([^"]+)""#) ?? "")
            let animated = decode(first(block, pattern: #"data-gif-url="([^"]+)""#) ?? "")
            items.append(PHGIF(id: id, title: title, still: still, animated: animated, href: href))
        }
        return items
    }

    static func albums(in html: String) -> [PHAlbum] {
        var items: [PHAlbum] = []
        var seen = Set<String>()
        for block in slices(html, open: "<li", close: "</li>", requiring: "href=\"/album/") {
            guard let href = first(block, pattern: #"href="(/album/\d+)""#), seen.insert(href).inserted else { continue }
            let id = href.split(separator: "/").last.map(String.init) ?? href
            let title = clean(first(block, pattern: #"alt="([^"]+)""#) ?? "")
            let thumb = decode(first(block, pattern: #"src="([^"]+)""#) ?? "")
            let count = clean(first(block, pattern: #"(\d+)\s*照片"#) ?? "")
            guard !title.isEmpty else { continue }
            items.append(PHAlbum(id: id, title: title, thumb: thumb, href: href, photoCount: count, verified: block.contains("verified")))
        }
        return items
    }

    static func photos(in html: String) -> [PHPhoto] {
        var items: [PHPhoto] = []
        var seen = Set<String>()
        let pattern = #"<a\b([^>]*href="/photo/\d+"[^>]*)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = html as NSString
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let attrs = ns.substring(with: match.range(at: 1))
            guard let href = first(attrs, pattern: #"href="([^"]+)""#), seen.insert(href).inserted else { continue }
            let thumb = decode(first(attrs, pattern: #"data-bkg="([^"]+)""#) ?? first(attrs, pattern: #"src="([^"]+)""#) ?? "")
            let id = href.split(separator: "/").last.map(String.init) ?? href
            items.append(PHPhoto(id: id, href: href, thumb: thumb, rating: "", views: ""))
        }
        return items
    }

    static func photoImage(in html: String, photoID: String) -> String {
        let pattern = #"https://[^"']+/pics/albums/[^"']*\(photoID)[^"']+\.jpg[^"']*"#
        return decode(first(html, pattern: pattern) ?? "")
    }

    static func playlists(in html: String) -> [PHPlaylist] {
        var items: [PHPlaylist] = []
        var seen = Set<String>()
        for block in slices(html, open: "<li", close: "</li>", requiring: "/playlist/") {
            guard let href = first(block, pattern: #"href="(/playlist/\d+)""#), seen.insert(href).inserted else { continue }
            let id = href.split(separator: "/").last.map(String.init) ?? href
            let title = clean(first(block, pattern: #"alt="([^"]+)""#) ?? first(block, pattern: #"href="/playlist/\d+"[^>]*>([^<]+)</a>"#) ?? "")
            let thumb = decode(first(block, pattern: #"src="([^"]+)""#) ?? "")
            let models = clean(first(block, pattern: #"class="modelsList"[^>]*>(.*?)</div>"#) ?? "")
            guard !title.isEmpty else { continue }
            items.append(PHPlaylist(id: id, title: title, thumb: thumb, href: href, models: models))
        }
        return items
    }

    static func playlistChunkToken(in html: String) -> (id: String, token: String)? {
        let decoded = decode(html)
        guard let id = first(decoded, pattern: #"viewChunked\?id=(\d+)"#) else { return nil }
        let token = first(decoded, pattern: #"viewChunked\?id=\d+&token=([^"&]+)"#) ?? ""
        return (id, token)
    }

    static func profile(in html: String, href: String) -> PHProfile {
        let name = clean(first(html, pattern: #"class="title js-profile-header-title"[^>]*>\s*([^<]+)"#)
            ?? first(html, pattern: #"<title>([^<|]+)"#)
            ?? "")
        let avatar = decode(first(html, pattern: #"id="getAvatar"[^>]+src="([^"]+)""#) ?? "")
        let subscribers = clean(first(html, pattern: #"([0-9][0-9.,]*[KMB]?)\s*订阅者"#) ?? "")
        let about = clean(first(html, pattern: #"class="aboutMeSection"[^>]*>(.*?)</div>"#) ?? "")
        return PHProfile(name: name, avatar: avatar, subscribers: subscribers, href: href, about: about, videos: videos(in: html))
    }

    static func loginToken(in html: String) -> String {
        first(html, pattern: #"name="token"[\s\S]{0,80}?value="([^"]+)""#) ?? ""
    }

    static func loginRedirect(in html: String) -> String {
        first(html, pattern: #"name="redirect"[\s\S]{0,200}?value="([^"]+)""#) ?? ""
    }

    static func menuDestinations() -> [(title: String, path: String, icon: String)] {
        [
            ("精选色情片", "/video", "film"),
            ("推荐视频", "/recommended", "hand.thumbsup"),
            ("最热", "/video?o=ht", "flame"),
            ("Shorties", "/shorties", "play.rectangle"),
            ("分类", "/categories", "square.grid.2x2"),
            ("色情明星", "/pornstars", "star"),
            ("频道", "/channels", "dot.radiowaves.left.and.right"),
            ("片单", "/playlists", "list.bullet.rectangle"),
            ("动图", "/gifs", "livephoto"),
            ("照片", "/albums", "photo"),
            ("社区比赛", "/contest_hub", "trophy")
        ]
    }

    static func duration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0:00" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func flashvarsJSON(in html: String) -> String? {
        guard let marker = html.range(of: "var flashvars_") else { return nil }
        guard let brace = html[marker.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = brace
        while index < html.endIndex {
            let character = html[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(html[brace...index])
                }
            }
            index = html.index(after: index)
        }
        return nil
    }

    private static func jsonObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return decode(text) }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String { return text == "1" || text == "true" }
        return false
    }

    private static func formatCount(_ value: Any) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            if raw >= 1_000_000 { return String(format: "%.1fM", raw / 1_000_000).replacingOccurrences(of: ".0", with: "") }
            if raw >= 1_000 { return String(format: "%.1fK", raw / 1_000).replacingOccurrences(of: ".0", with: "") }
            return number.stringValue
        }
        return ""
    }

    private static func path(_ url: String) -> String {
        guard let components = URL(string: url) else { return url }
        return components.path.isEmpty ? url : components.path
    }

    static func clean(_ value: String) -> String {
        var text = decode(value)
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decode(_ value: String) -> String {
        var text = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
        if text.contains("\\u") || text.contains("&#") {
            text = text.decodingUnicodeEscapes
        }
        return text.removingPercentEncoding.map { $0 == text ? text : text } ?? text
    }

    static func first(_ text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let hit = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[hit])
    }

    static func matches(_ text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let hit = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[hit])
        }
    }

    static func pairMatches(_ text: String, pattern: String) -> [(String, String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 2,
                  let a = Range(match.range(at: 1), in: text),
                  let b = Range(match.range(at: 2), in: text) else { return nil }
            return (String(text[a]), String(text[b]))
        }
    }

    static func slices(_ text: String, open: String, close: String, requiring needle: String) -> [String] {
        var items: [String] = []
        var search = text.startIndex
        while search < text.endIndex, let found = text.range(of: open, range: search..<text.endIndex) {
            guard let end = text.range(of: close, range: found.lowerBound..<text.endIndex) else { break }
            let block = String(text[found.lowerBound..<end.upperBound])
            if block.contains(needle) { items.append(block) }
            search = end.upperBound
            if items.count > 400 { break }
        }
        return items
    }
}

private extension String {
    var decodingUnicodeEscapes: String {
        var result = ""
        var cursor = startIndex
        while cursor < endIndex {
            if self[cursor] == "\\", let last = self.index(endIndex, offsetBy: -1, limitedBy: startIndex), cursor < last {
                let next = self.index(after: cursor)
                if self[next] == "u", let end = self.index(cursor, offsetBy: 6, limitedBy: endIndex) {
                    let hex = self[self.index(cursor, offsetBy: 2)..<end]
                    if let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) {
                        result.append(Character(scalar))
                        cursor = end
                        continue
                    }
                }
            }
            if self[cursor] == "&", let hash = self.index(cursor, offsetBy: 2, limitedBy: endIndex), self[self.index(after: cursor)] == "#" {
                let start = hash
                if let semi = self[start...].firstIndex(of: ";") {
                    let body = self[start..<semi]
                    let number = body.hasPrefix("x") ? UInt32(body.dropFirst(), radix: 16) : UInt32(body)
                    if let number, let scalar = UnicodeScalar(number) {
                        result.append(Character(scalar))
                        cursor = self.index(after: semi)
                        continue
                    }
                }
            }
            result.append(self[cursor])
            cursor = self.index(after: cursor)
        }
        return result
    }
}
