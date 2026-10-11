import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import KSPlayer

struct PHPlayer: View {
    let qualities: [PHQuality]
    var videoID: String = ""

    var body: some View {
        PHPlayerHost(qualities: qualities, videoID: videoID)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .background(Color.black)
    }
}

/// One UIKit owner, one IOSVideoPlayerView. Fullscreen reparents that same view,
/// as in KSPlayer's IOSVideoPlayerView.updateUI(isFullScreen:), not a second
/// KSVideoPlayer representable sharing a Coordinator (whose dismantle resets it).
private struct PHPlayerHost: UIViewControllerRepresentable {
    let qualities: [PHQuality]
    let videoID: String

    func makeUIViewController(context: Context) -> PHPlaybackController {
        PHPlaybackController()
    }

    func updateUIViewController(_ controller: PHPlaybackController, context: Context) {
        controller.configure(qualities: qualities, videoID: videoID)
    }

    static func dismantleUIViewController(_ controller: PHPlaybackController, coordinator: ()) {
        controller.dispose()
    }
}

private final class PHPlaybackController: UIViewController {
    private let player = PHNativePlayerView(frame: .zero)
    private var qualities: [PHQuality] = []
    private var selection = PHQualitySelection()
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

    func configure(qualities input: [PHQuality], videoID: String) {
        loadViewIfNeeded()
        let qualities = PHQualityPolicy.ranked(input)
        let sameVideo = selection.videoID == videoID
        guard !disposed, self.qualities != qualities || !sameVideo else { return }
        self.qualities = qualities
        let preferred = selection.update(qualities, videoID: videoID)
        player.qualitySelected = { [weak self] index in
            guard let self, self.qualities.indices.contains(index) else { return }
            self.selection.choose(self.qualities[index])
        }
        guard let preferred else {
            // A temporary empty metadata refresh must not destroy active playback.
            if !sameVideo {
                player.resetPlayer()
                player.playerLayer = nil
            }
            return
        }
        let definitions = qualities.map { quality in
            KSPlayerResourceDefinition(url: quality.url, definition: quality.label, options: playbackOptions())
        }
        player.replaceResource(KSPlayerResource(name: "", definitions: definitions), index: preferred, preservingPosition: sameVideo)
        player.playerLayer?.player.contentMode = .scaleAspectFit
        player.setFullscreenControls(fullscreenController != nil)
    }

