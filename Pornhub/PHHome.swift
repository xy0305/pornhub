import SwiftUI

struct PHHomeView: View {
    @EnvironmentObject private var library: PHLibrary
    @StateObject private var model = PHHomeModel()
    @Binding var path: NavigationPath
    let present: (PHHomeSheet) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                titleRow
                searchButton
                    .padding(.horizontal, PHLayout.gutter)
                quickLinks
                PHSectionHeading(title: "热门视频", subtitle: "浏览站点热门内容", icon: "flame.fill")
                if !model.chips.isEmpty {
                    PHChipRow(chips: model.chips) { chip in
                        open(chip)
                    }
                }
                if let message = model.error, model.videos.isEmpty {
                    PHErrorBanner(message: message) { Task { await model.reload() } }
                }
                LazyVGrid(columns: PHLayout.columns, spacing: 24) {
                ForEach(model.videos) { video in
                    Button {
                        library.remember(video)
                        path.append(PHRoute.video(video))
                    } label: {
                        PHVideoCard(video: video)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.video.\(video.vkey)")
                    .onAppear {
                        if video.id == model.videos.last?.id {
                            Task { await model.loadMore() }
                        }
                    }
                }
                }
                if model.loadingMore || (model.loading && model.videos.isEmpty) {
                    PHLoading()
                }
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
        .background(PHTheme.background)
        .refreshable { await model.reload() }
        .task { await model.loadIfNeeded() }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            iconButton("line.3.horizontal", color: PHTheme.orange) { present(.menu) }
                .accessibilityLabel("浏览菜单与取向")
                .accessibilityIdentifier("home.menu")
            PHLogo().accessibilityLabel("Pornhub")
            Spacer(minLength: 0)
            PHGlassGroup {
                HStack(spacing: 0) {
                    iconButton("heart", color: .white) { path.append(PHRoute.subscriptions) }
                        .accessibilityLabel("订阅")
                    iconButton("person.crop.circle", color: .white) { present(.account) }
                        .accessibilityLabel("账号")
                        .accessibilityIdentifier("home.account")
                }
                .phGlass(radius: 24)
            }
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PHLayout.gutter)
        .padding(.vertical, 8)
        .background(PHTheme.background)
    }

    private var searchButton: some View {
        Button { present(.search) } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(PHTheme.orange)
                Text("搜索视频、明星、分类")
                    .font(.subheadline).foregroundStyle(PHTheme.secondary)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                    .foregroundStyle(PHTheme.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: PHLayout.controlHeight)
            .contentShape(Capsule())
            .phGlass(radius: 28, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.search")
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("发现 / DISCOVER")
                .font(.caption.weight(.bold)).tracking(2)
                .foregroundStyle(PHTheme.orange)
            Text("找到你的精彩")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PHTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("热门内容、喜爱的明星，从这里开始。")
                .font(.subheadline).foregroundStyle(PHTheme.secondary)
        }
        .padding(.horizontal, PHLayout.gutter)
        .padding(.top, 18)
        .accessibilityIdentifier("home.discovery")
    }

    private var quickLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { shortcutItems }
            VStack(spacing: 10) { shortcutItems }
        }
        .padding(.horizontal, PHLayout.gutter)
    }

    @ViewBuilder private var shortcutItems: some View {
        shortcut("分类", icon: "square.grid.2x2.fill", id: "categories", route: .categoryGrid)
        shortcut("明星", icon: "star.fill", id: "performers", route: .performerGrid(title: "色情明星", path: "/pornstars"))
        shortcut("观看记录", icon: "clock.arrow.circlepath", id: "history", route: .history)
    }

    private func shortcut(_ title: String, icon: String, id: String, route: PHRoute) -> some View {
        Button { path.append(route) } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold)).foregroundStyle(PHTheme.orange)
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(PHTheme.text).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .padding(14)
            .phCard(radius: 18)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.quick.\(id)")
    }

    private func iconButton(_ name: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PHInteractionFixtures") {
            videos = (1...6).map { index in
                PHVideo(vkey: "design-fixture-\(index)", videoID: "", title: "Fixture · 原生视频卡片 \(index)", thumb: "fixture://thumbnail/\(index)", preview: "", duration: "12:34", views: "24.8K", author: "Fixture Studio", authorURL: "/model/fixture/videos", verified: true)
            }
            chips = [PHChip(title: "精选", href: "/video", systemImage: "sparkles"), PHChip(title: "最新", href: "/video?o=mr", systemImage: nil)]
            return
        }
        #endif
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
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
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
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
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
