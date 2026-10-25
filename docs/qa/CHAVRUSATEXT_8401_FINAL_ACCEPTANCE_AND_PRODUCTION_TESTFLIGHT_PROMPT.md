# ChavrusaText — Build 8401 Final Acceptance, Upstream Approval & Production TestFlight

**Date:** 2026-10-26  
**Purpose:** Final, executable instructions for the **single primary coding/QA agent**, grounded in direct review of the current candidate and its actual iPad XCUITest/CI sources.  
**Desired end state:** Real end-to-end proof for the seven Build 8401 regressions, full-production Otzaria data profile verified separately from miniTest10, complete protected-upstream owner-approval dossier, a successful Xcode 27 validation run on the exact release candidate SHA, and (only when gates are legitimately satisfied) a signed **internal TestFlight** build that reaches Apple `VALID`. **Do not merge into main or the upstream-integration branch.**

> **Execution mandate:** Do the engineering and verification, do not merely write a plan or green summary. Existing 208/208 portable assertions and 16/16 XCUITests are genuine passes **for what they assert**, but several named acceptance tests do **not** prove the behavior their names claim. Correct the tests and any real application defects they reveal. Do not weaken, skip, mark optional, or game the tests.

## 0. Verified baseline: freeze and independently reconfirm before touching anything

