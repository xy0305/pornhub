import SwiftUI

struct PHHomeView: View {
    @EnvironmentObject private var library: PHLibrary
    @StateObject private var model = PHHomeModel()
    @Binding var path: NavigationPath
    @Binding var showMenu: Bool
    @Binding var showSearch: Bool
    @Binding var showAccount: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                titleRow
                if !model.chips.isEmpty {
                    PHChipRow(chips: model.chips) { chip in
                        open(chip)
                    }
                }
                if let message = model.error, model.videos.isEmpty {
                    PHErrorBanner(message: message) { Task { await model.reload() } }
                }
                ForEach(model.videos) { video in
                    Button {
                        library.remember(video)
                        path.append(PHRoute.video(video))
                    } label: {
                        PHVideoCard(video: video)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if video.id == model.videos.last?.id {
                            Task { await model.loadMore() }
                        }
                    }
                }
                if model.loadingMore || (model.loading && model.videos.isEmpty) {
                    PHLoading()
                }
            }
            .padding(.bottom, 28)
        }
        .background(PHTheme.background)
        .refreshable { await model.reload() }
        .task { await model.loadIfNeeded() }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
    }

    private var header: some View {
        HStack(spacing: 2) {
            iconButton("line.3.horizontal", color: PHTheme.orange) { showMenu = true }
            iconButton("figure.stand.dress", color: .white) { showMenu = true }
            Image(systemName: "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 44)
                .overlay(alignment: .bottom) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .offset(y: 8)
                }
                .onTapGesture { path.append(PHRoute.liked) }
            Spacer()
            PHLogo()
            Spacer()
            iconButton("magnifyingglass", color: .white) { showSearch = true }
            iconButton("person.crop.circle", color: Color(white: 0.75)) { showAccount = true }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .background(PHTheme.background)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text("热门色情视频")
                .font(.system(size: 26, weight: .bold))
            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
                .overlay(Image(systemName: "globe").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private func iconButton(_ name: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func open(_ chip: PHChip) {
        if chip.href.contains("/shorties") {
            path.append(PHRoute.shorties)
        } else if let query = queryValue(chip.href, name: "search") {
            path.append(PHRoute.search(query))
        } else {
            path.append(PHRoute.listing(title: chip.title, path: chip.href))
        }
    }

    private func queryValue(_ href: String, name: String) -> String? {
        let decoded = href.removingPercentEncoding ?? href
        guard let components = URLComponents(string: decoded.hasPrefix("http") ? decoded : "https://cn.pornhub.com" + decoded) else { return nil }
        return components.queryItems?.first { $0.name == name }?.value
    }
}

@MainActor
final class PHHomeModel: ObservableObject {
    @Published var videos: [PHVideo] = []
    @Published var chips: [PHChip] = []
    @Published var loading = false
    @Published var loadingMore = false
    @Published var error: String?
    private var page = 1
    private var exhausted = false
    private let client = PHClient()

    func loadIfNeeded() async {
        guard videos.isEmpty, !loading else { return }
        await reload()
    }

    func reload() async {
        loading = true
        error = nil
        page = 1
        exhausted = false
        do {
            let home = try await client.home()
            videos = home.videos
            chips = home.chips
            page = 1
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func loadMore() async {
        guard !loadingMore, !exhausted, !videos.isEmpty else { return }
        loadingMore = true
        let next = page + 1
        do {
            let result = try await client.listing(path: "/video", page: next)
            let existing = Set(videos.map(\.vkey))
            let fresh = result.videos.filter { !existing.contains($0.vkey) }
            if fresh.isEmpty { exhausted = true }
            else {
                videos.append(contentsOf: fresh)
                page = next
            }
        } catch {
            self.error = error.localizedDescription
        }
        loadingMore = false
    }
}

struct PHMenuView: View {
    @Binding var orientation: PHOrientation
    let onSelect: (PHRoute) -> Void
    let close: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PHOrientation.allCases) { item in
                        Button {
                            orientation = item
                            onSelect(.listing(title: item.title, path: item.path == "/" ? "/video" : item.path))
                        } label: {
                            Label(item.title, systemImage: item.systemImage)
                        }
                        .foregroundStyle(item == orientation ? PHTheme.orange : .white)
                    }
                } header: {
                    Text("取向")
                }
                Section {
                    ForEach(PHParser.menuDestinations(), id: \.path) { item in
                        Button {
                            onSelect(route(for: item))
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PHTheme.background)
            .navigationTitle("菜单")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭", action: close)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func route(for item: (title: String, path: String, icon: String)) -> PHRoute {
        switch item.path {
        case "/categories": return .categoryGrid
        case "/pornstars": return .performerGrid(title: "色情明星", path: "/pornstars")
        case "/gifs": return .gifs
        case "/albums": return .albums
        case "/playlists": return .playlists
        case "/shorties": return .shorties
        default: return .listing(title: item.title, path: item.path)
        }
    }
}
