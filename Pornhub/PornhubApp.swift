import SwiftUI
import KSPlayer

@main
struct PornhubApp: App {
    @UIApplicationDelegateAdaptor(PHAppDelegate.self) private var appDelegate
    @StateObject private var library = PHLibrary()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-PHQualityFixture") {
                    PHQualityInteractionFixture()
                } else if ProcessInfo.processInfo.arguments.contains("-PHProfileFixture") {
                    NavigationStack {
                        PHProfileView(href: "/model/fixture/videos", name: "Fixture Author", path: .constant(NavigationPath()))
                    }
                } else if ProcessInfo.processInfo.arguments.contains("-PHSubscriptionsFixture") {
                    NavigationStack { PHServerSubscriptionsView(path: .constant(NavigationPath())) }
                } else {
                    PHRootView()
                }
                #else
                PHRootView()
                #endif
            }
                .environmentObject(library)
                .preferredColorScheme(.dark)
        }
    }
}

#if DEBUG
private struct PHQualityInteractionFixture: View {
    @State private var refreshed = false
    var body: some View {
        VStack(spacing: 24) {
            PHPlayer(qualities: [
                PHQuality(label: "360p", height: 360, url: URL(string: "http://127.0.0.1:9/360.mp4?revision=\(refreshed ? 1 : 0)")!, isDefault: true),
                PHQuality(label: "720p", height: 720, url: URL(string: "http://127.0.0.1:9/720.mp4?revision=\(refreshed ? 1 : 0)")!, isDefault: false)
            ], videoID: "quality-fixture")
            Button("刷新测试资源") { refreshed.toggle() }
                .accessibilityIdentifier("player.fixture.refresh")
                .frame(minHeight: 44)
            Text("Synthetic fixture · unavailable localhost sources")
                .font(.caption).foregroundStyle(PHTheme.secondary)
        }
    }
}
#endif

/// KSPlayer documents this delegate bridge for its orientation mask.
final class PHAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        KSOptions.supportedInterfaceOrientations
    }
}

enum PHHomeSheet: String, Identifiable {
    case menu, search, account
    var id: String { rawValue }
}

struct PHRootView: View {
    @EnvironmentObject private var library: PHLibrary
    @State private var path = NavigationPath()
    @State private var activeSheet: PHHomeSheet?
    @State private var pendingRoute: PHRoute?
    @State private var orientation: PHOrientation = .straight

    var body: some View {
        NavigationStack(path: $path) {
            PHHomeView(path: $path) { activeSheet = $0 }
                .navigationDestination(for: PHRoute.self) { route in
                    destination(route)
                }
        }
        .tint(PHTheme.orange)
        .sheet(item: $activeSheet, onDismiss: finishSheetNavigation) { sheet in
            switch sheet {
            case .menu:
                PHMenuView(orientation: $orientation, onSelect: openAfterSheet) {
                    activeSheet = nil
                }
                .presentationDetents([.large])
            case .search:
                PHSearchSheet { query in
                    openAfterSheet(.search(query))
                } onOpen: { route in
                    openAfterSheet(route)
                }
            case .account:
                PHAccountSheet().environmentObject(library)
            }
        }
    }

    // Navigation waits for the sheet's dismissal; do not push behind a modal.
    private func openAfterSheet(_ route: PHRoute) {
        pendingRoute = route
        activeSheet = nil
    }

    private func finishSheetNavigation() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        path.append(route)
    }

    @ViewBuilder
    private func destination(_ route: PHRoute) -> some View {
        switch route {
        case .video(let video):
            PHVideoDetailView(video: video, path: $path)
        case .search(let query):
            PHListingView(title: query, path: "/video/search", query: query, pathStack: $path)
        case .listing(let title, let listingPath):
            PHListingView(title: title, path: listingPath, pathStack: $path)
        case .categoryGrid:
            PHCategoryGrid(path: $path)
        case .performerGrid(let title, let source):
            PHPerformerGrid(title: title, source: source, path: $path)
        case .profile(let href, let name):
            PHProfileView(href: href, name: name, path: $path)
        case .gifs:
            PHGIFGrid(path: $path)
        case .gif(let gif):
            PHGIFPlayer(gif: gif)
        case .albums:
            PHAlbumGrid(path: $path)
        case .album(let album):
            PHAlbumView(album: album, path: $path)
        case .photo(let photo):
            PHPhotoView(photo: photo)
        case .playlists:
            PHPlaylistGrid(path: $path)
        case .playlist(let playlist):
            PHPlaylistView(playlist: playlist, path: $path)
        case .shorties:
            PHListingView(title: "Shorties", path: "/shorties", pathStack: $path)
        case .login:
            PHAccountSheet()
        case .liked:
            PHSavedList(title: "已点赞", videos: library.liked, path: $path)
        case .history:
            PHSavedList(title: "观看记录", videos: library.history, path: $path)
        case .subscriptions:
            PHSubscriptionList(path: $path)
        }
    }
}
