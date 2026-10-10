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
 'build 4': b.count('CURRENT_PROJECT_VERSION = 4;') == 2,
 'audited dependency': 'kind = exactVersion;' in b and 'version = 2.3.4;' in b,
}
for name, ok in checks.items(): print(('PASS: ' if ok else 'FAIL: ') + name)
assert all(checks.values())
print(f'{len(checks)} architecture guards passed; UI requires device verification.')
