# 1.0.0 (9) — highest-quality playback and restrained native design

## Quality selection

`PHParser.qualities` now validates http(s) URLs with hosts, ranks every valid source by actual positive height (numeric quality/quality-p only when height is absent), retains unknown adaptive sources as `自动`, deduplicates URLs rather than labels, and uses stable ordering for ties. Website `defaultQuality` remains raw metadata only: it does not choose playback quality. Unknown metadata never becomes a fabricated 1080p label. The controller repeats validation/ranking so callers/fixtures cannot bypass the policy.

Every new `videoID` starts at highest known resolution. An initially empty/unknown list safely upgrades when real metadata arrives. `PHQualitySelection` records manual intent per video; same-video SwiftUI updates do not reset it. Signed URL refresh chooses the exact URL first, then the same real height/label. If that manual tier disappears, use the nearest available tier not above it, otherwise highest valid fallback. Empty same-video metadata does not destroy an active stream. Resource replacement reuses build7 source-ready position/play-intent restoration and stale-layer protection. New videos reset manual intent. Executable Swift tests cover low site-default vs high source, unsorted inputs, invalid schemes, URL duplicates, unknown/missing metadata, URL renewal, refresh/manual preservation and identity changes.

## Design decisions

- Near-black canvas, opaque charcoal surfaces, restrained orange accent. Remove outlined content cards; thumbnails and title hierarchy carry the interface instead of thick borders.
- Home: one grouped navigation rail (menu, brand, subscriptions, account), separate full-width 44pt search target; no individual glass bubbles inside the rail. Header remains safe-area inset. Feed uses adaptive columns and 24pt rhythm rather than an enormous iPad single-column card.
- Video cards: 16:9 cropped thumbnail with a compact monospaced duration badge; title first, quiet author/verification/views second. No invented HD badges or fake overflow actions. Content is capped/centered on wide displays.
- Categories remain landscape image tiles with gradient legibility; performers use larger portraits and borderless name stacks; author stats have horizontal/vertical fallback. Author filter controls share a quiet capsule style, retain horizontal overflow, actual discovered source queries, stale-response guards and pagination.
- Search input is opaque rather than decorative glass; suggestion rows have 44pt targets. Account retains native Form/SecureField and unchanged website protocol. Album/GIF/photo grids become adaptive instead of fixed phone columns.
- Loading, retryable errors and saved/subscription empty states use shared typography/icon/spacing. Content cards stay opaque. Navigation/actions use real iOS26 Liquid Glass, iOS17 material fallback, and accessibility Reduce Transparency opaque fallback. Build7 hit-region and single sheet-owner protections remain.

## PiP, background, and landscape controls

- Add `UIBackgroundModes: audio`, keep AVAudioSession `.playback`/`.moviePlayback`, and explicitly enable public `KSOptions.canBackgroundPlay`. No scenePhase/onDisappear pause/reset was added; final owner disposal still stops PiP, resets/releases the player and restores portrait.
- Audit of KSPlayer 2.3.4: its public `isPipActive=true` / official button helper calls `KSPictureInPictureController.start(view:)`, whose default branch uses an UIApplication `suspend` selector. This app deliberately does NOT invoke that path. The existing official PiP button is reused, moved to a 44pt safe-area slot, and wired to public AVKit `startPictureInPicture`/`stopPictureInPicture` after device/controller/readiness checks, with KSPlayerLayer as delegate. Unsupported/unready sources show an explicit native transient message, not an inert button. No private API added.
- Audit found a single existing KSPlayer pan recognizer already direction-locks at `.began`; reuse it, do not stack another recognizer. Add 6pt intent threshold, horizontal pass-through, landscape-only vertical adjustment, origin-half lock (left brightness/right system volume), translation-based sensitivity and 0...1 clamping. Use attached MPVolumeView's UISlider + public valueChanged events, never private volume setters. Native temporary percentage HUD is non-interactive.
- Gestures reject controls, progress/top/bottom bars, active seeks and pending quality restoration. Vertical end never runs horizontal seek. Brightness uses UIScreen public brightness. System route volume, interruption/audio-session recovery and actual PiP require physical-device validation.

## Preserved contracts

Single UIKit aspectFit player reparents during landscape; build8 upper-left safe-area back button, real definition source changes and build5 PHSeekSession are retained. No WebView, new authentication protocol, true-account login, or subscription write is introduced. `/subscriptions` remains account/session isolated, read-only retrieval in this work.

## Evidence and limitations

CI runs 37 architecture guards, native UI contracts, compiled Swift quality/catalog/author/subscription fixtures and build5 seek regression, then actual XCUITest on Simulator. Interaction tests cover header target edges/sheet ownership, author real filter/page/stale/retry fixtures, account isolation, highest-source initial selection, PiP unavailable feedback, landscape menu URL switches and upper-left return. XCTest retains home/author/player screenshots; workflow exports attachments to `Build9-UIEvidence-synthetic-fixtures`. All fixture screenshots are synthetic, not live site data. Debug-only gradient thumbnail fixtures are excluded from shipping Release.

Static source tests are NOT visual acceptance. Unplayable localhost quality fixtures prove URL selection/menu/layout only, not frame decoding/playback continuity. Simulator tests do not establish real PiP, lock-screen/background audio, hardware volume, actual live stream position continuity, or real-device glass appearance. Narrow/iPad/Reduce Transparency paths are implemented but not all have runtime screenshot acceptance. Unsigned Release IPA is built only after all CI steps succeed.

Official audited source: https://github.com/kingslay/KSPlayer/tree/2.3.4/Sources/KSPlayer (Video/IOSVideoPlayerView.swift, Video/VideoPlayerView.swift, AVPlayer/KSPlayerLayer.swift, AVPlayer/KSPictureInPictureController.swift, Core/PlayerToolBar.swift).
