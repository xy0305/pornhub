import SwiftUI

@main
struct PornhubApp: App {
    @StateObject private var library = PHLibrary()

    var body: some Scene {
        WindowGroup {
            PHRootView()
                .environmentObject(library)
                .preferredColorScheme(.dark)
        }
    }
}

struct PHRootView: View {
    @EnvironmentObject private var library: PHLibrary
    @State private var path = NavigationPath()
    @State private var showMenu = false
    @State private var showSearch = false
    @State private var showAccount = false
    @State private var orientation: PHOrientation = .straight

    var body: some View {
        NavigationStack(path: $path) {
            PHHomeView(path: $path, showMenu: $showMenu, showSearch: $showSearch, showAccount: $showAccount)
                .navigationDestination(for: PHRoute.self) { route in
                    destination(route)
                }
        }
        .tint(PHTheme.orange)
        .sheet(isPresented: $showMenu) {
            PHMenuView(orientation: $orientation) { route in
                showMenu = false
                path.append(route)
            } close: {
                showMenu = false
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSearch) {
            PHSearchSheet { query in
                path.append(PHRoute.search(query))
            }
        }
        .sheet(isPresented: $showAccount) {
            PHAccountSheet()
                .environmentObject(library)
        }
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
        }
    }
}
