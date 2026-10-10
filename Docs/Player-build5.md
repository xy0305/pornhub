# Player build 5: progress interaction and transport polish

## Audited upstream API (exact KSPlayer 2.3.4)

Fetched tag `2.3.4` into a separate checkout and read:

- `Sources/KSPlayer/Core/UIKitExtend.swift`: `KSSlider` is public but not open; toolbar owns it as `let` and its delegate is internal. It combines UISlider tracking with separate tap/pan recognizers, expands `thumbRect` by 20pt, and maps touch cancellation/outside release to touchUpInside. Its custom pan only recognizes ended (not cancelled) as completion.
- `Core/PlayerToolBar.swift`: assigning currentTime writes the slider value; toolbar height is 49pt, play width 30pt.
- `Video/VideoPlayerView.swift`: private isSliderSliding suppresses time callbacks; the controller has tap/doubleTap/pan/longPress recognizers. Auto-hide work item is private. Native iOS slider height is 16pt; menus route to change(definitionIndex:).
- `Video/IOSVideoPlayerView.swift`: pan enabled again by judgePanGesture on player transitions; back/fullscreen widths 25/30pt. Preserve its playback and menu implementation, override only fullscreen presentation as build4 did.
- `Core/PlayerView.swift` and `AVPlayer/KSPlayerLayer.swift`: default seek can autoplay via global options. Layer's public seek(time:autoPlay:completion:) accepts explicit playback intent and completion.

## Implementation

Preserve build4's single UIViewControllerRepresentable owner, single native player, safe-area constrained UIKit reparenting, scene-specific rotation and app orientation delegate, transition guards, teardown and aspectFit. Do not create another SwiftUI player or share a coordinator. No catalog/login/search change and no dependency upgrade.

Hide and disable only the stock KSSlider input (retain its time model), overlay an app UISlider with one UIKit tracking path: 44pt hit height, 4pt track, white 18pt thumb / 24pt highlighted thumb and orange elapsed track. Tapping the track starts at the touched position, grabbing the thumb preserves finger offset; horizontal movement is clamped. Ends inside and outside commit once, cancellation restores engine position without seeking. VoiceOver increment/decrement uses the same session/commit path.

PHSeekSession owns finite duration bounds, preview, pending seek and generation. Time callbacks cannot overwrite a drag or pending seek. Dragging shows monospaced target/total preview and time text, and holds controls visible. Player gestures reject control-bar/control touches; pan is disabled while dragging/seeking and judgePanGesture respects that guard. Release performs exactly one public layer seek with current playback intent (paused stays paused), not repeated valueChanged seeks or a delayed guessed seek. Completion checks layer identity and generation; failure restores engine time. An 8-second recovery timer unlocks the UI if completion stalls, but never retries seek. Reset, quality change, cancellation and presentation changes invalidate old UI completion state. This cannot guarantee cancellation of an already submitted backend seek.

Control styling uses stronger existing top/bottom black gradients, orange play/progress accents, white SF Symbols, smaller crisp monospaced time and 44pt playback/back/fullscreen hit sizes. Existing narrow width constraints are replaced rather than overconstrained. Quality keeps the official UIMenu and 132pt safe-area slot, with 44pt height, subtle orange border and chevron. No extra toolbar buttons. Empty title and secondary track/rate/subtitle/PiP controls remain hidden.

Version remains 1.0.0, build becomes 5.

## Validation and boundaries

`Tests/PlayerChecks/check.py` retains build4 architecture guards and adds interaction/layout source guards. `Tests/PlayerChecks/SeekRegression.swift` compiles the actual production PHSeekSession without UIKit and tests invalid metadata, bounds, preview hold, single commit, pending immutability, cancellation, stale/duplicate completion and session isolation. These run in CI alongside unchanged parser fixtures and full unsigned iphoneos Release compilation.

Source checks do not prove UIKit touch routing or pixel layout. Swift logic tests do not emulate a decoder or network. Device acceptance still required: inline 320/375pt widths; notched landscape/iPad safe areas; short/long/4:3/portrait video; stationary thumb hold past auto-hide; track tap; slow/fast drags; release outside; system cancellation; pending seek timeout/failure; paused seek; repeated fullscreen migration and quality changes; VoiceOver; background/resume and teardown. Verify no gesture steals progress input, no held preview jumps, no overlapping labels/buttons, and playback continuity. No real-device verification or claim that the user's subjective feedback is fully resolved.
