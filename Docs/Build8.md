# 1.0.0 (8) — native player back placement and author video filters

## Scope / implementation

- KSPlayer 2.3.4 `IOSVideoPlayerView.customizeUIComponents` inserts its actual `backButton` into `navigationBar`, a stack view, with a 25pt width. Build7 increased width but did not remove arranged layout, allowing an empty-title stack to center the button. Build8 calls `removeArrangedSubview`, removes the old superview (and therefore its stack-owned constraints), then reparents the SAME button, preserving upstream action, to the player's safe area: leading +12, top +4, width 44, height >=44. It is no longer horizontally positioned by the title/route stack. The player itself remains safe-area constrained on all edges.
- No new player instance: fullscreen still migrates the one UIKit view. Aspect-fit, 16:9 inline presentation, build7 definition menu/source-ready position restoration and build5 seek state machine remain intact. Only back layout changes in PHPlayer.swift; PHSeekSession.swift is byte-for-byte unchanged.
- Native SwiftUI horizontal author controls: default, discovered latest/most-viewed/top-rated links and More > Longest when offered; filter icon presents the author's actual uploaded/tagged source links. There is no WebView and no synthetic server API.
- Capability discovery reads only the author's own filter `<ul>` blocks and validates site host + author prefix. Model/pornstar order codes and channel order codes are not interchangeable. Author home pages without filters follow an actual same-author `/videos` link if present. Missing capability blocks degrade to the source's default list and a native explanatory label, not invented filters.
- Selection clears video pages and invalidates older generations. Pagination keeps selected path/query and replaces only `page`. Stale success/error responses cannot overwrite current selection; page append is deduplicated. Errors retain the failed selection/page and expose Retry. No account write was performed to verify this release.

## Read-only live research (2026-10-11, iPhone User-Agent)

Requests used curl with `-k` in this shell; app URLSession TLS verification was NOT disabled. Network observations are HTML evidence, not contractual APIs; capabilities are discovered afresh for each author. Sanitized filter blocks are saved under Tests/Fixtures/profile-*.html and response hashes/first listing keys in Profile-build8-network.json. No cookies, tokens or account details are stored there.

Confirmed URLs:

- https://www.pornhub.com/model/lovely-asuna — real `/model/lovely-asuna/videos` link on homepage, with no sort block on homepage itself.
- https://www.pornhub.com/model/lovely-asuna/videos — Uploaded only in source dropdown; Most Recent is the bare URL, Most Viewed `?o=mv`, Top Rated `?o=tr`, Longest `?o=lg`.
- https://cn.pornhub.com/model/lovely-asuna/videos?o=mv
- https://cn.pornhub.com/model/lovely-asuna/videos?o=tr
- https://cn.pornhub.com/model/lovely-asuna/videos?o=lg — live listing keys changed across these responses after the featured section was excluded.
- https://www.pornhub.com/model/lovely-asuna/videos?o=mv&page=2 — returned a Page Not Found document (no pagination links on the actual first page). It is NOT valid page-two evidence; the app does not offer a next page without discovered pagination.
- https://www.pornhub.com/pornstar/lana-rhoades/videos?o=mv&page=2 — valid author's second page; canonical/next links retain `o=mv` and next `page=3`.
- https://www.pornhub.com/pornstar/lana-rhoades/videos — Tagged and Uploaded (`/videos/upload`) sources, and bare/mv/tr/lg order links with presentation-only fragments.
- https://www.pornhub.com/pornstar/lana-rhoades/videos/upload — same supported sorts scoped to the upload path.
- https://www.pornhub.com/channels/brazzers/videos — channel-specific subFilterList with `data-filter="o"`: Most Recent links to `/channels/brazzers`, Top Rated `?o=ra`, Most Viewed `?o=vi`; no Longest offered in this response.
- https://www.pornhub.com/users/xy0305/videos/public — no supported author filter block observed; this is a fallback observation, NOT proof that every public user lacks filters. All PHAuthorKind cases (model, pornstar, channel, user, unknown) use discovery, not hardcoded promises of capabilities.
- https://raw.githubusercontent.com/kingslay/KSPlayer/2.3.4/Sources/KSPlayer/Video/IOSVideoPlayerView.swift — audited official back-button insertion/width and action.

No duration-range/HD/paid-content condition appeared in the observed model/pornstar source dropdowns. Longest is a server sort, not a duration-range filter. We intentionally did not invent duration/type parameters. The screenshot's rightward overflow does not establish further conditions; only observed links are implemented.

## Tests and boundaries

CI compiles/runs Swift catalog + new real-filter fixtures (model, tagged pornstar, upload pornstar, channel; foreign/global link rejection, discovered video entry, page URL retention), existing seek regression executable, architecture/native UI contracts, then actual Simulator XCUITest via the existing generated Interactions target.

Runtime UI tests cover native header hit regions, landscape quality URL switching, returned button >=44pt/hittable and within upper-left quarter of landscape, tapping THAT button to return, author selection/query changes, page-two retention, clearing old pages, a deliberately delayed stale response, and retry of a deliberately failed Longest request. Debug author fixtures pass through production URL building, filter discovery, video parsing and profile state model; they do not authenticate or contact real accounts. Shipping Release excludes those fixtures.

Static checks alone are not runtime acceptance. The quality test intentionally uses unplayable localhost URLs: it proves layout/menu/source switching/return operation, NOT successful media playback, frame rendering, or real stream position continuity. No physical-device acceptance is claimed. CI must succeed before release artifact delivery; the reported workflow result and verified IPA hash are the release evidence.
