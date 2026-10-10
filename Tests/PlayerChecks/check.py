#!/usr/bin/env python3
"""Source architecture guards; not UI/device acceptance tests."""
from pathlib import Path
import plistlib
import re
r = Path(__file__).resolve().parents[2]
p = (r / 'Pornhub/PHPlayer.swift').read_text()
a = (r / 'Pornhub/PornhubApp.swift').read_text()
b = (r / 'Pornhub.xcodeproj/project.pbxproj').read_text()
code = re.sub(r'//[^\n]*', '', p)
checks = {
 'one native player': p.count('PHNativePlayerView(frame:') == 1,
 'no shared coordinator': 'KSVideoPlayer' not in code,
 'no duplicate stage': 'fullScreenCover' not in p and 'GeometryReader' not in p,
 'no double fitting': 'naturalSize' not in p and 'fittedSize' not in p,
 'no delayed seek': 'Task.sleep' not in p,
 'no disappearance pause': '.onDisappear' not in p,
 'deactivate before reparent': p.index('NSLayoutConstraint.deactivate(playerConstraints)') < p.index('player.removeFromSuperview()') < p.index('container.addSubview(player)'),
 'safe area all edges': all(f'player.{e}Anchor.constraint(equalTo: safe.{e}Anchor)' in p for e in ['top','leading','trailing','bottom']),
 'quality inside safe area': 'quality.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12)' in p and 'quality.widthAnchor.constraint(equalToConstant: 132)' in p,
 'native definitions': 'KSPlayerResourceDefinition' in p and 'player.set(resource:' in p,
 'aspect fit only': '.scaleAspectFit' in p and '.scaleAspectFill' not in p,
 'scene specific rotation': 'window?.windowScene' in p and 'connectedScenes' not in code,
 'transition guard': 'guard !disposed, !transitioning' in p,
 'explicit teardown': 'controller.dispose()' in p and 'player.playerLayer = nil' in p,
 'orientation delegate': '@UIApplicationDelegateAdaptor(PHAppDelegate.self)' in a and 'supportedInterfaceOrientationsFor' in a,
 'controller status bar': plistlib.loads((r/'Pornhub/Info.plist').read_bytes())['UIViewControllerBasedStatusBarAppearance'] is True,
 'build 7': b.count('CURRENT_PROJECT_VERSION = 7;') == 2,
 '44pt progress input': 'progress.heightAnchor.constraint(equalToConstant: 44)' in p,
 'single tracking path': 'class PHProgressSlider: UISlider' in p and 'override func beginTracking' in p and 'override func continueTracking' in p,
 'stock slider input disabled': 'toolBar.timeSlider.isUserInteractionEnabled = false' in p and 'toolBar.timeSlider.isHidden = true' in p,
 'gesture control exclusion': 'view is UIControl' in p and 'touched.isDescendant(of: bottomMaskView)' in p and '[panGesture, tapGesture, doubleTapGesture, longPressGesture].forEach { $0.delegate = self }' in p,
 'timer blocked while dragging and seeking': 'guard !seekSession.blocksProgress else { return }' in p,
 'all release paths': 'for: [.touchUpInside, .touchUpOutside]' in p and 'for: .touchCancel' in p,
 'seek uses completion and playback intent': 'layer.seek(time: request.target, autoPlay: resume, completion: finish)' in p,
 'stale completion rejected': 'self.playerLayer === layer' in p and 'self.seekSession.finish(generation: request.generation)' in p,
 'seek timeout recovery': 'DispatchWorkItem { finish(false) }' in p,
 'preview and accessible seeking': 'previewLabel.text =' in p and 'override func accessibilityIncrement()' in p,
 'transport touch size': 'control.widthAnchor.constraint(equalToConstant: 44)' in p and 'control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)' in p,
 'gradient surfaces': 'bottomMaskView.gradientLayer.colors' in p and 'topMaskView.gradientLayer.colors' in p,
 'audited dependency': 'kind = exactVersion;' in b and 'version = 2.3.4;' in b,
}
for name, ok in checks.items(): print(('PASS: ' if ok else 'FAIL: ') + name)
assert all(checks.values())
print(f'{len(checks)} architecture guards passed; UI requires device verification.')
