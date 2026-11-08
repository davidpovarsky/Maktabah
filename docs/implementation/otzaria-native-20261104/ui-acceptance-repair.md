# Native UI acceptance repair — in progress

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