- GitHub repository: `davidpovarsky/Maktabah`.
- Isolated candidate worktree: `C:\Users\DAVID\Code\Maktabah-build-8401-candidate`.
- Candidate branch: `validation/maktabah-build-8401-repair-production-20261025`.
- Local and remote HEAD at inspection: **`bf3bce4c6145715653400005d879023fe73557b6`**; clean worktree.
- Last code/test commit actually exercised by CI: **`dc8dfdd2de0a59644e5e9f57c875a55320ee15d2`**. HEAD differs by the following **documentation-only** commit: `bf3bce4c6145715653400005d879023fe73557b6`, updating `PROJECT_BOARD.md` and two QA documents. A new code change or approval/CI gate change requires a new test run on the resulting final SHA.
- Earlier candidate origin: `031df35710ab2c6015efb1acd1e65154dbcd3f24`.
- Pinned upstream: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`; independently check whether upstream has moved, **do not perform an upstream merge**.
- Genuine green CI: https://github.com/davidpovarsky/Maktabah/actions/runs/40233963450 ; Xcode 27, all six jobs successful, `208 of 208 assertions passed`, **16 XCUITest cases executed, zero failures**. This run tested `dc8dfdd2`, not an independently approved production release.
- Previous historical TestFlight Build 8401: https://github.com/davidpovarsky/Maktabah/actions/runs/40179808443 ; do **not** present this as the new repair release.
- The XCUITest base `Maktabah-iOSUITests/MaktabahUITestBase.swift` **currently always injects** `-OtzariaDataProfile miniTest10`, `-smokeBypassBootstrap`, `-smokeScenario`, and `-smokeBackend`. The simulator workflow also forces `OTZARIA_DEFAULT_DATA_PROFILE=miniTest10` and patches the simulator app's `Info.plist`. No existing green simulator UI test proves the normal production bootstrap.
- `Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift`: resolution precedence = launch argument, then environment, then embedded `OtzariaDefaultDataProfile`, then fallback `production`. Beware: a "production" build can still execute as miniTest10 if the test harness passes an override.
- `Maktabah.xcodeproj/project.pbxproj` currently has `OTZARIA_DEFAULT_DATA_PROFILE = production` in the relevant release/build settings. Signed release workflow `.github/workflows/ios-testflight.yml` accepts `data_profile=production` and `upload_to_testflight=true`, targets `xcode-27`, validates signing/entitlements and IPA, uploads, then waits for Apple processing.
- Official Otzaria library release verified on 2026-10-25: `Otzaria/SeforimLibrary` tag `v32-20261010190601`, asset `seforim-schema6.db.zst`, compressed size **1,850,679,582 bytes**, SHA-256 **`6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`**. Re-query the release and resolve expected digest before testing; never silently swap in a mini or stale database. The production database is normally **downloaded/reused on device, not bundled in the IPA**.
- `Scripts/CI/verify-upstream-boundary.py --base 031df35710ab2c6015efb1acd1e65154dbcd3f24 --head HEAD --upstream-ref a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` **currently reports FAIL** for protected upstream changes, including unapproved changes. `MAKTABAH_OWNER_VERIFICATION_KEY` has not been configured in the observed approval environment. Neither the existing `maktabah-batch-b-validation.yml` nor `ios-testflight.yml` was found invoking this upstream guard. **A green build is not a green owner-approval gate.**
- Existing 12 protected-patch proposals are in `docs/architecture/build-8401-patches/` and `docs/architecture/BUILD_8401_PROTECTED_HUNK_APPROVAL_PACKAGE.md`. **Critically, `Source/UI/iOS/Views/iOSMainView.swift` was changed in the candidate** for accessibility IDs and `searchOpen` tab selection, **but is not one of those 12 patch targets**. The exact current upstream-owned change inventory, not the number "12", is the source of truth.

### Absolute protection rules

- **Never alter** `C:\Users\DAVID\Code\Maktabah`, `C:\Users\DAVID\Code\Maktabah-v42-integration` (`sync/upstream-v42-full-integration`), or the separate `Maktabah-signing` and `maktabah-torah-photo-study` worktrees. Do not reset, clean, stash or rebase their users' changes.
- Do not create subagents. Do not change Git identity or security settings. No main/dev/upstream-integration merge. No App Store publication or external testers. No changes to Asana unless the owner separately asks for an Asana update/sync.
- Preserve original Maktabah UI/layout/reader, search and iPad behavior. Put new business logic and test helpers in downstream namespaces. Keep protected upstream edits to owner-approved minimum hooks and record all exact changed hunks. Read `AGENTS.md`, `PROJECT_AGENT_GUIDANCE.md`, `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`, `UPSTREAM_EXCEPTION_REGISTER.*`, `UPSTREAM_LEGACY_DEBT.md`, and the three user's Otzaria-project rule documents before changing code.
- Work in the isolated candidate, or a fresh child worktree of it. Take a pre-edit inventory of branch, SHA, Git status, remote tracking SHA, changed-path ownership and baseline. Never overwrite unrelated uncommitted files. Use one reviewed final SHA for required tests and the signed release.

## 1. Fix the **test truthfulness** defect: 16 passing tests are not 16 end-to-end proofs

The following are **code-confirmed gaps**. Fix them at their named sources; investigate application behavior only when a strengthened test actually fails. Maintain an acceptance manifest mapping each scenario to an interaction, a **real observable value**, an expected result, and an xcresult attachment. A test must fail if the relevant behavior is broken.

### 1A. Search highlighting must be verified in the **actually rendered attributed text**, not inferred from the X button

**Current test:** `Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift::testA1_A2_SearchResultHighlightAndClearButton` launches `searchOpen` (which itself programmatically calls `unifiedSearchSession.openResult(...)` in `Source/UI/iOS/Views/iOSMainView.swift`) and checks only `reader-surface` and `reader.clear_search_highlight_button` existence/disappearance. It does **not** assert that the selected words have visible highlighted attributed ranges or that a user tapped a search result in the UI.

**Implement:**
1. Add a separate true search flow test: launch into regular UI, open Search, enter a known Hebrew term, await real results, tap an actual result row, verify selected work/section/segment, selected range and scroll/focus. Choose deterministic known content in Sefaria, and also a full Otzaria production case in the separate production suite. `searchOpen` may remain a **smoke fixture only**.
2. Derive a read-only `#if DEBUG` accessibility/diagnostics snapshot directly **from the final on-screen `UITextView.attributedText`**, after `iOSIbarotTextView` has rendered and committed it. It must expose whether **actual** `.backgroundColor` or the precise highlight attribute used by `highlightSearchText` appears in nonempty ranges, with color, UTF-16 range, provenance (`search` vs persistent annotation), actual loaded locator and render generation. Do **not** use ViewModel fields as a proxy, fake an overlay, hard-code a PASS flag or expose user note text. Put processing in a downstream helper (for example `Source/ChavrusaText/Testing/ReaderRenderedHighlightInspector.swift`) with only an owner-approved tiny UIKit attachment point, or use an existing public hook if possible.
3. XCUITest must check search-marked glyph ranges count > 0 and color/appearance matching expected visible search highlighting, then tap `reader.clear_search_highlight_button` and verify the **actual rendered search highlight count returns to zero** and X disappears. Persistent annotations must remain unchanged. Repeat for two hits on the same page and after a page/render-cache update. Test search highlight with Hebrew niqqud/RTL/UTF-16 and on both backends as appropriate.
4. Test ordinary linked commentary/user selection: X must be absent even when focus/selection exists. Test programmatic scrolling does not clear X, while real manual scrolling beyond threshold follows documented behavior.
5. Include screenshot/xcresult/UI hierarchy for the selected term before/after clearing. Do not claim color proven from X visibility alone.

**Relevant implementation sources:**
- `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` (`RenderCacheKey`, final `.attributedText`, `highlightSearchText`, `selectedSegmentRange`)
- `Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift`
- `Source/Features/Reader/ViewModel/Extensions/Reader+iOS.swift`
- `Source/Features/Reader/iOS/Toolbar/iOSReaderBottomToolbarView.swift`
- `Source/ZayitSearch/UnifiedSearchSessionController.swift`
- `Source/UI/iOS/Views/iOSMainView.swift` (smoke-only `searchOpen`)

### 1B. Paging must verify an actual section/folio **transition**, not only a stable reader

**Current gaps:** `Build8401SevenDefectsAcceptanceTests.testB1_B2_PagingTransitionsPreserveReaderStability` only checks that `readerSurface` still exists after `.swipeUp()`/`.swipeDown()`. In `PullNavigationAcceptanceTests.testPullNavigationCommitBothDirectionsWithoutDuplicates`, the exact `reader-current-locator` assertion is conditional (`if !initialLocator.isEmpty && currentLocator.exists`); it can be skipped silently, and there is no compulsory assertion of an intermediate **different** locator. Moreover, a simple swipe through mid-content is not necessarily a page-boundary pull gesture.

