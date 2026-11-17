# O2-B — downstream history contrast and sidebar gesture evidence

Read this first. Original Phase 1 owner plan and `O2_EXECUTION_PLAN.md` constraints bind. Work only in the existing Cezar task worktree; no nested agents or independent reviewer dispatch.

## Goal and deliberately limited claims

Repair the observed History section-heading contrast gap using the existing native semantic styling. Investigate the reproduced LTR Contents-to-Library failure without inventing an unproved gesture/layout repair. Preserve original Maktabah UI, native search/scroll/TOC and approved upstream hooks.

The original native run is `43891893650` on `4065feef…`: 9 PASS / 13 FAIL / 1 interrupted / 4 NOT_RUN, cancelled, no aggregate acceptance. Rotation cases were contaminated by system prompts; do not treat them as proven layout regressions. O2-A is locally integrated, but has not been executed on iOS.

## Exact writable paths

1. `Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift`
2. `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift`
3. `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift` — only if a concrete scoped cause requires it; otherwise leave untouched.
4. `tools/test_native_sidebar_policy.swift` — existing real portable policy tests; never weaken its assertions.
5. `tools/test_o2b_native_ux.py` — optional new narrow source-contract/portable test harness; label its limits honestly.
6. `docs/phase1-cezar/O2B_IMPLEMENTATION_REPORT.md`

All other paths are read-only, including O2-A source/scripts/tests, all `Source/UI/`, all `Source/Features/`, original native UI tests, `R27NativeInteractionAcceptanceTests.swift`, `R27_CASES.json`, workflow/project/lock/config files, `PROJECT_BOARD.md`, shared HQ and Asana. Do not add a second UI, parser, scroll implementation or gesture system.

## History section contrast

- The actual unfiltered native accessibility audit failed on `Text("חיפושים אחרונים")`, `GlobalSearchHistoryContent.swift:31`.
- Reuse the existing dynamic semantic primary-foreground pattern in `GlobalSearchHeader.swift:65-67` against `Color.appBackground`. Keep native List/Section structure, RTL, localization, Dynamic Type, clear/history actions, existing identifiers and the selected query semantics.
- Minimal styling only. A source-contract check may demonstrate the intended style is explicit, but it is not an executed contrast/accessibility pass.

## Sidebar LTR/RTL and gesture triage

- Actual LTR Library-to-Contents swipe and both Library/Contents shared search checks progressed successfully; the reverse Contents-to-Library drag failed to select page 0. RTL and scene-state tests were blocked at reader startup `invalidLocator`, not proven gesture failures.
- Inspect the existing single NavigationStack/search adapter, `.page` TabView, scoped primary-column `bodyPan`, touch-region gate, delegate arbitration, direction policy and coordinator state. Verify exact UIKit delegate semantics through shared apple-devtools/official documentation when needed; do not guess the direction of failure priority.
- Reuse current extension points. Preserve vertical native scrolling, horizontal direction per RTL/LTR, native controls, reader identity/locator, and shared single search field.
- Add bounded, DEBUG-only, content-free gesture breadcrumbs if needed: eligibility/should-begin/terminal state/category and page-direction decisions; no query/book/reader content, URLs, private payloads or unbounded `.changed` logging.
- Change gesture behavior only with a specific reproduced defect or an authoritative, concrete platform-contract violation. If source evidence cannot isolate the cause without native execution, deliver diagnostics and explicitly leave LTR/RTL acceptance OPEN. Do not present a fabricated portable gesture model as a native reproduction.
- Do not replace native lists/scrolling, inject global/coordinate gestures, alter protected upstream files or weaken UI assertions. Stop with `BLOCKED_OWNER` if the only fix crosses protected scope.

## Focused test cycle and reporting

- [ ] Read existing relevant tests, add meaningful narrow RED assertions for the intended source/policy change, and record their scope.
- [ ] Implement only the smallest supported contrast/diagnostic/repair delta within the exact files.
- [ ] Run real portable policy checks using the existing `Scripts/CI/test-native-sidebar-policy.py` and `tools/test_native_sidebar_policy.swift`; do not rewrite a passing direction policy solely to make a new test pass.
- [ ] Run `tools/hq-sidebar-check.py` and any new focused harness with real Python 3.12 and installed portable Swift, each bounded to 60s. Existing checker files are read-only.
- [ ] Report source-contract checks, portable compiled policy assertions, syntax parse and native execution as separate statuses. Windows cannot typecheck SwiftUI/UIKit or prove body gesture arbitration/AX contrast.
- [ ] Self-review exact paths/protected integrity, cancellation/state/search regression risks, privacy and claimed evidence, then commit only authorized paths and provide full base/head SHAs plus exact commands/output.

Read-only Apple SDK/API lookup is allowed. No paid CI/manual workflow dispatch, project build/test suite, dependencies, push, account/model/provider change, fallback, rotation, production, email or user database. On quota/429/403, stop without retry.

If only contrast and diagnostics can safely be completed locally, say so plainly and keep native/body-paging gates NOT_RUN/OPEN; do not claim Phase 1 READY. Parent will obtain a separate independent task review after your report.
