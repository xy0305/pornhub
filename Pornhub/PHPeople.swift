import SwiftUI

struct PHCategoryGrid: View {
    @StateObject private var model = PHCategoryModel()
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            if let message = model.error, model.items.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                ForEach(model.items) { item in
                    Button {
                        path.append(PHRoute.listing(title: item.title, path: item.href))
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            PHRemoteImage(url: item.thumb, ratio: 16.0 / 10.0)
                            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 16, weight: .bold))
                                if !item.count.isEmpty {
                                    Text("\(item.count) 视频").font(.system(size: 12)).foregroundStyle(PHTheme.secondary)
                                }
                            }
                            .padding(10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: PHLayout.radius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(PHLayout.gutter)
            if model.loading { PHLoading() }
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
        .background(PHTheme.background)
        .navigationTitle("分类")
        .task { await model.load() }
    }
}

@MainActor
final class PHCategoryModel: ObservableObject {
    @Published var items: [PHCategory] = []
    @Published var loading = false
    @Published var error: String?
    private let client = PHClient()
    func load() async {
        guard items.isEmpty, !loading else { return }
        loading = true
        do { items = try await client.categories() } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHPerformerGrid: View {
    let title: String
    let source: String
    @StateObject private var model: PHPerformerModel
    @Binding var path: NavigationPath

    init(title: String, source: String, path: Binding<NavigationPath>) {
        self.title = title
        self.source = source
        self._path = path
        _model = StateObject(wrappedValue: PHPerformerModel(path: source))
    }

    var body: some View {
        ScrollView {
            if let message = model.error, model.items.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], spacing: 16) {
                ForEach(model.items) { item in
                    Button {
                        path.append(PHRoute.profile(href: item.href, name: item.name))
                    } label: {
                        VStack(spacing: 6) {
                            PHRemoteImage(url: item.avatar, ratio: 1)
                                .clipShape(Circle())
                                .overlay(alignment: .topLeading) {
                                    if !item.rank.isEmpty {
                                        Text(item.rank)
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(5)
                                            .background(.black.opacity(0.7), in: Circle())
                                    }
                                }
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(PHLayout.gutter)
            if model.loading { PHLoading() }
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
        .background(PHTheme.background)
        .navigationTitle(title)
        .task { await model.load() }
    }
}

@MainActor
final class PHPerformerModel: ObservableObject {
    @Published var items: [PHPerformer] = []
    @Published var loading = false
    @Published var error: String?
    private let path: String
    private let client = PHClient()
    init(path: String) { self.path = path }
    func load() async {
        guard items.isEmpty, !loading else { return }
        loading = true
        do { items = try await client.performers(path: path) } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHProfileView: View {
    let href: String
    let name: String
    @StateObject private var model: PHProfileModel
    @EnvironmentObject private var library: PHLibrary
    @Binding var path: NavigationPath

    init(href: String, name: String, path: Binding<NavigationPath>) {
        self.href = href
        self.name = name
        self._path = path
        _model = StateObject(wrappedValue: PHProfileModel(href: href))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    PHRemoteImage(url: model.profile?.avatar ?? "", ratio: 1)
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(model.profile?.name.isEmpty == false ? model.profile!.name : name)
                                .font(.system(size: 22, weight: .bold))
                            if model.profile?.videos.first?.verified == true || model.subscribed {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color(red: 0.25, green: 0.55, blue: 1))
                            }
                        }
                        ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            if let rank = model.profile?.rank, !rank.isEmpty {
                                stat(rank, "排名")
                            }
                            if let views = model.profile?.views, !views.isEmpty {
                                stat(views, "次观看")
                            }
                            if let subscribers = model.profile?.subscribers, !subscribers.isEmpty {
                                stat(subscribers, "订阅者")
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            if let views = model.profile?.views, !views.isEmpty { stat(views, "次观看") }
                            if let subscribers = model.profile?.subscribers, !subscribers.isEmpty { stat(subscribers, "订阅者") }
                        }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(20)
                .phCard()
                .padding(.horizontal, PHLayout.gutter)
                Button {
                    Task { await model.toggleSubscription(library) }
                } label: {
                    Label(model.subscribed ? "已订阅" : "订阅", systemImage: model.subscribed ? "checkmark" : "person.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundStyle(model.subscribed ? .white : .black)
                }
                .phAction(prominent: !model.subscribed)
                .disabled(model.subscribing)
                .padding(.horizontal, 16)
                if let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(PHTheme.secondary).padding(.horizontal, 16)
                }
                if let about = model.profile?.about, !about.isEmpty {
                    Text(about).font(.system(size: 14)).foregroundStyle(PHTheme.secondary).padding(.horizontal, 16)
                }
                Text("作者视频").font(.headline).padding(.horizontal, 16)
                if !model.sorts.isEmpty || !model.sources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if !model.sources.isEmpty {
                                Menu {
                                    ForEach(model.sources) { choice in
                                        Button(choice.title) { Task { await model.select(choice) } }
                                    }
                                } label: { Image(systemName: "line.3.horizontal.decrease") .frame(width: 44, height: 44) }
                                .accessibilityLabel("视频类型筛选")
                            }
                            Button("默认") { Task { await model.select(nil) } }
                                .accessibilityIdentifier("profile.sort.default")
                            ForEach(model.sorts.filter { $0.title != "最长" }) { choice in
                                Button(choice.title) { Task { await model.select(choice) } }
                                    .accessibilityIdentifier("profile.sort.\(choice.title)")
                            }
                            if model.sorts.contains(where: { $0.title == "最长" }) {
                                Menu("更多") {
                                    ForEach(model.sorts.filter { $0.title == "最长" }) { choice in
                                        Button(choice.title) { Task { await model.select(choice) } }
                                    }
                                }
                            }
                        }
                        .buttonStyle(PHFilterButtonStyle())
                        .frame(minHeight: 44)
                        .padding(.horizontal, 16)
                    }
                    .accessibilityIdentifier("profile.filters")
                    Text("当前：\(model.selected)").font(.caption).padding(.horizontal, 16)
                } else if model.profile != nil {
                    Text("该来源未提供视频筛选").font(.caption).padding(.horizontal, 16)
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-PHProfileFixture") {
                    Text(model.requestDescription).font(.caption2).accessibilityIdentifier("profile.request")
                }
                #endif
                if let message = model.error {
                    PHErrorBanner(message: message) { Task { await model.retry() } }
                }
                ForEach(model.profile?.videos ?? []) { video in
                    Button {
                        library.remember(video)
                        path.append(PHRoute.video(video))
                    } label: {
                        PHVideoCard(video: video)
                    }
                    .buttonStyle(.plain)
                }
                if model.nextPage != nil {
                    Button("加载更多") { Task { await model.more() } }
                        .accessibilityIdentifier("profile.more")
                        .disabled(model.loading)
                }
                if model.loading { PHLoading() }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
        .background(PHTheme.background)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: library.sessionRevision) {
            await model.load(session: library.sessionRevision)
            if let profile = model.profile {
                model.subscribed = library.isSubscribed(profile) || profile.subscribed
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 14, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(PHTheme.secondary)
        }
    }
}

@MainActor
final class PHProfileModel: ObservableObject {
    @Published var profile: PHProfile?
    @Published var loading = false
    @Published var subscribing = false
    @Published var subscribed = false
    @Published var error: String?
    @Published var message: String?
    private let href: String
    private let client = PHClient()
    @Published var sorts: [PHProfileChoice] = []
    @Published var sources: [PHProfileChoice] = []
    @Published var selected = "默认"
    @Published var nextPage: Int?
    @Published var requestDescription = ""
    private var currentHref: String
    private var generation = 0
    private var accountRevision: UUID?
    init(href: String) { self.href = href; self.currentHref = href }

    func load(session: UUID) async {
        if let previous = accountRevision, previous != session {
            generation += 1
            profile = nil; subscribed = false; loading = false
            nextPage = nil; error = nil; message = nil
        }
        accountRevision = session
        await load()
    }

    func load() async {
        guard profile == nil, !loading else { return }
        await fetch(page: 1, generation: generation)
    }

    func select(_ choice: PHProfileChoice?) async {
        generation += 1
        currentHref = choice?.href ?? href
        selected = choice?.title ?? "默认"
        profile?.videos = []
        nextPage = nil
        error = nil
        await fetch(page: 1, generation: generation)
    }

    func more() async {
        guard !loading, let nextPage else { return }
        await fetch(page: nextPage, generation: generation)
    }

    func retry() async {
        guard !loading else { return }
        await fetch(page: nextPage ?? 1, generation: generation)
    }

    private func fetch(page: Int, generation token: Int) async {
        loading = true
        error = nil
        let target = currentHref
        do {
            let result = try await client.profilePage(href: target, page: page)
            guard token == generation else { return }
            var updated = result.profile
            if page > 1 {
                let old = profile?.videos ?? []
                let ids = Set(old.map(\.id))
                updated.videos = old + updated.videos.filter { !ids.contains($0.id) }
            }
            currentHref = PHProfileFilters.requestURL(href: result.requestURL.absoluteString, page: 1).absoluteString
            profile = updated
            sorts = result.sorts
            sources = result.sources
            nextPage = result.nextPage
            requestDescription = result.requestURL.absoluteString
            subscribed = updated.subscribed
        } catch {
            guard token == generation else { return }
            self.error = error.localizedDescription
        }
        loading = false
    }

    func toggleSubscription(_ library: PHLibrary) async {
        guard let profile, !subscribing else { return }
        subscribing = true
        message = nil
        let sessionRevision = library.sessionRevision
        do {
            let now = try await client.setSubscription(profile: profile, subscribe: !subscribed)
            guard sessionRevision == library.sessionRevision else { subscribing = false; return }
            subscribed = now
            library.syncSubscription(profile, subscribed: now)
            message = now ? "已同步到当前账号" : "已从当前账号取消订阅"
        } catch {
            guard sessionRevision == library.sessionRevision else { subscribing = false; return }
            message = error.localizedDescription
        }
        subscribing = false
    }
}
