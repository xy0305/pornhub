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
        ZStack {
            Color.black
            if let quality = selected {
                KSVideoPlayer(coordinator: coordinator, url: quality.url, options: playbackOptions)
            } else {
                ContentUnavailableView("没有可播放的画质", systemImage: "play.slash")
            }
            controls(fullscreen: fullscreen)
            if fullscreen { progressBar }
            if showQualities { qualityPanel }
        }
        .aspectRatio(fullscreen ? nil : 16.0 / 9.0, contentMode: .fit)
        .background(Color.black)
    }

    private func controls(fullscreen: Bool) -> some View {
        VStack {
            HStack(spacing: 4) {
                if fullscreen {
                    controlButton("chevron.left", label: "退出横屏") {
                        showQualities = false
                        self.fullscreen = false
                    }
                }
                Spacer()
                Button {
                    showQualities.toggle()
                } label: {
                    Text(selected?.label ?? "画质")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                controlButton(fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", label: fullscreen ? "退出横屏" : "横屏播放") {
                    showQualities = false
                    self.fullscreen.toggle()
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, fullscreen ? 16 : 6)
            Spacer()
        }
        .foregroundStyle(.white)
    }

    private var progressBar: some View {
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
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.35))
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard fullscreen, !seeking else { return }
            currentTime = coordinator.playerLayer?.player.currentPlaybackTime ?? currentTime
            let total = coordinator.playerLayer?.player.duration ?? 0
            if total > 0 { duration = total }
        }
    }

    private var qualityPanel: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.01)
                .contentShape(Rectangle())
                .onTapGesture { showQualities = false }
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(qualities) { quality in
                    Button {
                        switchQuality(quality)
                        showQualities = false
                    } label: {
                        Text(quality.id == selectedID ? "\(quality.label) ✓" : quality.label)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(minWidth: 92)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.black.opacity(0.78), in: Capsule())
                    }
                }
            }
            .padding(.top, 62)
            .padding(.trailing, 58)
        }
        .foregroundStyle(.white)
    }

    private func controlButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: Circle())
        }
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

    private func switchQuality(_ quality: PHQuality) {
        let time = coordinator.playerLayer?.player.currentPlaybackTime ?? currentTime
        selectedID = quality.id
        coordinator.playerLayer?.set(url: quality.url, options: playbackOptions)
        guard time > 1 else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            coordinator.playerLayer?.seek(time: time, autoPlay: true, completion: { _ in })
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
