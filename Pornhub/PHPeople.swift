import SwiftUI

struct PHCategoryGrid: View {
    @StateObject private var model = PHCategoryModel()
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            if let message = model.error, model.items.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            if model.loading { PHLoading() }
        }
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
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
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            if model.loading { PHLoading() }
        }
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
                        Text(model.profile?.name.isEmpty == false ? model.profile!.name : name)
                            .font(.system(size: 22, weight: .bold))
                        if let subscribers = model.profile?.subscribers, !subscribers.isEmpty {
                            Text("\(subscribers) 订阅者").foregroundStyle(PHTheme.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                if let about = model.profile?.about, !about.isEmpty {
                    Text(about).font(.system(size: 14)).foregroundStyle(PHTheme.secondary).padding(.horizontal, 16)
                }
                if let message = model.error, (model.profile?.videos.isEmpty ?? true) {
                    PHErrorBanner(message: message) { Task { await model.load() } }
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
                if model.loading { PHLoading() }
            }
            .padding(.top, 12)
        }
        .background(PHTheme.background)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

@MainActor
final class PHProfileModel: ObservableObject {
    @Published var profile: PHProfile?
    @Published var loading = false
    @Published var error: String?
    private let href: String
    private let client = PHClient()
    init(href: String) { self.href = href }
    func load() async {
        guard profile == nil, !loading else { return }
        loading = true
        do { profile = try await client.profile(href: href) } catch { self.error = error.localizedDescription }
        loading = false
    }
}
