# Global Search independent baseline

Task1220546245946205; I developer chat01a1df8b-4498-76c1-8cca-cd5c11120b7a, acting QA role in the existing independent developer chat. Sole implementation writer S remains separate. Base13e40d1daa4a53799c94cd8ed5170f1343b9b1e8, branch codex/otzaria-global-search-acceptance-20261115. The only initial untracked file was the manager-supplied immutable specification; it remains unmodified. Exact239lines/35749bytes/SHA88d91318f0436aa98221acb688fa5245c466b53d3831149a87a8c393824bb100 verified. The external GLOBAL_SEARCH_ACK_I.json records actual thread/worktree/branch/HEAD ownership.

## Authority and limits

Only GlobalSearchNativeAcceptanceTests.swift and this QA directory are owned for writes. Production, shared UIKit, project membership, workflows/runner, previous Inspector/Resolver trees and public-v2 remain untouched. Original upstream HEAD was reverified d46af139b3a265399c16d87f5923acd8e3444024; the new app-specific UI-test path has no upstream tree entry. The upstream policy is unchanged against the earlier inspected policy. This is independent source baseline/design, not native acceptance.

`baseline.json` records raw file hashes. `acceptance-matrix.json` has48 requirement families across5 explicit simulator layout contexts plus physical iPad rows, with6 engine variants per simulator row. All new-UI runtime rows start NOT_RUN. The matrix does not claim that this covers the full Cartesian product of theme/language/accessibility/keyboard variants: each observed configuration must be recorded separately.

## Observed source gaps at13e40d1d

| ID | Reproducible source evidence | Acceptance consequence |
| --- | --- | --- |
| B01 | SearchModeView.body has focus-driven SearchHistoryOverlay in a ZStack; compactFilterView occupies initial compact content | Baseline differs from inline history/compact book-chooser specification; new UI must change composition |
| B02 | SearchInputBar and UnifiedSearchToolbar each submit; iPhoneLayout.searchTabContent also applies tree-filter searchable | Need one main field and single-submit observations, distinguishing the legitimate sidebar title field |
| B03 | SearchModeView.searchResultsView applies toolbar searchable to resultKitabFilter | Need results-only inline placement without conflating main query, tree filter or Library query |
| B04 | UnifiedSearchToolbar Stop calls stopSearch only for isSefaria then assigns isSearching=false | Otzaria/Zayit cancellation cannot be accepted from disappearance of progress alone |
| B05 | SearchAdvancedOptionsView omits otzariaScope/negativeScope/negativeDistance/grouping although session/runOtzariaSearch already carry them | Test every missing real binding plus conditional validation; no second engine/state |
| B06 | SefariaEmbeddedSearchAdapter.executeSearch does not read request.options; sends fixed exact/relevance | Hide/reject unsupported match/distance/sort/reverse controls until actual source fidelity proof |
| B07 | SefariaRemoteStore consumes options and raw source evidence through a different path | Legacy and Embedded are not equivalent; a registered search capability is not operation proof |
| B08 | canSaveResults uses usesNativeMaktabahDataPath and numeric archive | This is not by itself durable Otzaria persistence proof; save/reopen must be proven or unavailable |
| B09 | SearchResultsListView groups by canonical locator and versions, uses virtualized List, and has independent hasMore button | Visible cell count is not raw loaded/occurrence count. Empty loaded projection must retain paging |
| B10 | ListContentView has private UIButton-based checked/partial/unchecked state; iOSSearchFilterViewController controls canonical selectedBookIds | Preserve actual UIKit hierarchy/tri-state. No shared-cell rewrite from QA; coordinate real AX exposure with S |
| B11 | Session default scope is advanced; history is existing SearchViewModel state/UserDefaults | Freeze current default/history behavior; do not infer Exact default from the illustration |

These are baseline source observations for S's implementation, not verified defects in a supplied new candidate or native FAIL results. S received the source-capability and observability contract directly. The public ActionSearchSemantics port is deliberately narrower than the app UI path; it is not a substitute capability oracle for this task.

## Native blocker and preflight evidence

Manager's terminal evidence for frozen43736843778: checkout13e40d1d, application pin4dae2dac23b51f504e1722d24a90028cc4caa690; Xcode27.1(27A9275), Swift6.4, SDK27.1. Build failed because the effective app target is18.6 while MaktabahNativeIntents imports a host with minimum26.0. Project-level26.2 is insufficient. The source PBX app and UI-test configurations independently show18.6. Manager owns alignment; I will not change PBX or add fallbacks to hide it.

The11 existing UI cases are NOT_RUN(infrastructure errors), with0PASS/0FAIL, no real xcresult/screenshots. They are not Global Search tests. See baseline-native-blocker.json, which hashes the canonical manager review. I did not poll/watch/restart that run. Reported toolchain facts are evidence for that execution, not current QA simulator/device/HID readiness.

Local apple-doctor: Windows Swift6.3.3 only, no Apple SDK. Remote Desktop Commander enumeration exposed torah-social; fresh uname returned Linux. Repository-visible GitHub runner inventory returned0, which is not proof that no shared/organization-managed Mac exists. Fresh actual Mac destination/UDID/runtime/SDK/CLI checks remain required before native testing. No new CI or device mutation was started.

## Evidence standards

No UI identity/count/readiness value that merely echoes a request is an oracle. Single submit, local-filter-no-request, cancellation, stale suppression and no redundant index download require actual session/provider counters or correlated source logs. Native screenshots/tree plus visible/hittable behavior supplement these observations. No AX disappearance-only dismissal, optional assertions, test skips, fabricated rows or UI callback success can satisfy acceptance.

Automatic accessibility audits are useful but not VoiceOver acceptance. Apple describes both the audit scope and the need to test assistive apps: [accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app). Native glass button styles are documented by Apple: [glass style](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass). Installed Xcode SDK/compiler remains final declaration/compilation authority. The user target26.2 overrides generic skill advice to add older-OS fallbacks; the user also requires GlassEffectContainer only when actually justified, not a blanket extra layer.
