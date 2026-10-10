import SwiftUI

struct PHGIFGrid: View {
    @StateObject private var model = PHGIFModel()
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            if let message = model.error, model.items.isEmpty {
                PHErrorBanner(message: message) { Task { await model.reload() } }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(model.items) { item in
                    Button { path.append(PHRoute.gif(item)) } label: {
                        ZStack(alignment: .bottomLeading) {
                            PHRemoteImage(url: item.still, ratio: 1)
                            Text(item.title).font(.system(size: 12, weight: .semibold)).lineLimit(1).padding(8)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .onAppear { if item.id == model.items.last?.id { Task { await model.loadMore() } } }
                }
            }
            .padding(10)
            if model.loading { PHLoading() }
        }
        .background(PHTheme.background)
        .navigationTitle("动图")
        .task { await model.reload() }
    }
}

@MainActor
final class PHGIFModel: ObservableObject {
    @Published var items: [PHGIF] = []
    @Published var loading = false
    @Published var error: String?
    private var page = 1
    private var exhausted = false
    private let client = PHClient()
    func reload() async {
        guard items.isEmpty else { return }
        loading = true
        do { items = try await client.gifs(page: 1); page = 1 } catch { self.error = error.localizedDescription }
        loading = false
    }
    func loadMore() async {
        guard !loading, !exhausted else { return }
        loading = true
        do {
            let next = try await client.gifs(page: page + 1)
            let existing = Set(items.map(\.id))
            let fresh = next.filter { !existing.contains($0.id) }
            if fresh.isEmpty { exhausted = true } else { items.append(contentsOf: fresh); page += 1 }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHGIFPlayer: View {
    let gif: PHGIF
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let url = URL(string: gif.animated.isEmpty ? gif.still : gif.animated) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        default: PHRemoteImage(url: gif.still, ratio: 1)
                        }
                    }
                }
                Text(gif.title).font(.system(size: 18, weight: .bold)).padding(.horizontal, 16)
            }
        }
        .background(PHTheme.background)
        .navigationTitle("动图")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PHAlbumGrid: View {
    @StateObject private var model = PHAlbumModel()
    @Binding var path: NavigationPath
    var body: some View {
        ScrollView {
            if let message = model.error, model.items.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(model.items) { item in
                    Button { path.append(PHRoute.album(item)) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            PHRemoteImage(url: item.thumb, ratio: 1).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(item.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                            if !item.photoCount.isEmpty {
                                Text("\(item.photoCount) 照片").font(.system(size: 12)).foregroundStyle(PHTheme.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            if model.loading { PHLoading() }
        }
        .background(PHTheme.background)
        .navigationTitle("照片")
        .task { await model.load() }
    }
}

@MainActor
final class PHAlbumModel: ObservableObject {
    @Published var items: [PHAlbum] = []
    @Published var loading = false
    @Published var error: String?
    private let client = PHClient()
    func load() async {
        guard items.isEmpty, !loading else { return }
        loading = true
        do { items = try await client.albums(page: 1) } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHAlbumView: View {
    let album: PHAlbum
    @StateObject private var model: PHAlbumDetailModel
    @Binding var path: NavigationPath
    init(album: PHAlbum, path: Binding<NavigationPath>) {
        self.album = album
        self._path = path
        _model = StateObject(wrappedValue: PHAlbumDetailModel(album: album))
    }
    var body: some View {
        ScrollView {
            if let message = model.error, model.photos.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(model.photos) { photo in
                    Button { path.append(PHRoute.photo(photo)) } label: {
                        PHRemoteImage(url: photo.thumb, ratio: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            if model.loading { PHLoading() }
        }
        .background(PHTheme.background)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

@MainActor
final class PHAlbumDetailModel: ObservableObject {
    @Published var photos: [PHPhoto] = []
    @Published var loading = false
    @Published var error: String?
    private let album: PHAlbum
    private let client = PHClient()
    init(album: PHAlbum) { self.album = album }
    func load() async {
        guard photos.isEmpty, !loading else { return }
        loading = true
        do { photos = try await client.photos(albumHref: album.href) } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHPhotoView: View {
    let photo: PHPhoto
    @State private var image = ""
    @State private var error: String?
    private let client = PHClient()
    var body: some View {
        ScrollView {
            if image.isEmpty {
                PHRemoteImage(url: photo.thumb, ratio: 1).padding()
            } else {
                PHRemoteImage(url: image, ratio: 3.0 / 4.0).padding(.horizontal, 8)
            }
            if let error { Text(error).foregroundStyle(PHTheme.secondary).padding() }
        }
        .background(PHTheme.background)
        .navigationTitle("照片")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if image.isEmpty {
                image = (try? await client.photoImage(href: photo.href)) ?? photo.thumb
            }
        }
    }
}

struct PHPlaylistGrid: View {
    @StateObject private var model = PHPlaylistModel()
    @Binding var path: NavigationPath
    var body: some View {
        ScrollView {
            if let message = model.error, model.items.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVStack(spacing: 14) {
                ForEach(model.items) { item in
                    Button { path.append(PHRoute.playlist(item)) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            PHRemoteImage(url: item.thumb).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(item.title).font(.system(size: 16, weight: .bold)).lineLimit(2)
                            if !item.models.isEmpty {
                                Text(item.models).font(.system(size: 13)).foregroundStyle(PHTheme.secondary).lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            if model.loading { PHLoading() }
        }
        .background(PHTheme.background)
        .navigationTitle("片单")
        .task { await model.load() }
    }
}

@MainActor
final class PHPlaylistModel: ObservableObject {
    @Published var items: [PHPlaylist] = []
    @Published var loading = false
    @Published var error: String?
    private let client = PHClient()
    func load() async {
        guard items.isEmpty, !loading else { return }
        loading = true
        do { items = try await client.playlists(page: 1) } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHPlaylistView: View {
    let playlist: PHPlaylist
    @StateObject private var model: PHPlaylistDetailModel
    @EnvironmentObject private var library: PHLibrary
    @Binding var path: NavigationPath
    init(playlist: PHPlaylist, path: Binding<NavigationPath>) {
        self.playlist = playlist
        self._path = path
        _model = StateObject(wrappedValue: PHPlaylistDetailModel(playlist: playlist))
    }
    var body: some View {
        ScrollView {
            if let message = model.error, model.videos.isEmpty {
                PHErrorBanner(message: message) { Task { await model.load() } }
            }
            LazyVStack(spacing: 12) {
                ForEach(model.videos) { video in
                    Button {
                        library.remember(video)
                        path.append(PHRoute.video(video))
                    } label: { PHVideoCard(video: video) }
                    .buttonStyle(.plain)
                }
            }
            if model.loading { PHLoading() }
        }
        .background(PHTheme.background)
        .navigationTitle(playlist.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

@MainActor
final class PHPlaylistDetailModel: ObservableObject {
    @Published var videos: [PHVideo] = []
    @Published var loading = false
    @Published var error: String?
    private let playlist: PHPlaylist
    private let client = PHClient()
    init(playlist: PHPlaylist) { self.playlist = playlist }
    func load() async {
        guard videos.isEmpty, !loading else { return }
        loading = true
        do { videos = try await client.playlistVideos(href: playlist.href) } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PHAccountSheet: View {
    @EnvironmentObject private var library: PHLibrary
    @State private var email = ""
    @State private var password = ""
    @State private var googleToken = ""
    @State private var busy = false
    @State private var message: String?
    private let client = PHClient()

    var body: some View {
        NavigationStack {
            Form {
                if let account = library.account {
                    Section("已登录") {
                        Text(account.email)
                        Button("退出", role: .destructive) { library.signOut() }
                    }
                } else {
                    Section("邮箱登录") {
                        TextField("邮箱", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        SecureField("密码", text: $password)
                    }
                    if let message {
                        Section { Text(message).foregroundStyle(.red) }
                    }
                    Section {
                        Button(busy ? "正在登录" : "登录") { Task { await login() } }
                            .disabled(busy || email.isEmpty || password.isEmpty)
                    }
                }
                Section("说明") {
                    Text("登录走官网 /front/authenticate。站点若要求验证码，会提示失败，不会假装已登录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("账号")
            .scrollContentBackground(.hidden)
            .background(PHTheme.background)
        }
        .preferredColorScheme(.dark)
    }

    private func login() async {
        busy = true
        message = nil
        do {
            let account = try await client.authenticate(email: email, password: password)
            library.signIn(account)
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }

    private func google() async {
        busy = true
        message = nil
        do {
            let account = try await client.authenticateGoogle(accessToken: googleToken)
            library.signIn(account)
            googleToken = ""
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }
}

struct PHSubscriptionList: View {
    @EnvironmentObject private var library: PHLibrary
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            if library.subscriptions.isEmpty {
                ContentUnavailableView("还没有订阅", systemImage: "person.badge.plus", description: Text("在作者页订阅后会同步到这里"))
                    .padding(.top, 80)
            }
            LazyVStack(spacing: 12) {
                ForEach(library.subscriptions) { item in
                    Button {
                        path.append(PHRoute.profile(href: item.href, name: item.name))
                    } label: {
                        HStack(spacing: 12) {
                            PHRemoteImage(url: item.avatar, ratio: 1)
                                .frame(width: 54, height: 54)
                                .clipShape(Circle())
                            Text(item.name).font(.system(size: 17, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(PHTheme.muted)
                        }
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
        }
        .background(PHTheme.background)
        .navigationTitle("订阅")
    }
}

struct PHSavedList: View {
    let title: String
    let videos: [PHVideo]
    @Binding var path: NavigationPath
    @EnvironmentObject private var library: PHLibrary
    var body: some View {
        ScrollView {
            if videos.isEmpty {
                ContentUnavailableView("还没有内容", systemImage: "heart", description: Text("播放或点赞后会出现在这里"))
                    .padding(.top, 80)
            }
            LazyVStack(spacing: 12) {
                ForEach(videos) { video in
                    Button {
                        library.remember(video)
                        path.append(PHRoute.video(video))
                    } label: { PHVideoCard(video: video) }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(PHTheme.background)
        .navigationTitle(title)
    }
}