    private func playbackOptions() -> KSOptions {
        let options = KSOptions()
        options.appendHeader(["Referer": "https://cn.pornhub.com/", "Origin": "https://cn.pornhub.com"])
        options.userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        options.referer = "https://cn.pornhub.com/"
        KSOptions.isAutoPlay = true
        KSOptions.canBackgroundPlay = true
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
        player.playerLayer?.player.pipController?.stopPictureInPicture()
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
private final class PHNativePlayerView: IOSVideoPlayerView, UIGestureRecognizerDelegate, AVPictureInPictureControllerDelegate {
    var fullscreenAction: ((Bool) -> Void)?
    var qualitySelected: ((Int) -> Void)?
    private let progress = PHProgressSlider(frame: .zero)
    private let systemVolume = MPVolumeView(frame: .zero)
    private let adjustmentHUD = UILabel()
    private var hudDismiss: DispatchWorkItem?
    private var adjustmentPan = PHAdjustmentPan()
    private var touchOrigin = CGPoint.zero
    private var horizontalStart: Float = 0
    private var horizontalTranslation: CGFloat = 0
    #if DEBUG
    private var fixtureVolume = UISlider()
    private var fixtureBrightness: CGFloat = 0.5
    private var fixtureOutput = false
    #endif
    private let previewLabel = UILabel()
    private var seekSession = PHSeekSession()
    private var seekTimeout: DispatchWorkItem?
    private var pendingQualitySeek: (layer: KSPlayerLayer, time: Double, resume: Bool)?
    private let orange = UIColor(red: 1, green: 0.58, blue: 0, alpha: 1)

    override var isMaskShow: Bool {
        didSet {
            // Upstream's private auto-hide timer must not hide a held thumb.
            if seekSession.blocksProgress && !isMaskShow { isMaskShow = true }
        }
    }

    override func customizeUIComponents() {
        super.customizeUIComponents()
        configureProgress()
        configureTransport()
        // Official KSPlayer 2.3.4 inserts this into navigationBar (UIStackView).
        // Remove its arranged layout before pinning the SAME target/action button.
        navigationBar.removeArrangedSubview(backButton)
        backButton.removeFromSuperview()
        addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            backButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4)
        ])
        backButton.accessibilityIdentifier = "player.back"
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        backButton.layer.cornerRadius = 12
        // Reject touches in control bars before the player's recognizers begin.
        [panGesture, tapGesture, doubleTapGesture, longPressGesture].forEach { $0.delegate = self }
        // Quality must not compete with time/rate/subtitle buttons for toolbar
        // width. Reuse the official UIMenu button in a bounded safe-area slot.
        let quality = toolBar.definitionButton
        toolBar.removeArrangedSubview(quality)
        quality.removeFromSuperview()
        addSubview(quality)
        quality.translatesAutoresizingMaskIntoConstraints = false
        quality.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        quality.layer.cornerRadius = 12
        quality.layer.borderWidth = 1
        quality.layer.borderColor = orange.withAlphaComponent(0.5).cgColor
        quality.tintColor = orange
        quality.setTitleColor(.white, for: .normal)
        quality.setImage(UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)), for: .normal)
        quality.semanticContentAttribute = .forceRightToLeft
        quality.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        quality.titleLabel?.lineBreakMode = .byTruncatingTail
        quality.accessibilityLabel = "画质"
        NSLayoutConstraint.activate([
            quality.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4),
            quality.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            quality.widthAnchor.constraint(equalToConstant: 132),
            quality.heightAnchor.constraint(equalToConstant: 44)
        ])
        let pip = toolBar.pipButton
        toolBar.removeArrangedSubview(pip)
        pip.removeFromSuperview()
        pip.removeTarget(nil, action: nil, for: .allEvents)
        pip.addTarget(self, action: #selector(togglePictureInPicture), for: .touchUpInside)
        pip.accessibilityIdentifier = "player.pip"
        pip.accessibilityLabel = "画中画"
        pip.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        pip.layer.cornerRadius = 12
        addSubview(pip)
        pip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pip.trailingAnchor.constraint(equalTo: quality.leadingAnchor, constant: -10),
            pip.topAnchor.constraint(equalTo: quality.topAnchor),
            pip.widthAnchor.constraint(equalToConstant: 44),
            pip.heightAnchor.constraint(equalToConstant: 44)
        ])
        // One recognizer, one target. Upstream locks using velocity and ignores
        // cancelled/failed; do not allow its vertical output to run alongside ours.
        panGesture.removeTarget(nil, action: nil)
        panGesture.addTarget(self, action: #selector(handleAdjustmentPan(_:)))
        panGesture.maximumNumberOfTouches = 1
        systemVolume.frame = CGRect(x: -120, y: 0, width: 100, height: 44)
        systemVolume.showsRouteButton = false
        systemVolume.showsVolumeSlider = true
        systemVolume.alpha = 1
        systemVolume.isUserInteractionEnabled = false
        systemVolume.accessibilityElementsHidden = true
        // Mounted in this player's scene/window before any input, not created
        // lazily on the first swipe. Never hidden/zero-sized/alpha-near-zero.
        addSubview(systemVolume)
        #if DEBUG
        fixtureOutput = ProcessInfo.processInfo.arguments.contains("-PHGestureFixture")
        fixtureVolume.value = 0.5
        fixtureVolume.addTarget(self, action: #selector(fixtureVolumeChanged(_:)), for: .valueChanged)
        #endif
        adjustmentHUD.textAlignment = .center
        adjustmentHUD.font = .systemFont(ofSize: 16, weight: .semibold)
        adjustmentHUD.textColor = .white
        adjustmentHUD.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        adjustmentHUD.layer.cornerRadius = 14
        adjustmentHUD.clipsToBounds = true
        adjustmentHUD.isUserInteractionEnabled = false
        adjustmentHUD.accessibilityIdentifier = "player.adjustmentHUD"
        adjustmentHUD.isHidden = true
        addSubview(adjustmentHUD)
        adjustmentHUD.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            adjustmentHUD.centerXAnchor.constraint(equalTo: centerXAnchor),
            adjustmentHUD.centerYAnchor.constraint(equalTo: centerYAnchor),
            adjustmentHUD.widthAnchor.constraint(equalToConstant: 250),
            adjustmentHUD.heightAnchor.constraint(equalToConstant: 52)
        ])
        setFullscreenControls(false)
    }

    @objc private func togglePictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let layer = playerLayer, let pip = layer.player.pipController else {
            showHUD("此设备或当前视频不支持画中画")
            return
        }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else if pip.isPictureInPicturePossible {
            // Use public AVKit directly. KSPlayer's isPipActive=true helper
            // invokes UIApplication suspend; do not use that non-public path.
            pip.delegate = self
            pip.startPictureInPicture()
        } else {
            showHUD("视频就绪后可开启画中画")
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        toolBar.pipButton.isSelected = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        toolBar.pipButton.isSelected = false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        toolBar.pipButton.isSelected = false
        showHUD("画中画启动失败，请稍后重试")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // The owner remains in its original inline/landscape hierarchy; unlike
        // upstream's pop/suspend helper, no navigation reconstruction is needed.
        isMaskShow = true
        completionHandler(window != nil)
    }

    private func showHUD(_ text: String) {
        hudDismiss?.cancel()
        adjustmentHUD.text = text
        adjustmentHUD.isHidden = false
        bringSubviewToFront(adjustmentHUD)
        let work = DispatchWorkItem { [weak self] in self?.adjustmentHUD.isHidden = true }
        hudDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private var publicVolumeSlider: UISlider? {
        #if DEBUG
        if fixtureOutput { return fixtureVolume }
        #endif
        guard systemVolume.window != nil else { return nil }
        systemVolume.layoutIfNeeded()
        // Public UIKit types/events, but MPVolumeView's internal hierarchy is
        // NOT a documented Apple volume-setting API; fail safely if it changes.
        return systemVolume.subviews.compactMap { $0 as? UISlider }.first
    }

    private var currentBrightness: CGFloat {
        #if DEBUG
        if fixtureOutput { return fixtureBrightness }
        #endif
        return (window?.screen ?? UIScreen.main).brightness
    }

    private func writeAdjustment(_ value: CGFloat) {
        if adjustmentPan.side == .volume {
            guard let slider = publicVolumeSlider, slider.isEnabled else {
                showHUD("当前音频路由不可调，请使用设备音量按键")
                return
            }
            slider.setValue(Float(value), animated: false)
            slider.sendActions(for: .valueChanged)
        } else {
            #if DEBUG
            if fixtureOutput { fixtureBrightness = value }
            else { (window?.screen ?? UIScreen.main).brightness = value }
            #else
            (window?.screen ?? UIScreen.main).brightness = value
            #endif
        }
        showHUD("\(adjustmentPan.side == .volume ? "音量" : "亮度") · \(Int(value * 100))%")
        #if DEBUG
        if fixtureOutput {
            adjustmentHUD.accessibilityValue = "brightness=\(fixtureBrightness);volume=\(fixtureVolume.value);events=\(fixtureEvents)"
        }
        #endif
    }

    #if DEBUG
    private var fixtureEvents = 0
    @objc private func fixtureVolumeChanged(_ sender: UISlider) { fixtureEvents += 1 }
    #endif

    override func didMoveToWindow() {
        super.didMoveToWindow()
        systemVolume.layoutIfNeeded()
        if window == nil { finishAdjustmentPan(cancelled: true) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if adjustmentPan.active && adjustmentPan.size != bounds.size {
            finishAdjustmentPan(cancelled: true)
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGesture else { return true }
        // UIKit's one-shot shouldBegin must not reject a slowly starting swipe
        // merely because its current translation has not crossed our deadzone.
        return !isLock && !replayButton.isSelected && !seekSession.blocksProgress && pendingQualitySeek == nil
    }

    @objc private func handleAdjustmentPan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            adjustmentPan.begin(origin: touchOrigin, size: bounds.size)
            processAdjustmentPan(pan)
        case .changed:
            processAdjustmentPan(pan)
        case .ended:
            processAdjustmentPan(pan)
            finishAdjustmentPan(cancelled: false)
        case .cancelled, .failed:
            finishAdjustmentPan(cancelled: true)
        default: break
        }
    }

    private func processAdjustmentPan(_ pan: UIPanGestureRecognizer) {
        guard adjustmentPan.active else { return }
        guard adjustmentPan.size == bounds.size, pendingQualitySeek == nil, !isLock,
              !seekSession.blocksProgress || adjustmentPan.axis == .horizontal else {
            finishAdjustmentPan(cancelled: true); return
        }
        let translation = pan.translation(in: self)
        let initial: CGFloat
        if adjustmentPan.side == .volume {
            #if DEBUG
            initial = fixtureOutput ? CGFloat(fixtureVolume.value) : CGFloat(AVAudioSession.sharedInstance().outputVolume)
            #else
            initial = CGFloat(AVAudioSession.sharedInstance().outputVolume)
            #endif
        } else { initial = currentBrightness }
        if adjustmentPan.lock(translation: translation, initial: initial) {
            if adjustmentPan.axis == .horizontal {
                guard KSOptions.enablePlaytimeGestures, progress.isEnabled,
                      seekSession.begin(value: Double(progress.value), duration: totalTime) else {
                    adjustmentPan.end(); return
                }
                horizontalStart = progress.value
                horizontalTranslation = translation.x
                seekTimeout?.cancel()
                isMaskShow = true
                showPreview()
            } else {
                guard landscapeButton.isSelected else { adjustmentPan.end(); return }
                writeAdjustment(adjustmentPan.value)
            }
        }
        if adjustmentPan.axis == .vertical,
           let value = adjustmentPan.update(translation: translation, size: bounds.size) {
            writeAdjustment(value)
        } else if adjustmentPan.axis == .horizontal {
            let value = Double(horizontalStart) + Double((translation.x - horizontalTranslation) / max(1, bounds.width)) * totalTime
            seekSession.move(value: value, duration: totalTime)
            showPreview()
        }
    }

    private func finishAdjustmentPan(cancelled: Bool) {
        let horizontal = adjustmentPan.active && adjustmentPan.axis == .horizontal
        adjustmentPan.end() // clear before callbacks/recognizer enable changes
        if horizontal {
            if cancelled { progressCancelled() } else { progressEnded() }
        }
        // Brightness/volume commit continuously; cancellation never rolls back
        // a system value and never commits a horizontal seek.
    }

    private func configureProgress() {
        // KSSlider is a public, non-open class with a let toolbar property and
        // internal delegate. Hide its input; retain it as upstream's time model.
        toolBar.timeSlider.isHidden = true
        toolBar.timeSlider.isUserInteractionEnabled = false
        bottomMaskView.addSubview(progress)
        bottomMaskView.addSubview(previewLabel)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.minimumTrackTintColor = orange
        progress.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
        progress.thumbTintColor = .white
        progress.isEnabled = false
        progress.accessibilityLabel = "播放进度"
        progress.addTarget(self, action: #selector(progressBegan), for: .touchDown)
        progress.addTarget(self, action: #selector(progressChanged), for: .valueChanged)
        progress.addTarget(self, action: #selector(progressEnded), for: [.touchUpInside, .touchUpOutside])
        progress.addTarget(self, action: #selector(progressCancelled), for: .touchCancel)
        progress.accessibilityChange = { [weak self] value in
            guard let self else { return }
            self.progressBegan()
            self.seekSession.move(value: Double(value), duration: self.totalTime)
            self.showPreview()
            self.progressEnded()
        }
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        previewLabel.textColor = .white
        previewLabel.textAlignment = .center
        previewLabel.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        previewLabel.layer.cornerRadius = 8
        previewLabel.clipsToBounds = true
        previewLabel.isHidden = true
        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: bottomMaskView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            progress.trailingAnchor.constraint(equalTo: bottomMaskView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            progress.bottomAnchor.constraint(equalTo: toolBar.topAnchor),
            progress.heightAnchor.constraint(equalToConstant: 44),
            previewLabel.bottomAnchor.constraint(equalTo: progress.topAnchor, constant: 2),
            previewLabel.centerXAnchor.constraint(equalTo: progress.centerXAnchor),
            previewLabel.widthAnchor.constraint(equalToConstant: 152),
            previewLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func configureTransport() {
        topMaskView.isHidden = false
        topMaskView.gradientLayer.colors = [UIColor.black.withAlphaComponent(0.78).cgColor, UIColor.clear.cgColor]
        bottomMaskView.gradientLayer.colors = [UIColor.black.withAlphaComponent(0.92).cgColor, UIColor.clear.cgColor]
        bottomMaskView.gradientLayer.locations = [0, 1]
        toolBar.timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        toolBar.timeLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        toolBar.timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        toolBar.spacing = 8
        toolBar.setCustomSpacing(8, after: toolBar.timeLabel)
        for control in [toolBar.playButton, backButton, landscapeButton] {
            // Replace, rather than conflict with upstream's 25/30pt widths.
            control.constraints.filter { $0.firstAttribute == .width && $0.secondItem == nil }.forEach { $0.isActive = false }
            control.widthAnchor.constraint(equalToConstant: 44).isActive = true
            control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            control.tintColor = .white
        }
        toolBar.playButton.tintColor = orange
        toolBar.playButton.accessibilityLabel = "播放或暂停"
        backButton.accessibilityLabel = "返回竖屏"
        let symbol = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        [toolBar.playButton, backButton, landscapeButton].compactMap { $0 as? UIButton }.forEach {
            $0.setPreferredSymbolConfiguration(symbol, forImageIn: .normal)
        }
        // Keep the empty resource title from expanding into the quality slot.
        titleLabel.isHidden = true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touched = touch.view else { return true }
        if touched.isDescendant(of: bottomMaskView) || touched.isDescendant(of: topMaskView) { return false }
        var ancestor: UIView? = touched
        while let view = ancestor {
            if view is UIControl { return false }
            ancestor = view.superview
        }
        if gestureRecognizer === panGesture {
            touchOrigin = touch.location(in: self)
        }
        return !seekSession.blocksProgress && pendingQualitySeek == nil
    }

    override func judgePanGesture() {
        super.judgePanGesture()
        // Brightness/route volume work while paused or buffering in landscape.
        if landscapeButton.isSelected && !replayButton.isSelected { panGesture.isEnabled = true }
        if seekSession.blocksProgress || pendingQualitySeek != nil { panGesture.isEnabled = false }
    }

    @objc private func progressBegan() {
        guard let layer = playerLayer, layer.player.isReadyToPlay, layer.player.seekable,
              seekSession.begin(value: Double(progress.value), duration: totalTime) else { return }
        seekTimeout?.cancel()
        panGesture.isEnabled = false
        isMaskShow = true
        showPreview()
    }

    @objc private func progressChanged() {
        seekSession.move(value: Double(progress.value), duration: totalTime)
        showPreview()
    }

    private func showPreview() {
        guard let value = seekSession.preview else { return }
        toolBar.currentTime = value
        progress.value = Float(value)
        previewLabel.text = "\(timeText(value)) / \(timeText(totalTime))"
        previewLabel.isHidden = false
        progress.accessibilityValue = previewLabel.text
    }

    @objc private func progressEnded() {
        guard let layer = playerLayer, let request = seekSession.commit() else { return }
        // One seek on release, not for every valueChanged. Paused stays paused.
        let resume = toolBar.playButton.isSelected
        let finish: (Bool) -> Void = { [weak self, weak layer] success in
            DispatchQueue.main.async {
                guard let self, self.playerLayer === layer,
                      self.seekSession.finish(generation: request.generation) else { return }
                self.seekTimeout?.cancel()
                self.previewLabel.isHidden = true
                if success { self.delegate?.playerController(seek: request.target) }
                self.syncProgress()
                self.judgePanGesture()
                self.isMaskShow = true
            }
        }
        // A stalled engine must not permanently lock progress updates. This is
        // recovery only; it never schedules a second/delayed seek.
        let timeout = DispatchWorkItem { finish(false) }
        seekTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
        layer.seek(time: request.target, autoPlay: resume, completion: finish)
    }

    @objc private func progressCancelled() {
        seekTimeout?.cancel()
        seekSession.cancel()
        previewLabel.isHidden = true
        syncProgress()
        judgePanGesture()
        isMaskShow = true
    }

    private func timeText(_ time: Double) -> String {
        let seconds = Int(time.isFinite ? max(0, time) : 0)
        if seconds >= 3600 { return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func syncProgress() {
        guard !seekSession.blocksProgress else { return }
        let duration = totalTime
        progress.isEnabled = duration.isFinite && duration > 0 && toolBar.isSeekable && (playerLayer?.player.isReadyToPlay == true)
        progress.maximumValue = progress.isEnabled ? Float(duration) : 1
        let value = PHSeekSession.bounded(playerLayer?.player.currentPlaybackTime ?? 0, duration: duration) ?? 0
        progress.value = Float(value)
        toolBar.currentTime = value
        progress.accessibilityValue = "\(timeText(value)) / \(timeText(duration))"
    }

    override func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        guard !seekSession.blocksProgress else { return }
        super.player(layer: layer, currentTime: currentTime, totalTime: totalTime)
        syncProgress()
    }

    override func resetPlayer() {
        seekTimeout?.cancel()
        seekSession.cancel()
        previewLabel.isHidden = true
        super.resetPlayer()
        progress.value = 0
        progress.isEnabled = false
    }

    override func set(resource: KSPlayerResource, definitionIndex: Int = 0, isSetUrl: Bool = true) {
        guard !resource.definitions.isEmpty else { return }
        super.set(resource: resource, definitionIndex: max(0, min(definitionIndex, resource.definitions.count - 1)), isSetUrl: isSetUrl)
        refreshQualityMenu()
    }

    private func refreshQualityMenu() {
        let button = toolBar.definitionButton
        guard let resource, resource.definitions.indices.contains(currentDefinition) else {
            button.menu = nil
            button.isEnabled = false
            return
        }
        // KSPlayer 2.3.4 builds this only at readyToPlay. Build immediately too:
        // an unavailable source must not prevent choosing another source.
        let actions = resource.definitions.enumerated().map { index, definition in
            UIAction(title: definition.definition, state: index == currentDefinition ? .on : .off) { [weak self, weak resource] _ in
                guard let self, let resource, self.resource === resource else { return }
                self.change(definitionIndex: index)
            }
        }
        button.menu = UIMenu(title: "画质", options: .singleSelection, children: actions)
        button.showsMenuAsPrimaryAction = true
        button.isEnabled = actions.count > 1
        button.isHidden = false
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PHInteractionFixtures") {
            button.accessibilityValue = playerLayer?.url.lastPathComponent
        }
        #endif
        button.setTitle("画质 · " + resource.definitions[currentDefinition].definition, for: .normal)
        button.accessibilityIdentifier = "player.quality"
        // The root-level button stays above the full-size controller overlay,
        // including after reparenting / layer replacement and mask animations.
        bringSubviewToFront(button)
    }

    override func change(definitionIndex: Int) {
        guard let resource, resource.definitions.indices.contains(definitionIndex),
              definitionIndex != currentDefinition else { return }
        qualitySelected?(definitionIndex)
        replaceResource(resource, index: definitionIndex, preservingPosition: true)
    }

    func replaceResource(_ resource: KSPlayerResource, index definitionIndex: Int, preservingPosition: Bool) {
        let resume = preservingPosition ? toolBar.playButton.isSelected : true
        let time = preservingPosition ? (playerLayer?.player.currentPlaybackTime ?? 0) : 0
        progressCancelled()
        // IOSVideoPlayerView.change awaits thumbnailImageAtCurrentTime BEFORE
        // switching URL. A stuck decoder/network can strand that Task forever.
        // Use the public set(resource:) path (same view/owner), no thumbnail gate.
        pendingQualitySeek = nil
        set(resource: resource, definitionIndex: definitionIndex)
        playerLayer?.player.contentMode = .scaleAspectFit
        if let layer = playerLayer {
            pendingQualitySeek = (layer, time.isFinite ? max(0, time) : 0, resume)
            if !resume { pause() }
            restoreQualityPositionIfReady(layer)
        }
        setFullscreenControls(landscapeButton.isSelected)
    }

    private func restoreQualityPositionIfReady(_ layer: KSPlayerLayer) {
        guard let pending = pendingQualitySeek, pending.layer === layer,
              playerLayer === layer, layer.player.isReadyToPlay, layer.player.seekable else { return }
        pendingQualitySeek = nil
        layer.seek(time: pending.time, autoPlay: pending.resume) { _ in }
        if !pending.resume { pause() }
    }

    override func updateUI(isFullScreen: Bool) {
        progressCancelled()
        fullscreenAction?(isFullScreen)
    }

    func setFullscreenControls(_ fullscreen: Bool) {
        if landscapeButton.isSelected != fullscreen { finishAdjustmentPan(cancelled: true) }
        #if DEBUG
        // Unplayable URL fixture tests recognizer/HUD/output events, not playback.
        if fixtureOutput { pendingQualitySeek = nil }
        #endif
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
        toolBar.pipButton.isHidden = false
        isMaskShow = true
        refreshQualityMenu()
        judgePanGesture()
    }

    override func player(layer: KSPlayerLayer, state: KSPlayerState) {
        super.player(layer: layer, state: state)
        layer.player.contentMode = .scaleAspectFit
        if state == .readyToPlay { restoreQualityPositionIfReady(layer) }
        if state == .error || state == .playedToTheEnd {
            seekTimeout?.cancel()
            seekSession.cancel()
            previewLabel.isHidden = true
        }
        syncProgress()
        setFullscreenControls(landscapeButton.isSelected)
    }
}

/// UISlider's single tracking path replaces KSSlider's competing tap/pan paths.
/// The 44pt view is the hit target; the drawn track/thumb stay deliberately small.
private final class PHProgressSlider: UISlider {
    var accessibilityChange: ((Float) -> Void)?
    private var thumbOffset: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setThumbImage(Self.thumb(diameter: 18), for: .normal)
        setThumbImage(Self.thumb(diameter: 24), for: .highlighted)
        isContinuous = true
        accessibilityTraits.insert(.adjustable)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func thumb(diameter: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: diameter + 4, height: diameter + 4)).image { _ in
            UIColor.black.withAlphaComponent(0.25).setFill()
            UIBezierPath(ovalIn: CGRect(x: 1, y: 2, width: diameter + 2, height: diameter + 2)).fill()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 1, width: diameter, height: diameter)).fill()
        }
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: 11, y: bounds.midY - 2, width: max(1, bounds.width - 22), height: 4)
    }

    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var thumb = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        let range = maximumValue - minimumValue
        let fraction = range > 0 ? CGFloat((value - minimumValue) / range) : 0
        thumb.origin.x = rect.minX + min(max(fraction, 0), 1) * rect.width - thumb.width / 2
        return thumb
    }

    private func updateValue(at point: CGPoint) {
        let track = trackRect(forBounds: bounds)
        let fraction = min(max((point.x - thumbOffset - track.minX) / track.width, 0), 1)
        value = minimumValue + Float(fraction) * (maximumValue - minimumValue)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isEnabled else { return false }
        let point = touch.location(in: self)
        let track = trackRect(forBounds: bounds)
        let center = thumbRect(forBounds: bounds, trackRect: track, value: value).midX
        thumbOffset = abs(point.x - center) <= 22 ? point.x - center : 0
        isHighlighted = true
        updateValue(at: point)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updateValue(at: touch.location(in: self))
        sendActions(for: .valueChanged)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let touch { updateValue(at: touch.location(in: self)) }
        isHighlighted = false
        super.endTracking(touch, with: event)
    }

    override func cancelTracking(with event: UIEvent?) {
        isHighlighted = false
        super.cancelTracking(with: event)
    }

    override func accessibilityIncrement() { adjustAccessibility(by: 1) }
    override func accessibilityDecrement() { adjustAccessibility(by: -1) }
    private func adjustAccessibility(by direction: Float) {
        guard isEnabled else { return }
        value = min(max(value + direction * max(5, maximumValue * 0.01), minimumValue), maximumValue)
        accessibilityChange?(value)
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