**Implement:**
1. Add canonical, non-empty and uniquely identified **current backend + workKey + section locator** read-only accessibility metadata from the actual reader state. Require presence before starting. Do not use only the book title (often unchanged over many pages).
2. Start from a known non-boundary unit (Sefaria `Berakhot 15b` is suitable where data is available; Otzaria choose a middle chapter/section present in verified production data). Confirm that `previous` and `next` locators are known expected values.
3. Move to the proper physical top/bottom boundary (using actual scrollView behavior), perform the correct threshold-passing gesture; wait for exact **next** or **previous** locator using an XCTest predicate, assert it changed, and assert corresponding text content changed to that unit. Reverse and assert exact original locator. Test toolbar arrows and gestures through their actual UI surfaces; don't invoke ViewModel methods directly in XCUITest.
4. Check one navigation per gesture (observe transition generations if needed), no jump to first section in Otzaria, no wraparound at boundaries, no skipped/duplicated page, correct top/bottom scroll alignment, no empty or stale header, and correct TOC after transition.
5. Cover rapid next/previous, superseded async loads, first/last units, subthreshold retreat, and backend switch during load. The 208 portable assertions can test algorithmic correctness; native tests must prove UX behavior.
6. Make a missing locator/expected dataset **fail**, never silently bypass an assertion. `sleep()` is not evidence of a completed transition; use state/locator expectations with timeouts and diagnostic capture.

**Relevant code:** `Maktabah-iOSUITests/PullNavigationAcceptanceTests.swift`, `.../Build8401SevenDefectsAcceptanceTests.swift`, `Source/ChavrusaText/Navigation/ReaderBackendPagingCoordinator.swift`, `Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift`, `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift`, `Reader+Navigation.swift`, `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift`.

### 1C. Settings Picker must be selected **and** the backend genuinely change

**Current gap:** `BackendTransitionAcceptanceTests.testBackendSwitchViaSettingsPickerUI` attempts `picker.adjust(toPickerWheelValue: "Otzaria")` or taps a label **inside an `if/else if`**, but if neither control exists it keeps going. It then checks only the existence of the Library tab. The `testRoundTripBackendSwitchPersistsTabs` test instead injects different `-smokeBackend` launch values; it does not prove real settings transitions or tabs persisted.

**Implement:**
1. Ensure `settings-library-source-picker` actually exists and is hittable. Inspect the real SwiftUI Picker representation on iPadOS 27 (segmented/menu/picker wheel, depending on rendered UI); choose the actual Otzaria option via ordinary XCTest user taps, and make absence/failure a **hard FAIL**. Remove all optional `if exists` branches around essential steps.
2. Capture the initial **actual backend identity**, the active book/session locator and 3 distinct open tabs with known books/scroll positions. Confirm the setting changes to `.otzaria` and actual Otzaria catalog/content loads; then switch back to `.sefaria` via Settings and verify all original tabs, selected tab, identities, scroll positions, notes and history. Do not simulate the actual transition with `-smokeBackend`, `BackendCoordinator.commit`, or relaunch arguments.
3. Provide stable, read-only accessibility values derived from `BackendCoordinator.shared.activeBackendID`, transitionPhase and the displayed source description. Verify `.preparing` then `.idle` (or an actually observed successful terminal state); ensure picker reflects the active source. Check error state/rollback on missing catalog, offline failure, rapid attempts. No phantom books.
4. If prerequisites such as Otzaria DB setup are missing, the test must explicitly report BLOCKED with data requirements, not PASS because the Library tab survived.
5. Keep synthetic smoke test `testBackendSwitchRegressionScenario` as a separate **unit/smoke** gate, with accurately named coverage; it is not proof of real switching.

**Relevant code:** `Maktabah-iOSUITests/BackendTransitionAcceptanceTests.swift`, `Source/Features/Setting/SettingsView.swift` (Picker `settings-library-source-picker`, `commitAsync`, `.disabled(isTransitioning)`), `Source/LibraryBackend/BackendCoordinator.swift`, `Source/UI/iOS/Managers/iOSNavigationManager.swift`, `Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift`.

### 1D. TOC test must check current selected row and correct auto-scroll

**Current gap:** `testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState` checks a search field exists and "No TOC" is absent. It does **not** assert that the current chapter/folio is selected, that selection changes when content changes, or that a temporarily loading TOC reaches a valid loaded state.

