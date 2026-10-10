import SwiftUI
import Combine
import AVFoundation
import KSPlayer

struct PHPlayer: View {
    let qualities: [PHQuality]
    @State private var selectedID: String
    @State private var fullscreen = false
    @State private var showQualities = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var seeking = false
    @State private var videoSize: CGSize = .zero
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    init(qualities: [PHQuality]) {
        self.qualities = qualities
        let preferred = qualities.first { $0.isDefault } ?? qualities.first
        _selectedID = State(initialValue: preferred?.id ?? "")
    }

    var body: some View {
        stage(fullscreen: false)
            .fullScreenCover(isPresented: $fullscreen) {
                PHLandscapeHost {
                    stage(fullscreen: true)
                }
                .ignoresSafeArea()
                .onAppear { PHOrientationLock.set(.landscapeRight) }
                .onDisappear { PHOrientationLock.set(.portrait) }
            }
            .onAppear { activateAudio() }
            .onDisappear { coordinator.playerLayer?.pause() }
    }

    private func stage(fullscreen: Bool) -> some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let quality = selected {
                    KSVideoPlayer(coordinator: coordinator, url: quality.url, options: playbackOptions)
                        .frame(width: fittedSize(in: proxy.size).width, height: fittedSize(in: proxy.size).height)
                        .onAppear { applyAspectFit() }
                } else {
                    ContentUnavailableView("没有可播放的画质", systemImage: "play.slash")
                }
                controls(fullscreen: fullscreen, safe: proxy.safeAreaInsets)
                if fullscreen { progressBar(safe: proxy.safeAreaInsets) }
                if showQualities { qualityPanel(fullscreen: fullscreen, safe: proxy.safeAreaInsets) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(fullscreen ? nil : 16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: fullscreen ? .infinity : nil)
        .background(Color.black)
        .clipped()
    }

    /// Letterbox inside the stage. Never stretch a portrait frame to fill landscape.
    private func fittedSize(in container: CGSize) -> CGSize {
        let source = videoSize.width > 1 && videoSize.height > 1 ? videoSize : CGSize(width: 16, height: 9)
        let scale = min(container.width / source.width, container.height / source.height)
        guard scale.isFinite, scale > 0 else { return container }
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    private func controls(fullscreen: Bool, safe: EdgeInsets) -> some View {
        VStack {
            HStack(spacing: 8) {
                if fullscreen {
                    controlButton("chevron.left", label: "退出横屏") {
                        showQualities = false
                        self.fullscreen = false
                    }
                }
                Spacer(minLength: 8)
                qualityButton
                controlButton(fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", label: fullscreen ? "退出横屏" : "横屏播放") {
                    showQualities = false
                    self.fullscreen.toggle()
                }
            }
            .padding(.leading, max(safe.leading, fullscreen ? 20 : 10))
            .padding(.trailing, max(safe.trailing, fullscreen ? 20 : 10))
            .padding(.top, max(safe.top, fullscreen ? 12 : 6))
            Spacer()
        }
        .foregroundStyle(.white)
    }

    private var qualityButton: some View {
        Button {
            showQualities.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                Text(selected?.label ?? "画质")
                    .font(.system(size: 15, weight: .bold))
                Image(systemName: showQualities ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(.black.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("画质")
    }

    private func progressBar(safe: EdgeInsets) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Text(PHParser.duration(Int(currentTime)))
                Slider(
                    value: Binding(get: { currentTime }, set: { currentTime = $0 }),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        seeking = editing
                        if !editing {
                            coordinator.playerLayer?.seek(time: currentTime, autoPlay: true, completion: { _ in })
                        }
                    }
                )
                .tint(.white)
                Text(PHParser.duration(Int(duration)))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.35))
            .padding(.bottom, max(safe.bottom, 8))
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard fullscreen, !seeking else { return }
            refreshPlayback()
        }
    }

    private func qualityPanel(fullscreen: Bool, safe: EdgeInsets) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture { showQualities = false }
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(qualities) { quality in
                    Button {
                        switchQuality(quality)
                        showQualities = false
                    } label: {
                        HStack {
                            Text(quality.label)
                            if quality.id == selectedID {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minWidth: 132, alignment: .leading)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                        .background(quality.id == selectedID ? Color.orange : Color.black.opacity(0.9), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, max(safe.top, fullscreen ? 12 : 6) + 52)
            .padding(.trailing, max(safe.trailing, 16) + 56)
        }
        .foregroundStyle(.white)
    }

    private func controlButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.72), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var selected: PHQuality? { qualities.first { $0.id == selectedID } ?? qualities.first }

    private var playbackOptions: KSOptions {
        let options = KSOptions()
        options.appendHeader([
            "Referer": "https://cn.pornhub.com/",
            "Origin": "https://cn.pornhub.com"
        ])
        options.userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        options.referer = "https://cn.pornhub.com/"
        KSOptions.isAutoPlay = true
        return options
    }

    private func refreshPlayback() {
        currentTime = coordinator.playerLayer?.player.currentPlaybackTime ?? currentTime
        let total = coordinator.playerLayer?.player.duration ?? 0
        if total > 0 { duration = total }
        let size = coordinator.playerLayer?.player.naturalSize ?? .zero
        if size.width > 1, size.height > 1, size != videoSize {
            videoSize = size
        }
        applyAspectFit()
    }

    private func applyAspectFit() {
        coordinator.isScaleAspectFill = false
        coordinator.playerLayer?.player.contentMode = .scaleAspectFit
    }

    private func switchQuality(_ quality: PHQuality) {
        let time = coordinator.playerLayer?.player.currentPlaybackTime ?? currentTime
        selectedID = quality.id
        videoSize = .zero
        coordinator.playerLayer?.set(url: quality.url, options: playbackOptions)
        applyAspectFit()
        guard time > 1 else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            coordinator.playerLayer?.seek(time: time, autoPlay: true, completion: { _ in })
            applyAspectFit()
        }
    }

    private func activateAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

struct PHLandscapeHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    func makeUIViewController(context: Context) -> PHLandscapeController<Content> { PHLandscapeController(rootView: content) }
    func updateUIViewController(_ controller: PHLandscapeController<Content>, context: Context) { controller.rootView = content }
}

final class PHLandscapeController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PHOrientationLock.set(.landscapeRight)
    }
}

enum PHOrientationLock {
    static func set(_ mask: UIInterfaceOrientationMask) {
        let resolved: UIInterfaceOrientationMask = UIDevice.current.userInterfaceIdiom == .pad && mask == .portrait ? .all : mask
        KSOptions.supportedInterfaceOrientations = resolved
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: resolved)) { _ in }
        scene?.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}
