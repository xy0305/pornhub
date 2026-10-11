import SwiftUI

@MainActor
final class PHSubscriptionsModel: ObservableObject {
    @Published var videos: [PHVideo] = []
    @Published var loading = false
    @Published var error: String?
    @Published var needsLogin = false
    @Published var loaded = false
    @Published var nextHref: String?
    @Published private(set) var sessionRevision: UUID?
    private weak var library: PHLibrary?
    func bind(_ library: PHLibrary) { self.library = library }
    private let client = PHClient()
    private var requestTask: Task<Void, Never>?
    private var generation = 0
    private var failedHref = "/subscriptions"

    func cancel() {
        generation += 1
        requestTask?.cancel()
        requestTask = nil
        videos = []; nextHref = nil; loaded = false; loading = false
        error = nil; needsLogin = false
    }

    func reload() async {
        cancel()
        sessionRevision = library?.sessionRevision
        await fetch(href: "/subscriptions", append: false)
    }

    func more() async {
        guard !loading, let nextHref else { return }
        await fetch(href: nextHref, append: true)
    }

    func retry() async {
        guard !loading else { return }
        await fetch(href: failedHref, append: failedHref != "/subscriptions")
    }

    private func fetch(href: String, append: Bool) async {
        requestTask?.cancel()
        generation += 1
        let token = generation
        let owner = sessionRevision
        failedHref = href
        loading = true; error = nil; needsLogin = false
        let client = client
        let task = Task { [weak self] in
            do {
                let result = try await client.subscriptions(href: href)
                try Task.checkCancellation()
                guard let self, self.generation == token, self.library?.sessionRevision == owner else { return }
                if append {
                    let keys = Set(self.videos.map(\.id))
                    self.videos += result.videos.filter { !keys.contains($0.id) }
                } else { self.videos = result.videos }
                self.nextHref = result.nextHref
                self.loaded = true
            } catch {
                guard let self, !Task.isCancelled, self.generation == token, self.library?.sessionRevision == owner else { return }
                if case PHSubscriptionError.signIn = error {
                    self.videos = []; self.nextHref = nil; self.loaded = false
                    self.needsLogin = true
                }
                self.error = error.localizedDescription
            }
            guard let self, self.generation == token, self.library?.sessionRevision == owner else { return }
            self.loading = false
        }
        requestTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: { task.cancel() }
    }
}

struct PHServerSubscriptionsView: View {
    @EnvironmentObject private var library: PHLibrary
    @StateObject private var model = PHSubscriptionsModel()
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Text("官网订阅更新").font(.headline)
                Text("来自 /subscriptions 的订阅视频，不是本地作者缓存")
                    .font(.caption).foregroundStyle(PHTheme.secondary)
                if let error = model.error {
                    PHErrorBanner(message: error) { Task { await model.retry() } }
                        .accessibilityIdentifier("subscriptions.error")
                }
                if model.needsLogin {
                    Text("请从账号中心登录；登录后返回此页或下拉刷新。")
                        .accessibilityIdentifier("subscriptions.login")
                }
                if model.loaded && model.videos.isEmpty {
                    PHEmptyState(title: "暂无订阅更新", icon: "person.2", message: "官网已返回空的视频列表")
                }
                ForEach(model.sessionRevision == library.sessionRevision ? model.videos : []) { video in
                    Button {
                        library.remember(video)
                        path.append(PHRoute.video(video))
                    } label: { PHVideoCard(video: video) }
                        .buttonStyle(.plain)
                }
                if model.nextHref != nil {
                    Button("加载更多") { Task { await model.more() } }
                        .accessibilityIdentifier("subscriptions.more")
                        .disabled(model.loading)
                }
                if model.loading { PHLoading() }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-PHSubscriptionsFixture") {
                    HStack {
                        Button("切换夹具账号") {
                            Task {
                                await PHSubscriptionsFixture.shared.setAccount("B")
                                library.signIn(PHAccount(email: "fixture-b", displayName: "Fixture B", provider: "fixture"))
                            }
                        }.accessibilityIdentifier("subscriptions.fixture.account")
                        Button("退出夹具账号") {
                            Task {
                                await PHSubscriptionsFixture.shared.setAccount("anonymous")
                                library.signOut()
                            }
                        }
                            .accessibilityIdentifier("subscriptions.fixture.logout")
                    }
                }
                #endif
            }.padding(.top, 16)
        }
        .frame(maxWidth: 1200)
        .frame(maxWidth: .infinity)
        .background(PHTheme.background)
        .navigationTitle("订阅")
        .toolbar { Button("刷新") { Task { await model.reload() } }.accessibilityIdentifier("subscriptions.refresh") }
        .task(id: library.sessionRevision) { model.bind(library); await model.reload() }
        .refreshable { await model.reload() }
        .onDisappear { model.cancel() }
    }
}
