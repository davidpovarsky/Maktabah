# Native UI acceptance repair — in progress

Attribution: [מיה | Native UX] [MAIN_SESSION]; CI fixture repairs [נועם | Engineering] [MAIN_SESSION]. No delegated agent work.

The user explicitly included the previously deferred UI failures in this session's scope on 2026-11-08. They must be repaired and rerun before this integration's TestFlight upload; the other chat's manual-beta exception is not acceptance here.

## Actual baseline

[Run 42447373973](https://github.com/davidpovarsky/Maktabah/actions/runs/42447373973) tested source 661d53e0541779ae6c9ed7526cae5b1f273c708d. Its focused iPad selection passed four of seventeen cases and failed thirteen; the separate phone case failed. [Native logs, accessibility trees and screenshots](https://github.com/davidpovarsky/Maktabah/actions/runs/42447373973/artifacts/13607217850) are the baseline evidence, not a claim about the repaired app.

The observed failures cover TOC search, global-search geometry, book-info dismissal, palette Escape, reader chrome collapse, overview drag persistence, real Reduce Motion, narrow-window controls/restoration, subsequent original-view observations and the phone overview route.

## Prepared corrections, pending runtime verification

- Keep the command keys on the actual native text-input responder. Preserve the original command model, filtering, query binding, results and macOS input; remove the ineffective extra hosting-controller Escape layer.
- Anchor the existing expanded palette below the actual native detail bars, rather than the root split-view's top. Let the native iPad tab bar use its automatic policy when visible and preserve the original policy when the feature is off.
- Isolate Library and Contents navigation/search preferences using two persistent hosting roots in a native UIPageViewController. Retain original views and their viewports, environment, RTL, grouping and selection. Restore the original Library query binding to a native search field; keep native TOC search visible.
- Give each tab drag its original UUID and an owned local session. Prevent swipe-to-close from consuming a lifted drag, and persist the authoritative order before collection animation can receive an obsolete SwiftUI projection.
- Query the original book-info Close action in its real popover. It is not a navigation-bar action; the baseline tree already shows the genuine segmented card.
- Restore a resized system window using Apple's documented [Globe-F shortcut](https://support.apple.com/en-lamr/102393), preserving the actual original-frame assertion. The prior coordinate-based restoration failed and subsequent baseline tests ran in a 375-by-486 window.
- Verify the real Settings switch and a fresh foreground-app UIAccessibility Reduce Motion observation, rather than a potentially cached value in the background XCTest runner. No feature override or fabricated preference is supplied.
- Save screenshots and hierarchy before a failed settling assertion. Attach fresh read-only native scroll facts to diagnose any remaining chrome-collapse failure.

Native search placement follows Apple's [search-interface documentation](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app). The original Maktabah colors, reader typography, renderer, backend contracts and canonical locator persistence remain the source of behavior.

## Open gates

[SDK run 42481871742](https://github.com/davidpovarsky/Maktabah/actions/runs/42481871742) passed at e873d13c7dd334ab7d9f4056a0f32ea1fb30f6ce: actual XCTest code generation, original sidebar/toolbar source compilation, the modified CommandPalette and DuckDuckGoBookTabs packages, and all 66 portable workspace checks. This is not app/runtime acceptance.

The baseline phone receipt identifies an actual iPhone Duo, not a conventional compact-width phone. Its regular-width reader lacks the original compact-only title action. A downstream modifier supplies that same native title action and manager binding only for enabled regular-width phones, through the existing downstream reader-surface composition. It does not change the original iOSReaderView condition or flags-off behavior. Runtime proof remains pending on the same device selection.

The baseline collapse video shows the genuine linked passage fitting within the iPad viewport at the normal 19pt reader preference. The scrolling case now uses the reader's supported 48pt preference and requires measured native content height to exceed its viewport by 100pt before performing the unchanged collapse/restore assertions. Other launches explicitly use the normal 19pt preference. No generated content or simulated scroll event is introduced.

The focused SDK workflow compiles actual XCTest, sidebar/toolbar sources and the two changed source packages. Compilation is not runtime acceptance. Real source/edition interactions, all required iPad sizes, Dynamic Type, phone, windowing, accessibility, production Release and final source synchronization remain required. Reader chrome collapse, narrow-window controls and phone overview must not be called repaired until their real interactions pass.

No TestFlight upload from this integration has been dispatched.

## Native harness result and repair

[Run 42482169586](https://github.com/davidpovarsky/Maktabah/actions/runs/42482169586) built the full app and tests at 302b62b4, including the regular-width phone action, but failed before any required source/edition XCTest: CoreSimulator's data-container query timed out after 45 seconds following installation on a newly created run-owned iPad. The broad UI and Release stages did not execute. The failure is not a UI assertion result.

Container discovery now retains its exact attempt receipt and permits one recovery using the visual matrix's existing scoped shutdown/boot procedure. It accepts only a UUID, validates the actual returned application directory within that Simulator, and does not retry an installer rejection, an absent app or any XCTest. Eight focused fault-injection/path tests pass, including persistent timeout, non-transient failure, another application's path, and the distinct genuine App Group/private storage layouts.

The fixture also no longer guesses that signing always selects Maktabah-Debug storage. The actual baseline native report used a Shared/AppGroup path. It first completes a real digest-checked database installation, obtains the canonical storage path from that native receipt, seeds the unchanged checksum-verified lexical resource there, then runs the real installer with both indexes and searches required. Both native receipts are retained and must agree on the final database path. No database is copied by this harness, no production storage override is provided, and no required interaction is skipped.

miniTest10-v9 is [published immutably](https://github.com/davidpovarsky/Maktabah/releases/tag/otzaria-miniTest10-v9) at builder 013f0a9a6a11006478b7b2781e3522e6766888b1. All 66 server asset digests/sizes match the verified build artifacts; the original schema10 metadata sidecars were decompressed and checked. Native HTTP bootstrap/relaunch/search is pending [42484697648](https://github.com/davidpovarsky/Maktabah/actions/runs/42484697648). The originating build 42480483741 passed native corpus indexing/reopen but failed its GitHub Actions publication with HTTP403; manual publication does not turn that workflow into a pass.

That reuse run has now finished: genuine HTTP installation and cold relaunch both passed with 18,879 documents, 131 actual Otzaria matches, 134 Zayit matches, exact hashes and restored ready state. The subsequent native 2×2 backend/language diagnostics executed 37 rows, with 34 passes and three annotation-identity failures; therefore the workflow is FAIL. Its later prebuilt negative-path and device-build steps did not run. Native receipts are retained in the run artifact and locally under `build/integration-verification/mini-v9-reuse-42484697648/miniTest10/logs`.

The annotation failure is a real cache/pending-sync identity defect: a creation caller holds a pre-insert value without the UUID that the repository generated. SQL preserves that UUID, but an update's returned value previously lost it in the cache. `updateAnnotationRow` now restores the existing row's identity before publishing the update. The native diagnostic retains all existing assertions and additionally compares cached IDs to independently loaded SQLite rows. The fix needs a fresh native rerun; the prior failing run is not relabeled green.

The b0ec7a86 rerun 42486273365 stopped before app build: the new path regression test compared macOS's `/private/var` canonical temporary path with its `/var` alias as literal strings. The helper already resolves paths correctly. The test's expected root now also resolves the same filesystem directory; ownership and foreign-path rejection assertions remain. These cheap Python checks now run immediately after checkout, before SDK/source-port/npm work. No UI acceptance occurred in that failed run.

## Genuine functional run 42490779555

At bdab4b549b23f51324ffc1d31eaa168b6c85e1c2, fixture installation and the full SDK build passed. All 13 required native methods executed: five passed, eight failed. The real Hermes diagnostic passed all 18 mandatory stages. Catalog launch, reader presentation, background/relaunch and backend switching also passed. The broad visual matrix and production Release were not reached.

The failure hierarchies establish that Inspector commentary groups are native Other containers containing header Buttons, not Buttons themselves. The native passage tap did open the panel with real sources. The tests now query those containers and activate their actual headers. TOC tests now open the original More menu before selecting its TOC item. Canonical navigation and real-content assertions are retained.

Search result buttons exposed a full-width accessibility frame, but the centered tap landed on empty label space and left their value Collapsed. The label now has a rectangular full-width hit region; the original centered tap is retained. The edition row previously rendered no content until its own attached task populated versions. It now keeps the native Picker mounted while metadata loads, disables selection until loading completes, and derives its work from the actual canonical reader destination. The real edition test must wait for an enabled control and still prove missing-edition errors and merged-text recovery at the unchanged locator. Source SQLite confirms Torat Emet and Vocalized Edition have lines 522–526 while Minchat Chinukh has none there.

Collapsed-result copy actions also now check the real schema7 export policy at the clipboard boundary and reject failures or profile-generation changes. This closes the path that previously bypassed the expanded preview's protection. These repairs require a fresh native run; none of the eight failing methods has been relabeled PASS.

Separately, mini reuse run 42488278465 passed every one of the 37 real shared-data rows after the annotation identity fix, both engine searches, HTTP install/cold restore and the unsigned device Release build. Full published-package HTTP acceptance 42490213235 passed the actual 7,660,127-document native download/install and cold reopen without local indexing. These data results do not substitute for the pending UI/production Release gates.
