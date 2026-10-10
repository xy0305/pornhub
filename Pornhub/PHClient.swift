import Foundation

actor PHClient {
    static let origin = URL(string: "https://cn.pornhub.com")!
    private let session: URLSession
    private let jar: HTTPCookieStorage

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.6"
        ]
        let storage = HTTPCookieStorage.shared
        configuration.httpCookieStorage = storage
        jar = storage
        session = URLSession(configuration: configuration)
    }

    func home() async throws -> (videos: [PHVideo], chips: [PHChip]) {
        let html = try await text(url: Self.origin)
        return (PHParser.videos(in: html), PHParser.chips(in: html))
    }

    func listing(path: String, page: Int, sort: PHSort = .featured) async throws -> PHPage {
        var components = URLComponents(url: Self.origin, resolvingAgainstBaseURL: false)!
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        components.path = parts.first?.isEmpty == false ? parts[0] : "/"
        var items = URLComponents(string: "https://x.test/?" + (parts.count > 1 ? parts[1] : ""))?.queryItems ?? []
        if page > 1 {
            items.removeAll { $0.name == "page" }
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if !sort.rawValue.isEmpty, !items.contains(where: { $0.name == "o" }) {
            items.append(URLQueryItem(name: "o", value: sort.rawValue))
        }
        components.queryItems = items.isEmpty ? nil : items
        let html = try await text(url: components.url ?? Self.origin)
        return PHParser.page(in: html, current: page)
    }

    func search(query: String, page: Int, sort: PHSort) async throws -> PHPage {
        var items = [
            URLQueryItem(name: "search", value: query)
        ]
        if page > 1 { items.append(URLQueryItem(name: "page", value: String(page))) }
        if !sort.rawValue.isEmpty { items.append(URLQueryItem(name: "o", value: sort.rawValue)) }
        return try await get(path: "/video/search", items: items)
    }

    func detail(_ video: PHVideo) async throws -> PHVideoDetail {
        let html = try await text(url: url("/view_video.php", [URLQueryItem(name: "viewkey", value: video.vkey)]))
        var detail = PHParser.detail(in: html, fallback: video)
        if detail.video.author.isEmpty { detail.video.author = video.author }
        if detail.video.authorURL.isEmpty { detail.video.authorURL = video.authorURL }
        if detail.video.thumb.isEmpty { detail.video.thumb = video.thumb }
        if detail.video.views.isEmpty { detail.video.views = video.views }
        return detail
    }

    func related(url: String, videoID: String) async throws -> [PHVideo] {
        let target: URL
        if url.isEmpty {
            target = self.url("/api/v1/video/player_related_datas", [URLQueryItem(name: "id", value: videoID)])
        } else if let parsed = URL(string: url), parsed.host != nil {
            target = parsed
        } else {
            target = PHParser.absolute(url).asURL ?? Self.origin
        }
        let data = try await data(url: target, referer: Self.origin.absoluteString)
        return PHParser.related(from: data)
    }

    func categories() async throws -> [PHCategory] {
        PHParser.categories(in: try await text(url: url("/categories")))
    }

    func performers(path: String) async throws -> [PHPerformer] {
        PHParser.performers(in: try await text(url: url(path)))
    }

    func suggestions() async throws -> (searches: [PHSuggestion], performers: [PHSuggestion]) {
        PHParser.suggestions(in: try await text(url: Self.origin))
    }

    func profile(href: String) async throws -> PHProfile {
        PHParser.profile(in: try await text(url: PHParser.absolute(href).asURL ?? Self.origin), href: href)
    }

    func gifs(page: Int) async throws -> [PHGIF] {
        var items: [URLQueryItem] = [URLQueryItem(name: "o", value: "tr")]
        if page > 1 { items.append(URLQueryItem(name: "page", value: String(page))) }
        return PHParser.gifs(in: try await text(url: url("/gifs", items)))
    }

    func albums(page: Int) async throws -> [PHAlbum] {
        var items: [URLQueryItem] = []
        if page > 1 { items.append(URLQueryItem(name: "page", value: String(page))) }
        return PHParser.albums(in: try await text(url: url("/albums", items)))
    }

    func photos(albumHref: String) async throws -> [PHPhoto] {
        PHParser.photos(in: try await text(url: PHParser.absolute(albumHref).asURL ?? Self.origin))
    }

    func photoImage(href: String) async throws -> String {
        let html = try await text(url: PHParser.absolute(href).asURL ?? Self.origin)
        let id = href.split(separator: "/").last.map(String.init) ?? ""
        return PHParser.photoImage(in: html, photoID: id)
    }

    func playlists(page: Int) async throws -> [PHPlaylist] {
        var items: [URLQueryItem] = []
        if page > 1 { items.append(URLQueryItem(name: "page", value: String(page))) }
        return PHParser.playlists(in: try await text(url: url("/playlists", items)))
    }

    func playlistVideos(href: String) async throws -> [PHVideo] {
        let page = try await text(url: PHParser.absolute(href).asURL ?? Self.origin)
        let direct = PHParser.videos(in: page)
        if !direct.isEmpty { return direct }
        guard let token = PHParser.playlistChunkToken(in: page) else { return [] }
        var items = [URLQueryItem(name: "id", value: token.id)]
        if !token.token.isEmpty { items.append(URLQueryItem(name: "token", value: token.token)) }
        let chunk = try await text(
            url: url("/playlist/viewChunked", items),
            referer: PHParser.absolute(href),
            ajax: true
        )
        let parsed = PHParser.videos(in: chunk)
        if !parsed.isEmpty { return parsed }
        return playlistLinks(in: chunk)
    }

    func authenticate(email: String, password: String) async throws -> PHAccount {
        let login = try await text(url: url("/login"))
        let token = PHParser.loginToken(in: login)
        let redirect = PHParser.loginRedirect(in: login)
        let body = [
            "redirect": redirect,
            "user_id": "",
            "token": token,
            "from": "pc_login_modal",
            "email": email,
            "password": password,
            "remember_me": "on"
        ]
        return try await submitLogin(body, provider: "email", fallbackName: email.split(separator: "@").first.map(String.init) ?? email)
    }

    func authenticateGoogle(accessToken: String) async throws -> PHAccount {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw PHError.login("没有收到 Google 凭证") }
        let login = try await text(url: url("/login"))
        let body = [
            "redirect": PHParser.loginRedirect(in: login),
            "user_id": "",
            "token": PHParser.loginToken(in: login),
            "from": "pc_login_modal",
            "email": "",
            "password": "",
            "sso_token": token,
            "remember_me": "on"
        ]
        return try await submitLogin(body, provider: "google", fallbackName: "Google")
    }

    func setSubscription(profile: PHProfile, subscribe: Bool) async throws -> Bool {
        let template = subscribe ? profile.subscribeURL : profile.unsubscribeURL
        guard !template.isEmpty, !profile.userID.isEmpty else {
            throw PHError.login("这个资料页没有订阅接口")
        }
        let target = url(template, [URLQueryItem(name: "id", value: profile.userID)])
        let payload = try await data(url: target, referer: PHParser.absolute(profile.href), ajax: true)
        let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any]
        let success = (object?["success"] as? String)?.uppercased() == "PASS" || (object?["success"] as? Bool) == true
        guard success else {
            let message = (object?["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "订阅没有被官网接受"
            throw PHError.login(message)
        }
        return subscribe
    }

    var hasSessionCookie: Bool {
        let cookies = jar.cookies(for: Self.origin) ?? []
        return cookies.contains { ["il","ss","sessid","ua"].contains($0.name) == false && ($0.name.contains("login") || $0.name == "gateway_security_key" || $0.name.contains("auth")) }
            || cookies.contains { $0.name == "il" && !$0.value.isEmpty }
    }

    private func submitLogin(_ fields: [String: String], provider: String, fallbackName: String) async throws -> PHAccount {
        var request = URLRequest(url: url("/front/authenticate"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(Self.origin.absoluteString + "/login", forHTTPHeaderField: "Referer")
        request.setValue(Self.origin.absoluteString, forHTTPHeaderField: "Origin")
        request.httpBody = form(fields).data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<400).contains(status) else { throw PHError.login("登录请求失败 \(status)") }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let redirect = (object?["redirect"] as? String) ?? (object?["redirectUrl"] as? String) ?? ""
        let message = (object?["message"] as? String) ?? ""
        guard !redirect.isEmpty else {
            if message.localizedCaseInsensitiveContains("captcha") || message.localizedCaseInsensitiveContains("recaptcha") {
                throw PHError.login("官网要求验证码，这次没有登录成功")
            }
            throw PHError.login(message.isEmpty ? "登录没有被官网接受" : message)
        }
        let email = (object?["email"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fields["email"].flatMap { $0.isEmpty ? nil : $0 } ?? ""
        let name = (object?["username"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? email.split(separator: "@").first.map(String.init)
            ?? fallbackName
        return PHAccount(email: email.isEmpty ? name : email, displayName: name, provider: provider)
    }

    private func get(path: String, items: [URLQueryItem]) async throws -> PHPage {
        let html = try await text(url: url(path, items))
        let page = items.first { $0.name == "page" }.flatMap { Int($0.value ?? "") } ?? 1
        return PHParser.page(in: html, current: page)
    }

    private func playlistLinks(in html: String) -> [PHVideo] {
        var items: [PHVideo] = []
        var seen = Set<String>()
        for href in PHParser.matches(html, pattern: #"href="([^"]*viewkey=[^"]+)""#) {
            guard let vkey = PHParser.first(href, pattern: #"viewkey=([A-Za-z0-9]+)"#), seen.insert(vkey).inserted else { continue }
            items.append(PHVideo(vkey: vkey, videoID: vkey, title: "片单视频", thumb: "", preview: "", duration: "", views: "", author: "", authorURL: "", verified: false))
        }
        return items
    }

    private func text(url: URL, referer: String? = nil, ajax: Bool = false) async throws -> String {
        let data = try await data(url: url, referer: referer, ajax: ajax)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw PHError.network("页面编码无法识别")
        }
        if text.contains("Access Denied") || text.contains("cf-error") {
            throw PHError.network("站点暂时拒绝访问")
        }
        return text
    }

    private func data(url: URL, referer: String?, ajax: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(referer ?? Self.origin.absoluteString + "/", forHTTPHeaderField: "Referer")
        if ajax { request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With") }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<400).contains(status) else { throw PHError.network("请求失败 \(status)") }
        return data
    }

    private func url(_ path: String, _ items: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: Self.origin, resolvingAgainstBaseURL: false)!
        if path.hasPrefix("http"), let parsed = URL(string: path) { return parsed }
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        components.path = parts[0].isEmpty ? "/" : parts[0]
        var query = URLComponents(string: "https://x.test/?" + (parts.count > 1 ? parts[1] : ""))?.queryItems ?? []
        query.append(contentsOf: items)
        components.queryItems = query.isEmpty ? nil : query
        return components.url ?? Self.origin
    }

    private func form(_ fields: [String: String]) -> String {
        fields.map { key, value in
            "\(key.formEncoded)=\(value.formEncoded)"
        }.joined(separator: "&")
    }

    private func message(from html: String) -> String? {
        let text = PHParser.clean(PHParser.first(html, pattern: #"class="signinError[^"]*"[^>]*>(.*?)</span>"#) ?? "")
        return text.isEmpty ? nil : text
    }
}

enum PHError: LocalizedError {
    case network(String)
    case login(String)

    var errorDescription: String? {
        switch self {
        case .network(let message), .login(let message): return message
        }
    }
}

private extension PHPage {
    func replacing(with page: PHPage) -> PHPage { page }
}

private extension String {
    var asURL: URL? { URL(string: self) }
    var formEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}
