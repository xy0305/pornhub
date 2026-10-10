import SwiftUI

struct PHSearchSheet: View {
    @State private var query = ""
    @State private var searches: [PHSuggestion] = []
    @State private var performers: [PHSuggestion] = []
    @State private var failed = false
    let onSearch: (String) -> Void
    let onOpen: (PHRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    private let client = PHClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("搜索视频、明星、分类", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .padding(14)
                        .background(PHTheme.card, in: RoundedRectangle(cornerRadius: 12))
                        .onSubmit { submit() }
                    Button("搜索") { submit() }
                        .buttonStyle(.borderedProminent)
                        .tint(PHTheme.orange)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !searches.isEmpty {
                        Text("热门搜索")
                            .font(.system(size: 22, weight: .bold))
                        ForEach(searches) { item in
                            Button(item.title) {
                                query = item.title
                                submit()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                    if !performers.isEmpty {
                        Text("热门色情明星和模特")
                            .font(.system(size: 22, weight: .bold))
                        ForEach(performers) { item in
                            Button {
                                onOpen(.profile(href: item.href, name: item.title))
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    PHRemoteImage(url: item.avatar, ratio: 1)
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                    Text(item.title)
                                        .font(.system(size: 18, weight: .semibold))
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if failed && searches.isEmpty {
                        Text("热门搜索暂时没有加载出来，仍可以直接输入搜索。")
                            .font(.footnote)
                            .foregroundStyle(PHTheme.secondary)
                    }
                }
                .padding(16)
            }
            .background(PHTheme.background)
            .navigationTitle("搜索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task { await load() }
        }
        .preferredColorScheme(.dark)
    }

    private func submit() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSearch(text)
        dismiss()
    }

    private func load() async {
        guard searches.isEmpty, performers.isEmpty else { return }
        do {
            let result = try await client.suggestions()
            searches = result.searches
            performers = result.performers
        } catch {
            failed = true
        }
    }
}

struct PHListingView: View {
    let title: String
    let path: String
    var query: String?
    @StateObject private var model: PHListingModel
    @EnvironmentObject private var library: PHLibrary
    @Binding var pathStack: NavigationPath

    init(title: String, path: String, query: String? = nil, pathStack: Binding<NavigationPath>) {
        self.title = title
        self.path = path
        self.query = query
        self._pathStack = pathStack
        _model = StateObject(wrappedValue: PHListingModel(path: path, query: query))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                sortBar
                if let message = model.error, model.videos.isEmpty {
                    PHErrorBanner(message: message) { Task { await model.reload() } }
                }
                ForEach(model.videos) { video in
                    Button {
                        library.remember(video)
                        pathStack.append(PHRoute.video(video))
                    } label: {
                        PHVideoCard(video: video)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if video.id == model.videos.last?.id { Task { await model.loadMore() } }
                    }
                }
                if model.loading { PHLoading() }
            }
        }
        .background(PHTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadIfNeeded() }
    }

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PHSort.allCases) { sort in
                    Button(sort.title) {
                        Task { await model.setSort(sort) }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(model.sort == sort ? PHTheme.orange : PHTheme.card, in: Capsule())
                    .foregroundStyle(model.sort == sort ? .black : .white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}

@MainActor
final class PHListingModel: ObservableObject {
    @Published var videos: [PHVideo] = []
    @Published var loading = false
    @Published var error: String?
    @Published var sort: PHSort = .featured
    private var page = 1
    private var exhausted = false
    private let path: String
    private let query: String?
    private let client = PHClient()

    init(path: String, query: String?) {
        self.path = path
        self.query = query
    }

    func loadIfNeeded() async {
        guard videos.isEmpty else { return }
        await reload()
    }

    func setSort(_ sort: PHSort) async {
        self.sort = sort
        await reload()
    }

    func reload() async {
        loading = true
        error = nil
        page = 1
        exhausted = false
        do {
            let result = try await fetch(page: 1)
            videos = result.videos
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func loadMore() async {
        guard !loading, !exhausted else { return }
        loading = true
        let next = page + 1
        do {
            let result = try await fetch(page: next)
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
        loading = false
    }

    private func fetch(page: Int) async throws -> PHPage {
        if let query, !query.isEmpty {
            return try await client.search(query: query, page: page, sort: sort)
        }
        return try await client.listing(path: path, page: page, sort: sort)
    }
}

struct PHVideoDetailView: View {
    let video: PHVideo
    @EnvironmentObject private var library: PHLibrary
    @StateObject private var model: PHDetailModel
    @Binding var path: NavigationPath

    init(video: PHVideo, path: Binding<NavigationPath>) {
        self.video = video
        self._path = path
        _model = StateObject(wrappedValue: PHDetailModel(video: video))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.detail?.qualities.isEmpty == false {
                    PHPlayer(qualities: model.detail?.qualities ?? [])
                } else if model.loading {
                    PHRemoteImage(url: video.thumb)
                        .overlay { ProgressView().tint(.white) }
                } else {
                    PHRemoteImage(url: video.thumb)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.detail?.video.title ?? video.title)
                        .font(.system(size: 20, weight: .bold))
                    HStack(spacing: 12) {
                        meta(model.detail?.viewsText ?? video.views, "eye")
                        if let rating = model.detail?.ratingText, !rating.isEmpty {
                            meta(rating, "hand.thumbsup")
                        }
                        if let seconds = model.detail?.durationSeconds, seconds > 0 {
                            meta(PHParser.duration(seconds), "clock")
                        }
                        Spacer()
                        Button {
                            library.toggleLike(model.detail?.video ?? video)
                        } label: {
                            Image(systemName: library.isLiked(model.detail?.video ?? video) ? "heart.fill" : "heart")
                                .foregroundStyle(PHTheme.orange)
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PHTheme.secondary)
                    authorButton
                    if let tags = model.detail?.tags, !tags.isEmpty {
                        PHChipRow(chips: tags) { chip in
                            path.append(PHRoute.listing(title: chip.title, path: chip.href))
                        }
                    }
                    if let message = model.error {
                        PHErrorBanner(message: message) { Task { await model.load() } }
                    }
                }
                .padding(.horizontal, 14)
                if !model.related.isEmpty {
                    Text("相关视频")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 14)
                    ForEach(model.related) { item in
                        Button {
                            library.remember(item)
                            path.append(PHRoute.video(item))
                        } label: {
                            PHVideoCard(video: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(PHTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private var authorButton: some View {
        let current = model.detail?.video ?? video
        return Button {
            guard !current.authorURL.isEmpty else { return }
            path.append(PHRoute.profile(href: current.authorURL, name: current.author))
        } label: {
            HStack(spacing: 8) {
                Text(current.author.isEmpty ? "作者" : current.author)
                    .font(.system(size: 16, weight: .semibold))
                if current.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 1))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(PHTheme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private func meta(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
    }
}

@MainActor
final class PHDetailModel: ObservableObject {
    @Published var detail: PHVideoDetail?
    @Published var related: [PHVideo] = []
    @Published var loading = false
    @Published var error: String?
    private let video: PHVideo
    private let client = PHClient()

    init(video: PHVideo) { self.video = video }

    func load() async {
        guard detail == nil, !loading else { return }
        loading = true
        do {
            let detail = try await client.detail(video)
            self.detail = detail
            related = try await client.related(url: detail.relatedURL, videoID: detail.video.videoID)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