**Implement:**
1. Open a known multi-level TOC on Sefaria and a real production Otzaria book. Determine expected section/ancestor by structured `TextLocator` and real `TOCReadingLocationTracker`, not prefix matches or surrogate ID ordering.
2. On-screen `TOCNodeRow` / `iOSTOCView`: provide an accessible selected state (`.isSelected` trait or `value="selected"`), exact locator for the selected row, and id; driven by **actual view state**. No manually manufactured selection for tests.
3. With TOC visible, navigate through at least three known sections by reader gesture/toolbar and verify the selected row changes to the correct expected node and is `isHittable`/within visible scroll region following automatic scroll. Reopen TOC after deep-linked commentary; test deepest ancestor match.
4. For loading: use an intentionally delayed, valid backend response or controlled network fixture; assert initial loading spinner/progress, no premature empty/error message, then actual nonempty TOC rows. Separately test legitimate empty/error/offline outcomes and rapid switching between books (old response must not win).
5. Verify Hebrew chapter/folio labels inside the **TOC rows** (not just a Hebrew Library tab) and English labels under English locale.

**Relevant code:** `Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift`, `Source/Features/Reader/ViewModel/BookTOCViewModel.swift`, `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift`, `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift`, `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift`.

## 2. Add missing actual link, commentator and Hebrew-TOC acceptance

1. **Deep commentary link:** From a real reader/search/inspector UI, tap a real source link pointing to `Rashi on Berakhot 15b:3:1`; assert **entire `Rashi on Berakhot 15b` reading unit** loads (not a one-line/blank viewport), that neighboring segments on 15b are accessible, and that specific `3:1` focus lands on screen. From ordinary linked-source navigation the search X must not appear. Also test `Genesis 1:3` opens a whole chapter 1 with verse 3 focused and verses before/after accessible.
2. **Section boundary errors:** canonical-ref section ancestors must be validated against Sefaria type/schema; malformed refs fail visibly and preserve current reader. Verify Talmud, Tanakh, commentary, already-section refs and wrong-backend references.
3. **Hebrew TOC:** Navigate through chapter/folios inside actual Sefaria TOC. Assert `פרקים`, `דפים`, `פרשות` where semantically appropriate, plus explicit daf cases such as `י״ב ע״א`, `ט״ו ע״ב`, `ט״ז ע״א`; English locale must show suitable English labels (`Chapters`, `Folios`, `12a`, `15b`) in real TOC UI. Do not confuse History tab localization with Sefaria TOC localization.
4. **Annotation preservation:** `HighlightAnnotationAcceptanceTests.swift` now genuinely asserts note survival after relaunch — preserve that test. Improve its first-pass assertion: `createdNoteElement.waitForExistence` currently discards the result (`_ = ...`), while only post-relaunch matching is mandatory; make both pre/post saves mandatory. Verify annotation anchor/book identity and persistence across backend switching. Never rely on a Debug-only auto-opened `studyNotes` editor as the sole proof of normal user creation; add a real user-entry path test.
5. Full side-by-side proof: expected locator / actual locator / screenshot / debug-attributed-range diagnostics / xcresult name / PASS, FAIL or BLOCKED. Update `docs/qa/BUILD_8401_REGRESSION_TEST_MATRIX.md` with the 21 H1–H5, P1–P4, B1–B3, T1–T2, S1–S2, L1–L3, X1–X2 rows and newly added real-flow coverage. No row may move from `PASS_PORTABLE` to `PASS_NATIVE` merely from a green test with insufficient assertions.

## 3. Split the test harness into two independent tiers; production must **never** inherit mini flags

**Files:** `Maktabah-iOSUITests/MaktabahUITestBase.swift`, `.github/workflows/maktabah-batch-b-validation.yml`, and new `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift` or equivalent. Preserve existing smoke tests.

- **Tier S — fast smoke (existing behavior):** `miniTest10`, `-smokeScenario`, `-smokeBackend`, `-smokeBypassBootstrap`; every result labeled `PASS_SMOKE_MINI`, not real-production PASS.
- **Tier R — real user UI:** No `-smokeScenario`, no `-smokeBackend` to effect transitions, no `-smokeBypassBootstrap`. Run with a known prepared dataset and the genuine app bootstrap. Standard UI steps; require actual expected displayed state. May use controlled external test data/backend responses when documented, but not a direct coordinator commit in place of user action.
- **Tier P — full production Otzaria:** Effective `OtzariaDefaultDataProfile=production`; **no** launch/environment overrides to miniTest10; real official full SQLite library + matching search index (where needed), real catalog/reader/search/TOC/download-install/retention semantics, and actual Sefaria cloud/offline selection paths. Validate the data's schema, checksum, identity, index availability, end-to-end search and reader behaviors. Use a fresh simulator data container as well as a carefully controlled in-place upgrade case. No deleting the owner's installed data.
- Make profile selection an explicit input to the test launcher, **do not hard-code miniTest10 in the common base class**. Fail immediately if effective runtime profile differs from requested tier; assert both the built Info.plist and the runtime chosen `OtzariaDataProfileRegistry.activeProfileID` (precedence matters).
- Distinguish unit tests of the production resolver from true on-disk production acceptance. Download the 1.85GB compressed library at most once per controlled runner/cache where feasible; verify size/digest/schema and adequate decompression space before work. If the corpus is genuinely unavailable, mark Tier P `BLOCKED_DATA_UNAVAILABLE`, do not report full-production PASS and do not substitute a ten-book fixture under the production name. Use deterministic fixtures for corrupt archive, stale manifest, interrupted download, resume, cold catalog, offline behavior and storage error injections.
- Test **valid existing full DB reuse** after an app upgrade, without a redundant forced download; separate search-package status from core library presence. Also verify notes/bookmarks/tabs remain intact; no version downgrade or silent mini fallback.
- The official release tag/digest are facts from inspection time, not a permanently pinned universal constant: resolve latest official asset at execution, record its tag/version/size/digest and do not accept unverified replacements.
- Full library isn't embedded in IPA; verify download/reuse path in the installed app. Fail if runtime DB/search-index packages are incorrectly packed inside the IPA.
- Physical owner's iPad Pro acceptance is **after** internal TestFlight delivery. Mark this `OWNER_PHYSICAL_QA_PENDING` until the owner reports results; it is not evidence obtainable from a CI simulator.

