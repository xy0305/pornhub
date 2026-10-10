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
 'search button': 'Button { showSearch = true } label:' in h,
 'subscription label': '.accessibilityLabel("订阅")' in h,
 'no fake ellipsis': 'ellipsis' not in read('PHComponents.swift'),
 'adaptive grids': p.count('GridItem(.adaptive(') == 2,
 'narrow details': 'ViewThatFits(in: .horizontal)' in b,
 'one player': b.count('PHPlayer(qualities:') == 1,
 'secure field': 'SecureField("密码", text: $password)' in m,
 'account dismiss': 'Button("完成") { dismiss() }' in m,
 'dark appearance': '.preferredColorScheme(.dark)' in read('PornhubApp.swift'),
 'no web renderer': not any(re.search(r'\b(WKWebView|UIWebView|SFSafariViewController|import WebKit)\b', x.read_text()) for x in (r/'Pornhub').glob('*.swift')),
}
for n,d in {'PHPlayer.swift':'c2da129f444e937ba2ce41067edce69a09e848c6590d94813aeb3d8b2b6fa42e','PHSeekSession.swift':'ff05c215c1ae556d820c09f0642e582c3186337612a83ef76c94fb6b407a286c'}.items():
 checks['build5 unchanged '+n]=hashlib.sha256((r/'Pornhub'/n).read_bytes()).hexdigest()==d
for n,ok in checks.items(): print(('PASS: ' if ok else 'FAIL: ')+n)
assert all(checks.values())
print(f'{len(checks)} static UI contracts passed; device acceptance remains required.')
