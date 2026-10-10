import SwiftUI

enum PHTheme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let elevated = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let card = Color(red: 0.16, green: 0.16, blue: 0.16)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.0)
    static let text = Color.white
    static let secondary = Color(white: 0.72)
    static let muted = Color(white: 0.48)
    static let hairline = Color.white.opacity(0.08)
}

struct PHRemoteImage: View {
    let url: String
    var ratio: CGFloat = 16.0 / 9.0

    var body: some View {
        Color.black
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                if let target = URL(string: url), !url.isEmpty {
                    AsyncImage(url: target) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(PHTheme.muted)
                        default:
                            ProgressView().tint(PHTheme.orange)
                        }
                    }
                }
            }
            .clipped()
    }
}

@MainActor
final class PHLibrary: ObservableObject {
    @Published var liked: [PHVideo] = []
    @Published var history: [PHVideo] = []
    @Published var subscriptions: [PHSubscription] = []
    @Published var account: PHAccount?

    private let likedKey = "ph.liked"
    private let historyKey = "ph.history"
    private let accountKey = "ph.account"
    private let subscriptionKey = "ph.subscriptions"

    init() {
        liked = Self.videos(likedKey)
        history = Self.videos(historyKey)
        subscriptions = Self.subscriptions(subscriptionKey)
        account = Self.account(accountKey)
    }

    func toggleLike(_ video: PHVideo) {
        if let index = liked.firstIndex(of: video) {
            liked.remove(at: index)
        } else {
            liked.insert(video, at: 0)
        }
        Self.save(liked, likedKey)
    }

    func isLiked(_ video: PHVideo) -> Bool { liked.contains(video) }

    func remember(_ video: PHVideo) {
        history.removeAll { $0.vkey == video.vkey }
        history.insert(video, at: 0)
        if history.count > 80 { history.removeLast(history.count - 80) }
        Self.save(history, historyKey)
    }

    func signIn(_ account: PHAccount) {
        self.account = account
        Self.save(account, accountKey)
    }

    func signOut() {
        account = nil
        UserDefaults.standard.removeObject(forKey: accountKey)
    }

    func isSubscribed(_ profile: PHProfile) -> Bool {
        subscriptions.contains { $0.userID == profile.userID && !profile.userID.isEmpty }
    }

    func syncSubscription(_ profile: PHProfile, subscribed: Bool) {
        subscriptions.removeAll { $0.userID == profile.userID || ($0.href == profile.href && !profile.href.isEmpty) }
        if subscribed {
            subscriptions.insert(PHSubscription(userID: profile.userID, name: profile.name, href: profile.href, avatar: profile.avatar), at: 0)
        }
        Self.save(subscriptions, subscriptionKey)
    }

    private static func subscriptions(_ key: String) -> [PHSubscription] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode([PHSubscription].self, from: data) else { return [] }
        return value
    }

    private static func videos(_ key: String) -> [PHVideo] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode([PHVideo].self, from: data) else { return [] }
        return value
    }

    private static func account(_ key: String) -> PHAccount? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PHAccount.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