## 4. CI pipeline: make each claim traceable to the exact SHA and its actual test suite

**Existing CI:** `.github/workflows/maktabah-batch-b-validation.yml`; test runner Xcode 27; separate Otzaria/Zayit frameworks + SwiftPM already exist. **Reuse them**, avoid unnecessary rebuilding and adding an unrelated new build system.

1. Inspect real `workflow_dispatch` schema and `xcodebuild -list/-showdestinations`; do not pass nonexistent `runner=` or `test_filter=` CLI inputs. Candidate branch does not match workflow's existing `push` branch filter (`validation/maktabah-batch-b-*`), so dispatch manually with `gh workflow run maktabah-batch-b-validation.yml --repo davidpovarsky/Maktabah --ref <CANDIDATE_BRANCH>` if authorized.
2. Add fail-closed required jobs for Tier R and production Tier P acceptance with **separate** `.xcresult`, build logs and artifacts. Tier S may run separately. Test suites must explicitly list all required test names and affirm expected test count; no silent test discovery drops, skips, retries-only-good-tests, `continue-on-error` or `|| true` masking.
3. Existing local component suite is 208/208 across 20 suites. Retain all tests, add focused tests where needed. Run full Debug iPad simulator, Release generic iphoneos compile, XCTest and real XCUITest. Keep build cache/SwiftPM/XCFramework integrity. Native debug build and non-signed Release compile **are not signed distribution validation**.
4. Add a check mapping each XCUITest row to its actual assertion evidence and any relevant screenshot/recorded diagnostic. In CI summary, expose separately the counts `SMOKE_MINI`, `REAL_USER`, `PRODUCTION_FULL` and `BLOCKED/NOT_RUN`; a total such as "16/16" without scope is inadequate.
5. Preserve `.xcresult`, relevant video/screenshot attachments, diagnostics, source/profile manifests, app/runtime profile and SHA. Artifacts must be available even on failure. Remove any optional steps that hide test failures, not unrelated noncritical Live Activity notification refreshes.
6. Freeze candidate at a single final code/docs/workflow commit. Run fresh complete CI **on that exact SHA**, not solely on the historical `dc8dfdd2` run. Verify GitHub run `headSha` equals `git rev-parse HEAD` and remote `git ls-remote` at dispatch, and that all expected tests ran. Any further code/workflow change invalidates the prior final SHA and requires rerunning affected gates.
7. Write an honest failure matrix: `PASS_PORTABLE`, `PASS_SMOKE_MINI`, `PASS_REAL_UI`, `PASS_FULL_PRODUCTION`, `FAIL`, `BLOCKED`, `NOT_RUN`, `OWNER_DEVICE_PENDING`. Tests requiring data must fail/flag blocked when data unavailable, not silently pass.

## 5. Close upstream-owned change inventory; don't accept the previous "12 patches" as complete

**Known exact gap:** `Source/UI/iOS/Views/iOSMainView.swift` changed three spots relative to baseline: `settings-done-button` accessibility ID, `main-settings-button` accessibility ID, and `selectedTab = .viewer` in DEBUG `searchOpen`. This is absent from the 12-patch list. `git diff --name-status 031df35710... HEAD -- Source/Features Source/UI Maktabah.xcodeproj/project.pbxproj` showed **13 changed protected-origin paths**; enumerate from Git, not from package labels. Minimize or move smoke-only UI changes into a downstream test harness where feasible; otherwise require genuine owner approval for their exact hunks.

