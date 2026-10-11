# Build11 — Native discovery redesign

## Baseline and scope

Fetched origin/main before editing: `eaced71` (build10); clean working tree. Only xy0305/pornhub is changed; no AVDB repository access. Reviewed build9's actual synthetic-fixture Simulator home/author screenshots under `/var/minis/shared/Pornhub/evidence/build9`, plus PHHome/Components/Theme/Browse/People/Media/Subscriptions. The former double full-width glass capsules, flat heading and repeated ungrouped video rows read as a utility screen rather than a discovery product.

## Implemented native visual direction

- A lightweight brand/navigation row replaces the full-width heavy toolbar. Glass is limited to the account/subscription control group and search/action surfaces. A scrollable editorial discovery heading uses large Dynamic Type text, warm orange eyebrow and explanatory copy, with generous but finite whitespace.
- Three **working** quick links reuse existing category, performer and local history routes. No fake recommended media, invented statistics, decorative nonfunctional controls or server requests are added by these links. Home chips still come from parsed site data; the hot video list remains the existing home response.
- Refined search capsule with native iconography and a full-width target; menu, subscription and account retain accessibility identifiers and 44pt targets. Single root sheet ownership and post-dismissal routing are unchanged.
- Shared image-first video cards now use a shallow opaque warm-neutral surface, small image inset, clear title/author/view hierarchy and an unobtrusive real duration label. No glass, color border or new gradient on production content cards. Existing DEBUG fixture image gradients are test placeholders, not online thumbnails.
- Unified editorial section headings across listings/search, category, performer, GIF, album, playlist and subscription screens. Category image labels and several formerly fixed body fonts use semantic typography. Performer portraits sit on quiet content panels, not floating glass.
- Creator identity has a separate orange eyebrow, portrait/title/stats grouping and a distinct works section. Existing source-provided statistics, actual filters, next-page control and subscription behavior are retained. Detail information uses a spacious title panel with horizontal/vertical metadata fallback; the single actual UIKit player stays outside this panel.
- Account welcome and login form follow the same warm surfaces and semantic headings. Email/password fields, real authentication protocol and dismissal behavior remain intact. Subscription section copy accurately identifies `/subscriptions` as its source.

## Compatibility and preservation

Real public iOS26 `glassEffect`, `GlassEffectContainer`, `.glass` and `.glassProminent` remain availability-gated. iOS17 uses regularMaterial; Reduce Transparency takes priority and uses an opaque surface. No WebView/web renderer. Content surfaces are opaque. No decoration acquires a touch handler. Header controls remain 44pt; navigation logo has a fixed brand wordmark size to prevent clipping at large text sizes, while content uses Dynamic Type. Quick links use ViewThatFits and multiline labels; metadata and creator statistics have narrow-width fallback. Existing adaptive video/category/performer grids and 1200pt width limit remain.

**PHPlayer.swift, PHSeekSession.swift, PHAdjustmentPan.swift, PHModels.swift, PHClient.swift, PHParser.swift, PHProfileFilters.swift and PHSubscriptionParser.swift are byte-identical to build10.** Highest-real-resolution selection, manual source retention, one UIKit aspectFit landscape player, safe-area top-left return, immediate quality menu, progress seek, PiP/background, audited brightness/volume gestures, author actual filtering/pagination, subscription account isolation and login protocol are not reimplemented. Production state models are unchanged; the only detail-model addition is an isolated `#if DEBUG` synthetic UI fixture branch.

## Regression and evidence boundaries

Local Linux runs 41 UI architecture contracts, 37 player guards and Python parser fixture checks. CI/Xcode26 must compile/run Swift catalog, quality, seek and adjustment regressions, all previous Simulator interaction tests plus new quick-link/account/detail and accessibilityXXXL tests, then build unsigned iphoneos Release IPA. UI screenshots are exported directly from XCTAttachment in the real Simulator. Artifact name: `Build11-UIEvidence-synthetic-fixtures`.

All screenshots are **synthetic fixture, not live content**. The first real Simulator run passed six of seven tests; the legacy global `buttons["分类"].firstMatch` incorrectly selected the new covered home shortcut instead of the menu row. Added a stable menu destination identifier and asserted that exact modal row is hittable before tapping; no assertion was removed. Actual first-run home/author/detail/XXXL screenshots were reviewed. Accessibility-size search now uses the concise native label “搜索” to avoid a tall wrapped capsule. First-run artifacts are retained separately as `attempt1`, not presented as a passing build.

Detail fixture uses an unavailable localhost source to exercise the real native view and controls without a live network/login or successful playback claim. The adjustment fixture output adapter remains synthetic, not a physical volume measurement. Large-type test establishes navigation reachability and bounds, not an exhaustive typography audit. iOS17 fallback and Reduce Transparency are protected in source contracts but not claimed as device-run screenshot acceptance. iPad/narrow layout choices are implemented, not an exhaustive multi-device visual acceptance matrix.

No real login or subscription-write operation performed. No physical-device visual signoff, live highest-quality playback, real PiP/background/lock-screen continuity, hardware brightness/volume or route testing claimed. CI success and unsigned package integrity are separate from those acceptance tasks. The unsigned IPA requires user signing before installation.
