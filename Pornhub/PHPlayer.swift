import SwiftUI
import AVFoundation
import KSPlayer

struct PHPlayer: View {
    let qualities: [PHQuality]

    var body: some View {
        PHPlayerHost(qualities: qualities)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .background(Color.black)
    }
}

/// One UIKit owner, one IOSVideoPlayerView. Fullscreen reparents that same view,
/// as in KSPlayer's IOSVideoPlayerView.updateUI(isFullScreen:), not a second
/// KSVideoPlayer representable sharing a Coordinator (whose dismantle resets it).
private struct PHPlayerHost: UIViewControllerRepresentable {
    let qualities: [PHQuality]

    func makeUIViewController(context: Context) -> PHPlaybackController {
        PHPlaybackController()
    }

    func updateUIViewController(_ controller: PHPlaybackController, context: Context) {
        controller.configure(qualities: qualities)
    }

    static func dismantleUIViewController(_ controller: PHPlaybackController, coordinator: ()) {
        controller.dispose()
    }
}

private final class PHPlaybackController: UIViewController {
    private let player = PHNativePlayerView(frame: .zero)
    private var qualities: [PHQuality] = []
    private var playerConstraints: [NSLayoutConstraint] = []
    private var fullscreenController: PHLandscapeController?
    private var transitioning = false
    private var disposed = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        attachPlayer(to: view)
        player.fullscreenAction = { [weak self] fullscreen in
            self?.setFullscreen(fullscreen)
        }
        player.backBlock = { [weak self] in self?.setFullscreen(false) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func configure(qualities: [PHQuality]) {
        loadViewIfNeeded()
        guard !disposed, self.qualities != qualities else { return }
        self.qualities = qualities
        guard !qualities.isEmpty else {
            player.resetPlayer()
            player.playerLayer = nil
            return
        }
        let definitions = qualities.map { quality in
            KSPlayerResourceDefinition(url: quality.url, definition: quality.label, options: playbackOptions())
        }
        let preferred = qualities.firstIndex(where: { $0.isDefault }) ?? 0
        player.set(resource: KSPlayerResource(name: "", definitions: definitions), definitionIndex: preferred)
        player.playerLayer?.player.contentMode = .scaleAspectFit
        player.setFullscreenControls(fullscreenController != nil)
    }

    private func playbackOptions() -> KSOptions {
        let options = KSOptions()
        options.appendHeader(["Referer": "https://cn.pornhub.com/", "Origin": "https://cn.pornhub.com"])
        options.userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        options.referer = "https://cn.pornhub.com/"
        KSOptions.isAutoPlay = true
        return options
    }

    private func attachPlayer(to container: UIView) {
        // Explicitly remove the old host's constraints before changing superview.
        NSLayoutConstraint.deactivate(playerConstraints)
        player.removeFromSuperview()
        container.addSubview(player)
        player.translatesAutoresizingMaskIntoConstraints = false
        let safe = container.safeAreaLayoutGuide
        playerConstraints = [
            player.topAnchor.constraint(equalTo: safe.topAnchor),
            player.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            player.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            player.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        ]
        NSLayoutConstraint.activate(playerConstraints)
        container.layoutIfNeeded()
    }

    private func setFullscreen(_ fullscreen: Bool) {
        guard !disposed, !transitioning else { return }
        if fullscreen {
            guard fullscreenController == nil, view.window != nil else { return }
            transitioning = true
            let controller = PHLandscapeController()
            controller.modalPresentationStyle = .fullScreen
            controller.modalTransitionStyle = .crossDissolve
            controller.isModalInPresentation = true
            fullscreenController = controller
            controller.loadViewIfNeeded()
            attachPlayer(to: controller.view)
            player.setFullscreenControls(true)
            KSOptions.supportedInterfaceOrientations = .landscapeRight
            present(controller, animated: true) { [weak self] in
                guard let self else { return }
                self.transitioning = false
                PHOrientationLock.set(.landscapeRight, from: controller)
                controller.view.layoutIfNeeded()
            }
        } else {
            guard let controller = fullscreenController else { return }
            transitioning = true
            PHOrientationLock.set(.portrait, from: self)
            controller.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.fullscreenController = nil
                self.transitioning = false
                guard !self.disposed else { return }
                self.attachPlayer(to: self.view)
                self.player.setFullscreenControls(false)
                PHOrientationLock.set(.portrait, from: self)
            }
        }
    }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        player.fullscreenAction = nil
        player.backBlock = nil
        player.resetPlayer()
        player.playerLayer = nil
        fullscreenController?.dismiss(animated: false)
        fullscreenController = nil
        NSLayoutConstraint.deactivate(playerConstraints)
        player.removeFromSuperview()
        PHOrientationLock.set(.portrait, from: self)
    }
}

/// Keep KSPlayer's native transport, progress and definition menu. Only replace
/// its presentation hook: the app owns a scene-aware landscape-only controller.
private final class PHNativePlayerView: IOSVideoPlayerView {
    var fullscreenAction: ((Bool) -> Void)?

    override func customizeUIComponents() {
        super.customizeUIComponents()
        // Quality must not compete with time/rate/subtitle buttons for toolbar
        // width. Reuse the official UIMenu button in a bounded safe-area slot.
        let quality = toolBar.definitionButton
        toolBar.removeArrangedSubview(quality)
        quality.removeFromSuperview()
        addSubview(quality)
        quality.translatesAutoresizingMaskIntoConstraints = false
        quality.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        quality.layer.cornerRadius = 18
        quality.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        quality.titleLabel?.lineBreakMode = .byTruncatingTail
        quality.accessibilityLabel = "画质"
        NSLayoutConstraint.activate([
            quality.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4),
            quality.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            quality.widthAnchor.constraint(equalToConstant: 132),
            quality.heightAnchor.constraint(equalToConstant: 40)
        ])
        setFullscreenControls(false)
    }

    override func updateUI(isFullScreen: Bool) {
        fullscreenAction?(isFullScreen)
    }

    func setFullscreenControls(_ fullscreen: Bool) {
        landscapeButton.isSelected = fullscreen
        landscapeButton.isHidden = false
        landscapeButton.accessibilityLabel = fullscreen ? "退出横屏" : "横屏播放"
        backButton.isHidden = !fullscreen
        lockButton.isHidden = true
        // Keep transport compact even on a 320pt inline stage. Native quality
        // remains independently visible while transport masks auto-hide.
        toolBar.playbackRateButton.isHidden = true
        toolBar.audioSwitchButton.isHidden = true
        toolBar.videoSwitchButton.isHidden = true
        toolBar.srtButton.isHidden = true
        toolBar.pipButton.isHidden = true
        isMaskShow = true
        if let resource, resource.definitions.indices.contains(currentDefinition) {
            toolBar.definitionButton.isHidden = false
            toolBar.definitionButton.setTitle("画质 · " + resource.definitions[currentDefinition].definition, for: .normal)
        }
    }

    override func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        layer.player.contentMode = .scaleAspectFit
        setFullscreenControls(landscapeButton.isSelected)
    }
}

private final class PHLandscapeController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscapeRight }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
}

enum PHOrientationLock {
    static func set(_ mask: UIInterfaceOrientationMask, from controller: UIViewController) {
        KSOptions.supportedInterfaceOrientations = mask
        controller.setNeedsUpdateOfSupportedInterfaceOrientations()
        // Never pick connectedScenes.first: that can rotate another window.
        guard let scene = controller.viewIfLoaded?.window?.windowScene else { return }
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            NSLog("Player orientation request failed: %@", error.localizedDescription)
        }
    }
}