1. Inventory **every** modified/added/deleted/renamed path against the pinned upstream origin and baseline, classify owner (UPSTREAM_OWNED / DOWNSTREAM_OWNED / SHARED_SEAM / VENDORED / UNKNOWN), and diff final exact hunks. Check package/project target registrations, workflow changes and even modifications not flagged by the existing checker.
2. Read the full `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`, `UPSTREAM_EXCEPTION_REGISTER.json`, `BUILD_8401_PROTECTED_HUNK_APPROVAL_PACKAGE.md`, and `BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json`. The old dossier's 12 exact patch hashes represent an **earlier candidate**, not automatic approval for any new hunk. Track all old Batch B pending exceptions by path/hunk as well; do not duplicate or silently supersede them.
3. For all protected hunks, produce owner-review-ready records: exact relative path; upstream/base blob SHA; proposed resulting blob SHA; actual canonical diff SHA-256; rationale; downstream alternative tried; minimal hook; regressions/collision risk; test IDs + result links; rollback patch; approval reference and status. Recompute **from the final tree**; reconcile patch bundle/manifest/approval document byte-for-byte with candidate, including newly discovered `iOSMainView.swift`. Preserve reproducibility on a separate **clean checkout**, both patch application and rollback.
4. Re-run `python3 Scripts/CI/verify-upstream-boundary.py --base <PINNED_CANDIDATE_BASE> --head HEAD --upstream-ref <PINNED_UPSTREAM_SHA>` and store full JSON/report. Current outcome is **FAIL / OWNER_APPROVAL_REQUIRED**. Do not call it PASS just because release compile and 16/16 XCUITest passed.
5. The project's guard uses a trusted **Ed25519 owner-attestation** mechanism (including a trusted owner public verification key, currently not configured in the observed gate). **Do not generate or substitute an owner private key, self-approve, disable checks, supply a local unsafe exception register, modify signatures, or treat this prompt as a signed exception.** Owner must review exact final hunks and use a genuine trusted approval process/key; request the required owner action explicitly once the final diff is stable.
6. If architecture review identifies changes that can be moved fully into downstream, refactor them before preparing the final approval package. Do not create fresh upstream modifications to simplify tests without recording/authorizing them.

## 6. Enforce an actual cryptographic approval and exact-SHA release gate in CI

**Critical verified defect:** the green validation run checked compilation and tests, but the existing `.github/workflows/maktabah-batch-b-validation.yml` and `.github/workflows/ios-testflight.yml` do **not** invoke `verify-upstream-boundary.py`. Therefore a green GitHub run does NOT imply protected ownership compliance.

- Design a reusable fail-closed validation script/job that invokes the existing `Scripts/CI/verify-upstream-boundary.py` in **production/trusted mode** against the correct pinned base/upstream and final candidate SHA. Pin the trusted owner public verification key via the authorized source, never a candidate-provided unsafe override. Check the required approvals against the **actual modified final diff**. Missing key/approval = FAIL, not warning; invalid/expired/mismatched signature = FAIL.
- Add mandatory gate to **`.github/workflows/ios-testflight.yml` before code signing, archive, export or upload**. The release dispatch must take/verify the expected immutable candidate SHA, compare it with checked-out `git rev-parse HEAD`, and verify successful full required native CI for that exact SHA. Confirm `data_profile=production` (reject `miniTest10` for THIS release), all 21-row acceptance evidence and required Tier P result. Do not rely on branch names, earlier green jobs or mere presence of an approval document.
- The candidate test pipeline may run and produce evidence **before** approvals; its protected-policy job must accurately report FAIL/BLOCKED until legitimate owner approval. Do not mask it or use tests-only green as a release approval. A release workflow must never proceed on this known failure.
- Validate negative cases on a **non-release dry run**: missing owner key, expired signature, altered protected hunk, unrelated SHA, wrong data profile, missing CI evidence and invalid approval. Each must abort **before** signing/upload. These checks are security tests; do not dispatch a real signing run to test a failure path.
- Protect the guard and policy code as critical inputs themselves; an untrusted candidate commit must not be able to change the validator or trusted approval source to weaken the gate. Use a trusted pinned version/ref of the guard, verified checksum or a protected workflow mechanism appropriate to this repo's governance. Do not let candidate-supplied YAML alone declare itself approved; verify the trust root from an owner-controlled location.
- Store the gate attestation/report and resulting verified candidate SHA as CI artifacts. Do not print signing secrets or raw private keys. Treat GitHub Actions notification helper failures as noncritical but test/signing/gate failures as blocking.

## 7. Production TestFlight build — **conditional**, never bypass approval

Once **all** mandatory pre-release gates legitimately PASS and the owner has approved the **exact final protected hunks using the trusted process**, do all of the following. This document is an engineering task specification, **not** an Ed25519 attestation or permission to fabricate one.

1. Freeze one candidate commit; update and verify remote SHA. If final release gate edits changed SHA, rerun the required final CI on that SHA.
2. Use the already existing `.github/workflows/ios-testflight.yml`, runner `xcode-27` and existing Apple credentials/provisioning/entitlement verification. Avoid creating a parallel, less-safe signer. Dispatch only from the approved, tested SHA/branch with the **actual defined inputs**:
   ```bash
   gh workflow run ios-testflight.yml --repo davidpovarsky/Maktabah --ref validation/maktabah-build-8401-repair-production-20261025 -f data_profile=production -f upload_to_testflight=true
   ```
   If you add a required `expected_sha` workflow input as part of the trusted gate, supply the exact approved SHA as well, and confirm the run checkout SHA equals it. This CLI is **not to be run before approval**.
