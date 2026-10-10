# Player build 4: upstream audit and regression scope

## Sources actually fetched over HTTPS

Audited release 2.3.4 (the app now pins this exact version):

- https://github.com/kingslay/KSPlayer/blob/2.3.4/Sources/KSPlayer/Video/IOSVideoPlayerView.swift
- https://github.com/kingslay/KSPlayer/blob/2.3.4/Demo/demo-iOS/demo-iOS/DetailViewController.swift
- https://github.com/kingslay/KSPlayer/blob/2.3.4/Sources/KSPlayer/AVPlayer/KSVideoPlayer.swift
- https://github.com/kingslay/KSPlayer/blob/2.3.4/Sources/KSPlayer/Video/VideoPlayerView.swift

Also fetched current main (tree SHA b3afb825013606e9018296ecbe97291ba95a8948):

- https://github.com/kingslay/KSPlayer/blob/b3afb825013606e9018296ecbe97291ba95a8948/Sources/KSPlayerUI/View/IOSVideoPlayerView.swift
- https://github.com/kingslay/KSPlayer/blob/b3afb825013606e9018296ecbe97291ba95a8948/Sources/KSPlayerUI/View/PlayerFullScreenViewController.swift

The current main reorganized the library into KSPlayerUI; it is not the 2.3.4 API. Both use single-view fullscreen reparenting. We adopt that pattern without upgrading the dependency or copying its older fullscreen orientation controller verbatim.

## Confirmed from source

`KSVideoPlayer.Coordinator.makeView` returns the existing `player.view` when URL is unchanged. Two representables sharing that coordinator therefore do not own two independent UIView instances. `dismantleUIView` calls `resetPlayer`, which clears the coordinator layer. Upstream itself documents a make/dismantle ordering hazard. Build 3 created inline and fullscreen representables with the same coordinator, while inline `onDisappear` paused it. This is an ownership/lifecycle conflict, not a video aspect-ratio calculation fix.

The app also lacked the UIApplicationDelegate supportedInterfaceOrientations bridge documented by KSPlayer. Its orientation helper chose the first connected scene rather than the player's own scene. Build 3 placed its controls in a full-screen SwiftUI stage that ignored safe areas and used natural-size-dependent frames plus `.clipped()`.

## Inferences, not device-confirmed findings

The lifecycle conflict can detach/reset/pause the fullscreen render view during presentation/dismissal. Transitional geometry combined with the ignored safe area and clipping can explain offscreen controls. The exact contribution of each mechanism to the user's screenshots cannot be established without a device trace. We do not claim device acceptance.

## Implementation

A UIViewControllerRepresentable owns exactly one IOSVideoPlayerView subclass. Fullscreen transfers that same view to a landscape-only UIViewController after deactivating its old host constraints; dismissal restores it. Rotation uses the owning UIWindowScene, an application orientation delegate and requestGeometryUpdate, with transition reentry guarded. Only permanent representable teardown resets playback. There is no second SwiftUI video stage, naturalSize layout polling, delayed seek, or inline disappearance pause.

The native renderer fills an Auto Layout container and uses scaleAspectFit once. The fullscreen container is black; the player is constrained to all four safe-area edges. Intentional letterboxing is preferred over cropping/stretching. Controls never use video pixel dimensions.

The official definition UIMenu button is reused, removed from the crowded bottom toolbar and pinned to a 132x40pt safe-area slot. Its title includes the selected definition. Native resource definitions/change(definitionIndex:) retain KSPlayer's playback-position handling rather than a fixed 350ms seek. Transport/progress remain native. Extra toolbar track/rate/subtitle/PiP controls are hidden to keep narrow inline widths usable.

Build number is 4; controller-based status-bar appearance enables landscape status-bar hiding. No search/login behavior was changed.

## Automated and manual validation

`python3 Tests/PlayerChecks/check.py` checks 18 source-level architecture invariants and runs in CI before the existing parser tests and iphoneos Release build. These are not runtime layout tests. Existing Python fixture checks are retained; CI also compiles/runs the existing Swift parser fixture executable.

Manual device checks still required: 16:9, 4:3 and portrait videos; notched iPhone and iPad; enter/exit fullscreen repeatedly while playing and paused; quality switching before/after metadata ready; native menu with many definitions; seek and playback continuity; background/resume; navigate away while fullscreen. Confirm the quality entry/menu and transport stay within safe bounds and that video is letterboxed without stretching. No real-device acceptance is claimed by this change.
