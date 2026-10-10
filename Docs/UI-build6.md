# Native UI build 6 — Liquid Glass

Version 1.0.0 (6), baseline `90b53c7` (build5). Deployment target remains iOS 17.0. No dependency upgrade.

## Design and implementation

Black/orange branding and website information hierarchy remain: brand/navigation, search, popular heading, recommendation chips, media thumbnail, author/verification/views, title; detail retains player, title/metadata, like/author actions, tags and related videos.

- `PHTheme.swift`: shared 16pt gutter, 20pt content radius, 44pt control target. `phCard` is opaque elevated charcoal with a subtle stroke, not glass. `phGlass` uses public `.glassEffect(.regular, in:)` / `.regular.interactive()`. `PHGlassGroup` uses `GlassEffectContainer(spacing: 8)`. Native actions use `.buttonStyle(.glass)` / `.glassProminent`.
- All three API sites are gated with `#available(iOS 26.0, *)`. iOS17–25 uses `.regularMaterial` for custom surfaces and bordered native buttons. Reduce Transparency explicitly substitutes opaque custom surfaces and bordered buttons, bypassing effect groups and glass styles. Dark appearance stays app-wide.
- Home: safe-area-pinned two-row navigation with glass menu/account buttons, brand and an actual full-width search capsule plus accessible subscription button. Redundant menu shortcut removed (same menu routes remain); the former unlabeled subscription tap gesture is now a labeled 44pt Button. Popular heading and chips preserve their roles.
- Shared video cards: 16pt image corners within 20pt opaque cards, 16pt outside gutters, 14pt inner padding, semantic headline titles and quieter author/views. Removed inert ellipsis decoration (it had no action); no functional action removed. Changes propagate to home, search/listings, related videos, profile, playlists, saved/history.
- Browse: minimum-44pt sort pills and selected accessibility trait. Category adaptive grid (minimum145pt), strong bottom gradient labels; performer adaptive grid (minimum100pt), circular avatars/rank badges within opaque cards. Wider screens naturally gain columns.
- Detail: readable opaque title/metadata panel, separate glass like/author actions with horizontal-to-vertical `ViewThatFits` fallback, accessible like/cancel wording, disabled empty author link; chips and related section retained. The player is outside the information card and all glass modifiers.
- Profile: opaque avatar/stat card, native glass subscribe action with in-flight disabled state, unchanged actual network subscription/error semantics.
- Account: native Form identity header, SecureField, native glass prominent login action and explicit Done. Subscription list gets padded opaque identity rows; empty state retained. Existing media thumbnail corner styling is unified.

Content images, card backgrounds, scrolling chip/filter rows are deliberately not all glass. No decorative looping animation or gesture overlay was introduced. Some legacy secondary text still uses fixed font sizes: this is not a claim of complete Dynamic Type certification.

## Native rendering audit

Application sources were scanned for WebKit/WKWebView/UIWebView/SFSafariViewController, SVG and JavaScript evaluation. There are **zero app WebView wrappers, zero embedded site pages, zero SVG WebView fallbacks, and zero web-based login/authorization views**. Every app content screen is SwiftUI, except the single UIKit KSPlayer host. Images use native AsyncImage. `AppleWebKit` and `Safari` occur only in network User-Agent strings, not as renderers.

`PHClient` retains URLSession HTML/JSON retrieval and `PHParser` parsing as data sources; this is not website embedding. Login remains native email/password POST `/front/authenticate`; CAPTCHA requirements remain a reported failure rather than embedded web login. Existing unused Google token API/helper remains unchanged and does not embed a web page. No account login, subscription write or other real website write was performed during this upgrade. Audit scope is checked-in app source; KSPlayer 2.3.4 dependency implementation was not rewritten.

## Player preservation

`PHPlayer.swift` and `PHSeekSession.swift` are byte-for-byte unchanged from build5. Frozen SHA256 contracts:

- PHPlayer.swift: `c2da129f444e937ba2ce41067edce69a09e848c6590d94813aeb3d8b2b6fa42e`
- PHSeekSession.swift: `ff05c215c1ae556d820c09f0642e582c3186337612a83ef76c94fb6b407a286c`

Single UIViewControllerRepresentable owner, one native player, seek completion/generation/paused intent, safe-area reparenting and landscape quality UIMenu remain as documented in Player-build5.md. No second player or fullscreen SwiftUI overlay added.

## Official API references consulted online

- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/tutorials/data/documentation/swiftui/applying-liquid-glass-to-custom-views.json
- https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass

Apple's official article includes compilable snippets for `.glassEffect(.regular.tint(.orange).interactive())`, rounded rectangles, `GlassEffectContainer(spacing:)` and `.buttonStyle(.glass)`. Exact project usage is validated by full Xcode26 iphoneos Release compilation in GitHub Actions, not by assuming availability from screenshots.

## Regression and acceptance boundary

Run `python3 Tests/PlayerChecks/ui_check.py` (22 static contracts), `python3 Tests/PlayerChecks/check.py` (30 guards), and `python3 Tests/ParserRegression/check.py Tests/Fixtures`. CI also compiles/runs actual production seek state-machine regression and Swift parser fixtures, then performs unsigned iphoneos Release build and IPA packaging. UI source guards include availability, transparency fallbacks, native rendering, adaptive grids, safe-area header, accessible shortcuts, and byte-level build5 player preservation. These are not screenshot tests or UIKit interaction tests.

No local Xcode or device is available in the working Linux environment. Required device acceptance: iOS17 fallback vs iOS26 glass; Reduce Transparency enabled/disabled; 320/375pt widths, iPad and notched landscape; long translated titles/author names and larger text; keyboard/search/clear/submit; navigation sheets and dismissal; pagination/refresh/error; account validation and real login only with user consent; subscribe/error only with user consent; all build5 seek/rotation/quality tests from Player-build5.md. No claim of pixel-perfect screenshots, performance profiling, VoiceOver walkthrough or real-device touch verification is made.

Artifact: CI produces `Pornhub-unsigned-1.0.0-6.ipa`. Unsigned output requires the user's own signing workflow before installation; packaging alone is not device installation.