3. Verify release artifacts: Xcode 27, build number unique for `1.0.0`, signed Apple Distribution provisioning/entitlements, app bundle ID `com.davidpovarsky.chavrusatext`, display name `ChavrusaText`, Info.plist `OtzariaDefaultDataProfile=production`, **no** `-smoke*` runtime overrides, no mini profile. Capture IPA SHA-256, archive logs and signed embedded Info.plist evidence. Ensure no `seforim.db`, `lexical.db` or huge search DB has been embedded in the IPA.
4. Verify official full Otzaria DB runtime download/reuse after install. In-place upgrade from historical Build 8401 must preserve installed full DB, downloaded content, personal annotations, tab/session locations and settings. Do not delete/reinstall the user's app during testing without specific owner approval.
5. Verify `xcrun altool` validation/upload of the **new** IPA and `Scripts/CI/wait-for-testflight-build.py` success for its precise version+build; confirm App Store Connect `processingState=VALID`, beta visible to existing **internal** testers, and no accidental App Store/external tester publication.
6. Provide final run URL, version/build number, source SHA, IPA SHA, signed profile, Apple VALID timestamp and internal tester availability. Mark physical owner device tests `PENDING` until owner performs them. If Apple processing fails, diagnose and rerun only with a new validated SHA/build; no false success.
7. If approval, production data, signing or exact-SHA validation remains missing, **STOP AT THAT GATE**. Deliver the complete actionable approval/blocker report and safe candidate evidence. Do not silently ship miniTest10 or remove gates.

## 8. Required coverage map: no false PASS from test names

| Scenario | Existing test's real verified assertion | New mandatory evidence to add |
|---|---|---|
| Search result + X | X appears/disappears in `searchOpen` debug scenario | User-tapped result; real attributed highlight color/ranges before and zero after X, same-tab second hit, cache rebuild |
| Linked source no X | Ordinary reader has no X | Linked Rashi navigation with segment focus but no search provenance/X |
| Bidirectional paging | Reader surface stays present; optional locator checks | Nonempty required locator **changes to expected next/previous**, content and TOC change, returns exactly; Otzaria real corpus |
| Backend switching via settings | Picker interaction is optional, Library tab exists | Picker MUST be tapped, actual backend setting/catalog changes, 3 tabs/scroll/notes restored, rollback test |
| TOC tracking | Search field present, no empty message at one instant | Actual selected correct row, scroll-to-visible and ancestor selection across multiple pages; delayed loading to nonempty |
| Deep Rashi/Genesis | Portable resolver tests only | Native click to full 15b daf/chapter and exact focused segment, adjacent content visible |
| Hebrew Sefaria TOC | Hebrew library tab and nonempty reader title | Specific Hebrew structural/daf labels in real TOC, English counterpart and RTL/LTR |
| Annotation persistence | Unique note asserted post-relaunch | Require pre-relaunch presence too; actual selection anchor and normal user note entry |
| Full Otzaria production | Mini smoke + unsigned production Release compile | Runtime profile production, full database presence/schema/catalog/search/TOC, valid DB reuse and in-place upgrade |
| Integrity / release | 16/16 CI pass; guard separately fails | Trusted approval/hunk inventory + guard PASS; same SHA validated and signed, Apple VALID |

**21-row matrix:** `H1–H5, P1–P4, B1–B3, T1–T2, S1–S2, L1–L3, X1–X2` in `docs/qa/BUILD_8401_REGRESSION_TEST_MATRIX.md`; explicitly map each row to exact portable, smoke, native, production or owner-device evidence. If no adequate check exists, status = `NOT_RUN` or `BLOCKED`, not PASS. Include negative tests that fail if the behavior is deliberately broken.

## 9. Suggested exact file change plan (modify only when needed and permitted)

**Tests (downstream/test code, first priority):**
- `Maktabah-iOSUITests/MaktabahUITestBase.swift`: separate smoke vs true real-user vs production launch; effective runtime profile checks; required accessibility helper/assertion methods; deterministic data readiness.
- `Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift`: replace surface-only assertions with real search/render, section/locator paging, TOC and Hebrew TOC checks; add Rashi link tests (or new dedicated class).
- `Maktabah-iOSUITests/BackendTransitionAcceptanceTests.swift`: remove optional Picker/no-op success; real in-Settings switches, active identity and 3-tab exact restore checks, errors/rollback.
- `Maktabah-iOSUITests/PullNavigationAcceptanceTests.swift`: require nonempty current-locator, intermediate expected locator and exact reverse; true threshold gestures at boundaries.
- `Maktabah-iOSUITests/HighlightAnnotationAcceptanceTests.swift`: require note visible **before** relaunch and afterward; test real user note creation and anchor.
- Add `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift` and `Maktabah-iOSUITests/DeepLinkedCommentaryAcceptanceTests.swift` if appropriate.

**Downstream test observability/adapters (prefer these):**
- `Source/ChavrusaText/Testing/ReaderRenderedHighlightInspector.swift` for debug-only snapshots of actual attributed-text state; existing `Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift`, `ReaderDestinationResolver.swift`, `ReaderBackendPagingCoordinator.swift`, `TOCReadingLocationTracker.swift` for state evidence/necessary bug fixes only.
- Adapt existing `Source/LibraryBackend/` / `Source/Otzaria/` profile, storage and release validator diagnostics without introducing an alternative app UI. For full production, test real `OtzariaDatabaseBootstrapService`, release client, storage and migration paths.

