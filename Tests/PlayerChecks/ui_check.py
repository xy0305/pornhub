#!/usr/bin/env python3
"""Static native UI contracts, not screenshots or device interaction tests."""
from pathlib import Path
import hashlib
import re
r = Path(__file__).resolve().parents[2]
read = lambda n: (r/'Pornhub'/n).read_text()
t=read('PHTheme.swift'); h=read('PHHome.swift'); b=read('PHBrowse.swift'); p=read('PHPeople.swift'); m=read('PHMedia.swift')
checks = {
 'iOS26 gates': t.count('#available(iOS 26.0, *)') == 3,
 'public glass': 'content.glassEffect(' in t and '.regular.interactive()' in t,
 'glass container': 'GlassEffectContainer(spacing: 8)' in t,
 'glass button styles': '.buttonStyle(.glass)' in t and '.buttonStyle(.glassProminent)' in t,
 'iOS17 fallback': '.background(.regularMaterial, in: shape)' in t,
 'transparency priority': t.index('if reduceTransparency {') < t.index('content.glassEffect('),
 'opaque fallback': 'content.background(PHTheme.card, in: shape)' in t,
 'group/action accessibility': t.count('!reduceTransparency') == 2,
 'opaque content': 'background(PHTheme.elevated' in t,
 'safe-area header': '.safeAreaInset(edge: .top, spacing: 0)' in h,
 'search button': 'Button { present(.search) } label:' in h,
 'full search target': '.frame(maxWidth: .infinity, minHeight: PHLayout.controlHeight)' in h and '.contentShape(Capsule())' in h,
 'icon target': '.contentShape(Circle())' in h,
 'decoration noninteractive': t.count('.allowsHitTesting(false)') == 2,
 'single sheet owner': read('PornhubApp.swift').count('.sheet(') == 1 and '.sheet(item: $activeSheet, onDismiss: finishSheetNavigation)' in read('PornhubApp.swift'),
 'subscription label': '.accessibilityLabel("订阅")' in h,
 'no fake ellipsis': 'ellipsis' not in read('PHComponents.swift'),
 'adaptive grids': p.count('GridItem(.adaptive(') == 2,
 'narrow details': 'ViewThatFits(in: .horizontal)' in b,
 'one player': b.count('PHPlayer(qualities:') == 1,
 'secure field': 'SecureField("密码", text: $password)' in m,
 'account dismiss': 'Button("完成") { dismiss() }' in m,
 'restrained content cards': '.stroke(PHTheme.hairline' not in t[t.index('func phCard'):],
 'adaptive home videos': 'LazyVGrid(columns: PHLayout.columns' in h,
 'shared state design': 'PHEmptyState' in m and 'PHEmptyState' in read('PHSubscriptions.swift'),
 'public background configuration': 'KSOptions.canBackgroundPlay = true' in read('PHPlayer.swift'),
 'public pip readiness feedback': 'pip.isPictureInPicturePossible' in read('PHPlayer.swift') and '此设备或当前视频不支持画中画' in read('PHPlayer.swift'),
 'no private pip invocation': 'isPipActive.toggle()' not in read('PHPlayer.swift') and 'isPipActive = true' not in read('PHPlayer.swift'),
 'one pan recognizer': 'UIPanGestureRecognizer(' not in read('PHPlayer.swift'),
 'public volume events': 'slider.sendActions(for: .valueChanged)' in read('PHPlayer.swift'),
 'pan threshold and seek exclusion': '>= 6' in read('PHPlayer.swift') and 'pendingQualitySeek == nil' in read('PHPlayer.swift'),
 'dark appearance': '.preferredColorScheme(.dark)' in read('PornhubApp.swift'),
 'no web renderer': not any(re.search(r'\b(WKWebView|UIWebView|SFSafariViewController|import WebKit)\b', x.read_text()) for x in (r/'Pornhub').glob('*.swift')),
}
for n,d in {'PHPlayer.swift':'fde3d60c2caaa7f1879f5f048d5dd116b312d88d31af83688bfe04f7e26acbac','PHSeekSession.swift':'ff05c215c1ae556d820c09f0642e582c3186337612a83ef76c94fb6b407a286c'}.items():
 checks[('build9 audited player ' if n == 'PHPlayer.swift' else 'build5 unchanged seek ')+n]=hashlib.sha256((r/'Pornhub'/n).read_bytes()).hexdigest()==d
for n,ok in checks.items(): print(('PASS: ' if ok else 'FAIL: ')+n)
assert all(checks.values())
print(f'{len(checks)} static UI contracts passed; device acceptance remains required.')
