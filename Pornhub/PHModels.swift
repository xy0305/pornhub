import Foundation

struct PHVideo: Identifiable, Hashable, Codable {
    var id: String { vkey }
    var vkey: String
    var videoID: String
    var title: String
    var thumb: String
    var preview: String
    var duration: String
    var views: String
    var author: String
    var authorURL: String
    var verified: Bool

    var authorKind: PHAuthorKind { PHAuthorKind(url: authorURL) }
}

enum PHAuthorKind: String, Codable {
    case model, pornstar, channel, user, unknown

    init(url: String) {
        if url.contains("/model/") { self = .model }
        else if url.contains("/pornstar/") { self = .pornstar }
        else if url.contains("/channels/") { self = .channel }
        else if url.contains("/users/") || url.contains("/user/") { self = .user }
        else { self = .unknown }
    }

    var slug: String {
        ""
    }
}

struct PHQuality: Identifiable, Hashable, Codable {
    var id: String { url.absoluteString }
    var label: String
    var height: Int
    var url: URL
    var isDefault: Bool
}

enum PHPlayerGesturePolicy {
    static func adjusted(initial: CGFloat, translation: CGFloat, height: CGFloat) -> CGFloat {
        min(1, max(0, initial - translation / max(180, height * 0.8)))
    }
}

/// Resolution comes from source metadata, never from a site default flag.
/// Unknown/adaptive sources remain usable, but never claim a made-up resolution.
enum PHQualityPolicy {
    static func ranked(_ qualities: [PHQuality]) -> [PHQuality] {
        var seen = Set<URL>()
        return qualities.enumerated().filter {
            ["http", "https"].contains($0.element.url.scheme?.lowercased() ?? "") &&
            $0.element.url.host?.isEmpty == false
        }.sorted {
            let lhs = max(0, $0.element.height), rhs = max(0, $1.element.height)
            return lhs == rhs ? $0.offset < $1.offset : lhs > rhs
        }.map(\.element).filter { seen.insert($0.url).inserted }
    }
}

/// Per-player intent survives signed-URL refresh and temporary empty metadata.
struct PHQualitySelection {
    private(set) var videoID: String?
    private(set) var selected: PHQuality?
    private(set) var manual = false

    mutating func choose(_ quality: PHQuality) {
        selected = quality
        manual = true
    }

    mutating func update(_ qualities: [PHQuality], videoID: String) -> Int? {
        if self.videoID != videoID {
            self.videoID = videoID
            selected = nil
            manual = false
        }
        guard !qualities.isEmpty else { return nil }
        let index: Int
        if manual, let selected {
            // Keep exact source first, then the same real resolution on URL renewal.
            index = qualities.firstIndex { $0.url == selected.url } ??
                qualities.firstIndex { $0.height == selected.height && $0.label == selected.label } ??
                (manual ? (qualities.firstIndex { $0.height <= selected.height } ?? 0) : 0)
        } else {
            index = 0
        }
        selected = qualities[index]
        return index
    }
}

struct PHVideoDetail: Hashable {
    var video: PHVideo
    var qualities: [PHQuality]
    var tags: [PHChip]
    var viewsText: String
    var ratingText: String
    var durationSeconds: Int
    var relatedURL: String
}

struct PHChip: Identifiable, Hashable, Codable {
    var id: String { title + "|" + href }
    var title: String
    var href: String
    var systemImage: String?
}

struct PHCategory: Identifiable, Hashable, Codable {
    var id: String { "\(categoryID)|\(href)" }
    var categoryID: String
    var title: String
    var count: String
    var thumb: String
    var href: String
}

struct PHPerformer: Identifiable, Hashable, Codable {
    var id: String { href }
    var name: String
    var href: String
    var avatar: String
    var rank: String
    var verified: Bool
}

struct PHGIF: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var still: String
    var animated: String
    var href: String
}

struct PHAlbum: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var thumb: String
    var href: String
    var photoCount: String
    var verified: Bool
}

struct PHPhoto: Identifiable, Hashable, Codable {
    var id: String
    var href: String
    var thumb: String
    var rating: String
    var views: String
}

struct PHPlaylist: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var thumb: String
    var href: String
    var models: String
}

struct PHProfile: Hashable {
    var name: String
    var avatar: String
    var subscribers: String
    var rank: String
    var views: String
    var href: String
    var about: String
    var userID: String
    var subscribed: Bool
    var subscribeURL: String
    var unsubscribeURL: String
    var videos: [PHVideo]
}

struct PHSuggestion: Identifiable, Hashable, Codable {
    var id: String { title + "|" + href }
    var title: String
    var href: String
    var avatar: String
}

struct PHSubscription: Identifiable, Hashable, Codable {
    var id: String { userID }
    var userID: String
    var name: String
    var href: String
    var avatar: String
}

struct PHPage {
    var videos: [PHVideo]
    var nextPage: Int?
}

struct PHAccount: Codable, Hashable {
    var email: String
    var displayName: String
    var provider: String
}

enum PHOrientation: String, CaseIterable, Identifiable, Codable {
    case straight, gay, lesbian, trans
    var id: String { rawValue }

    var title: String {
        switch self {
        case .straight: return "异性恋"
        case .gay: return "男同"
        case .lesbian: return "女女萨福系"
        case .trans: return "变性"
        }
    }

    var path: String {
        switch self {
        case .straight: return "/"
        case .gay: return "/gayporn"
        case .lesbian: return "/lesbian"
        case .trans: return "/transgender"
        }
    }

    var systemImage: String {
        switch self {
        case .straight: return "figure.stand.dress"
        case .gay: return "figure.2"
        case .lesbian: return "figure.2.arms.open"
        case .trans: return "figure.dress.line.vertical.figure"
        }
    }
}

enum PHSort: String, CaseIterable, Identifiable {
    case featured = ""
    case newest = "mr"
    case mostViewed = "mv"
    case topRated = "tr"
    case longest = "lg"
    case hottest = "ht"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured: return "最相关"
        case .newest: return "最新"
        case .mostViewed: return "最多次观看"
        case .topRated: return "最高分"
        case .longest: return "最长"
        case .hottest: return "最热"
        }
    }
}

enum PHRoute: Hashable {
    case video(PHVideo)
    case search(String)
    case listing(title: String, path: String)
    case categoryGrid
    case performerGrid(title: String, path: String)
    case profile(href: String, name: String)
    case gifs
    case gif(PHGIF)
    case albums
    case album(PHAlbum)
    case photo(PHPhoto)
    case playlists
    case playlist(PHPlaylist)
    case shorties
    case login
    case liked
    case history
    case subscriptions
}