**Upstream-owned integration seams (approval REQUIRED for any new exact diff):**
- `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` for minimal read-only attributed-text snapshot attachment, if unavoidable.
- `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` / `Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift` / `TOCNodeRow.swift` for minimal genuine accessibility state, if needed.
- `Source/Features/Setting/SettingsView.swift` for Picker/active backend accessibility, if needed.
- `Source/UI/iOS/Views/iOSMainView.swift`: reconcile **existing unlisted** modified hunks, and avoid perpetuating a smoke-only upstream alteration unless approved.
- `Maktabah.xcodeproj/project.pbxproj`: include test source membership and required target registration; exact approval dossier for protected changes.

**CI / release:**
- `.github/workflows/maktabah-batch-b-validation.yml`: explicit suite tiers, fail-closed test count, production data gate, xcresult and integrity status reporting.
- `.github/workflows/ios-testflight.yml`: mandatory trusted guard before signing/upload, final SHA + profile + passed-CI matching, signed IPA proofs.
- Reuse, do not weaken, `Scripts/CI/verify-upstream-boundary.py`; any change to guard requires independent protected-owner review.
- Update approval/manifest/QA report under `docs/architecture/` and `docs/qa/`, recompute checksums and verify from a clean checkout.

## 10. Execution sequence and stop conditions

**Phase A — Record baseline:** Immutable branch/HEAD/remote, target ownership matrix, existing green run artifacts and actual guard FAIL. Save read-only snapshots.  
**Phase B — Make tests truthful:** Fix exact false-positive XCUITests; add genuinely observable reader/TOC/highlight/backend state (only minimal approved hook); add deep-link tests. Check that deliberately broken behavior makes the test fail.  
**Phase C — Correct real code bugs exposed:** Fix downstream-first, only when evidence demonstrates actual behavior failure. Test repeatability, race order, offline and performance.  
**Phase D — Full production validation:** Split Tier S/R/P; validate production asset/reuse/upgrade/corpus and zero mini fallback.  
**Phase E — Protected review dossier:** Complete all exact protected paths including `iOSMainView.swift`; clean reproducible patches/manifest; requested owner approval/attestation.  
**Phase F — Final SHA CI:** Run full Xcode 27 compile, component tests, real UI and production suite; report exact case names and xcresults. Keep trusted protection gate visible; it may remain FAIL until owner approval.  
**Phase G — Owner gate:** Obtain authentic exact-hunk owner permission and trusted Ed25519 attestation; never self-approve. Re-run the genuine guard and final SHA CI as required.  
**Phase H — Conditional TestFlight:** Only after approvals and all pre-release gates pass: invoke existing signed **production** `ios-testflight.yml`, verify Apple VALID and internal beta. Leave physical iPad acceptance for owner.

Do not stop merely on another green mini/smoke test. Do not ask the owner to re-specify already known requirements. If a gate is technically or organizationally blocked, finish all independently permitted work first; present a specific blocker with exact required owner action. Never present blocked or skipped tests as successful.

## 11. Final report and acceptance criteria

A single final `docs/qa/BUILD_8401_FINAL_PRODUCTION_TESTFLIGHT_ACCEPTANCE.md` containing:

1. Baseline, final candidate branch/HEAD/remote SHA, tested CI run and signed release run exact `headSha`.
2. File-by-file change inventory with ownership, exact protected patches, signed approval references or `OWNER_APPROVAL_REQUIRED` blockers.
3. Matrix of 21+ scenarios with actual test name, real UI steps, expected and actual locator/content/highlight/selected TOC, `PASS_PORTABLE | PASS_SMOKE_MINI | PASS_REAL_UI | PASS_FULL_PRODUCTION | FAIL | NOT_RUN | BLOCKED | OWNER_DEVICE_PENDING`, xcresult attachment.
4. Exact totals for 208+ portable, original 16 plus added strengthened UI tests, test count and failure/skip counts; don't claim all seven fixed if the actual behavior was never asserted.
5. Official production DB tag/asset/schema/size/digest, installed profile and runtime override evidence, upgrade/no-redownload/retention tests; data missing or untested stated prominently.
6. Cryptographic guard result and trusted key availability, exact list of unapproved upstream files, additional `iOSMainView.swift` and any new changes; security negative tests.
7. Signed IPA SHA, bundle/version/build, Apple Distribution signature/entitlements, `production` Info.plist, App Store Connect upload/Apple `VALID`, internal testers; or precise `NOT_UPLOADED_BLOCKED` status.
8. Rollback, remaining risks and the one next owner action if any. No fabricated green approvals, no Asana changes, no merges.

**Success means an actual internal TestFlight production beta with a credible verified functional surface and genuine protected-hunk approval, not just green compilation.** Physical iPad validation remains a separate required final owner acceptance step.