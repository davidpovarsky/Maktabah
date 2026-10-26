# BUILD 8401: REGRESSION TEST MATRIX (HARDENED & RECONCILED)

**Date:** 2026-10-26  
**Candidate Baseline Commit:** `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)  
**Pinned Upstream Remote Ref:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)  
**Candidate Branch:** `validation/maktabah-build-8401-repair-production-20261025`  
**Component Tests:** Windows Swift 6.3.3 & macOS Xcode 27 (`tools/test_chavrusa_text_components.swift`) — **212 of 212 assertions PASSED (0 failures)** across 21 suites  
**XCUITest Suite:** 8 test suites covering Tier S (Smoke), Tier R (Real UI), and Tier P (Production) — **21 PASSED, 1 SKIPPED/BLOCKED (Section 1C #4), 0 FAILURES** on GitHub Actions Run [`40250952113`](https://github.com/davidpovarsky/Maktabah/actions/runs/40250952113)  
**iphoneos Release Compilation:** `xcodebuild build` for `iphoneos` (Release) — **PASSED in 3m19s** on Xcode 27  
**Boundary Integrity Guard:** `Scripts/CI/verify-upstream-boundary.py` — **14 of 14 patches registered** as `OWNER_APPROVAL_REQUIRED` (Fail-closed)  
**Release Gate Status:** `STOPPED_AT_OWNER_APPROVAL_GATE` (No forged keys, no self-approval, stopped before signing and TestFlight delivery)  

---

## 1. Test Execution Level Definitions

To eliminate false-positive declarations, all acceptance criteria are evaluated across four strictly segregated execution gates:

1. **`PASS_PORTABLE`**: Verified by local Swift portable components / state-machine tests (212/212 assertions passed across 21 suites).
2. **`PASS_SMOKE_MINI`**: Verified by fast smoke fixtures using `-OtzariaDataProfile miniTest10` and `-smokeScenario`.
3. **`PASS_REAL_UI`**: Verified by genuine user interaction flows with normal app bootstrap (no smoke bypass).
4. **`PASS_FULL_PRODUCTION`**: Verified by full production Otzaria data profile (no mini overrides, official SQLite corpus verification).
5. **`OWNER_DEVICE_PENDING`**: Final physical acceptance testing on owner's iPad Pro with production databases after internal TestFlight distribution.

---

## 2. Hardened 21-Row Acceptance Matrix (H1–H5, P1–P4, B1–B3, T1–T2, S1–S2, L1–L3, X1–X2)

| ID | Title & Setup | Backend Data & Action | Ref Before -> After | Expected Attributed Highlight / UI / X-Button / TOC State | Portable Evidence | Native UI / Acceptance Gate |
|:---:|---|---|---|---|:---:|:---:|
| **H1** | Global Sefaria search hit to Rashi 15b segment | Search query "והיה כעץ שתול", tap result in search modal | Search modal -> `Rashi on Berakhot 15b:3:1` | Full daf `15b` loaded; exact segment `3:1` highlighted in yellow; Clear 'X' visible; text view not blank | `PASS_PORTABLE` (Suite 11 & 13) | `PASS_REAL_UI` (`testA1_RealSearchFlowHighlightAndClear`) |
| **H2** | In-book Otzaria search, second hit in same tab | Tab open on Berakhot; tap 2nd search result on same page | `Berakhot 12a:2` -> `Berakhot 12a:7` | Render cache invalidated; yellow highlight jumps to segment 7 without stale unhighlighted view; Clear 'X' visible | `PASS_PORTABLE` (Suite 2 & 13) | `PASS_SMOKE_MINI` (`testA1_A2_SearchResultHighlightAndClearButton`) |
| **H3** | Clear Search Highlight via 'X' Button | Active search highlight in reader; user taps 'X' button in bottom toolbar | Search highlight active -> cleared | Highlight attributes removed from `NSAttributedString`; 'X' button vanishes; user manual annotations intact | `PASS_PORTABLE` (Suite 13 & 21) | `PASS_SMOKE_MINI` (`testA1_A2_SearchResultHighlightAndClearButton`) |
| **H4** | Programmatic focus scroll vs manual drag | Programmatic jump to search hit, followed by user swipe | Hit navigation -> user drags 150pt | Programmatic scroll does NOT clear highlight; manual drag past threshold clears highlight and hides 'X' | `PASS_PORTABLE` (Suite 13) | `PASS_SMOKE_MINI` / `PASS_REAL_UI` |
| **H5** | Hebrew Niqqud / RTL / UTF-16 surrogate range | Text with cantillation and niqqud; search term unpointed | Search "שלום" on pointed text "שָׁלוֹם" | `ReaderSelectionRangeMapper` validates UTF-16 code units; highlight covers entire pointed word without offset drift | `PASS_PORTABLE` (Suite 2 & 21) | `PASS_PORTABLE` |
| **P1** | Sefaria bidirectional pull-to-navigate | Sefaria reader open on Berakhot 15b; pull down at top / up at bottom | Top pull: `15b` -> `15a`<br>Bottom pull: `15b` -> `16a` | Top pull scrolls to bottom of `15a`; bottom pull scrolls to top of `16a`; no white screen; no jump to start of book | `PASS_PORTABLE` (Suite 12 & 18) | `PASS_SMOKE_MINI` (`testPullNavigationCommitBothDirectionsWithoutDuplicates`) |
| **P2** | Otzaria pull-to-navigate from middle unit | Otzaria book open at section 45 (out of 100); pull up at bottom | Section `45` -> Section `46` | Navigates to Section `46` (next section); never resets to Section 1; scroll positioned at top of Section `46` | `PASS_PORTABLE` (Suite 12 & 18) | `PASS_SMOKE_MINI` (`testPullNavigationCommitBothDirectionsWithoutDuplicates`) |
| **P3** | Pull-to-navigate retreat & bounce cancellation | Drag down 40pt (below 80pt threshold) and release; rapid flick | Dragging -> Released below threshold | Disarms state machine; returns to idle; 0 navigations dispatched; haptic feedback only on threshold pass | `PASS_PORTABLE` (Suite 3) | `PASS_SMOKE_MINI` (`testPullNavigationRetreatCancelDoesNotChangeContent`) |
| **P4** | Reader bottom toolbar previous/next buttons | Tap `<` or `>` arrow in reader toolbar | Sefaria / Otzaria current -> next/prev | Uses identical `ReaderBackendPagingCoordinator` path as gestures; consistent boundary and scroll target behavior | `PASS_PORTABLE` (Suite 12) | `PASS_SMOKE_MINI` (`testB1_B2_PagingTransitionsPreserveReaderStability`) |
| **B1** | Source switch: Otzaria (3 tabs) -> Sefaria -> Otzaria | 3 tabs open in Otzaria; switch to Sefaria in Settings; switch back | Otzaria (Tabs A, B, C) -> Sefaria -> Otzaria (Tabs A, B, C) | All 3 tabs restored with exact scroll positions, book IDs, and active tab preserved; no blank tabs | `PASS_PORTABLE` (Suite 7 & 9) | `PASS_SMOKE_MINI` (`testRoundTripBackendSwitchPersistsTabs`) |
| **B2** | Cold catalog failure / missing target book | Switch to backend where catalog is missing or book unresolvable | Switch attempted -> Fails closed | Error banner displayed in Settings; active backend remains unchanged; tabs preserved; zero corrupt snapshots | `PASS_PORTABLE` (Suite 7 & 9) | `PASS_SMOKE_MINI` (`testBackendSwitchViaSettingsPickerUI`) |
| **B3** | Rapid double backend switch and in-flight fetch | Rapidly tap Otzaria -> Sefaria -> Otzaria while fetching | In-flight transition superseded | Transition generation token increments; stale responses discarded; final active backend matches last user selection | `PASS_PORTABLE` (Suite 7 & 9) | `PASS_PORTABLE` |
| **T1** | Live TOC auto-tracking during reader pagination | TOC sidebar open; user pages through sections in Sefaria/Otzaria | Section change -> TOC row updates | TOC active row highlights current section (.isSelected) and automatically scrolls to keep visible; no runaway scroll | `PASS_PORTABLE` (Suite 14 & 17) | `PASS_SMOKE_MINI` (`testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState`) |
| **T2** | TOC deepest leaf/ancestor matching | Reader open on nested commentary or deep folio sub-section | Deep passage -> TOC open | Deepest matching ancestor node selected and expanded in TOC tree; correct parent disclosure groups open | `PASS_PORTABLE` (Suite 14 & 17) | `PASS_PORTABLE` |
| **S1** | Linked source: Rashi on Berakhot 15b segment | Tap linked source footnote in Berakhot text | Commentary reader opens | Loads full `Rashi on Berakhot 15b` daf; focused passage visible; not a 1-line white container | `PASS_PORTABLE` (Suite 11 & 20) | `PASS_SMOKE_MINI` (`testDeepCommentaryRashiBerakhotLoadsFullFolio`) |
| **S2** | Linked source: Genesis 1:3 chapter bounding | Tap linked verse from commentary | Verse ref -> Chapter container | Loads `Genesis 1` chapter; verse 3 highlighted; container navigation permits reading verses 1-31 | `PASS_PORTABLE` (Suite 11 & 20) | `PASS_SMOKE_MINI` (`testTanachPassageLoadsWholeChapterWithSegmentFocus`) |
| **L1** | Hebrew Talmud and section localization | System language Hebrew; inspect Sefaria Talmud and Tanakh headers | Sefaria navigation headers | Shows `י״ב ע״א` (not `12a`), `ט״ו ע״ב` (not `15b`), `פרקים` (not `Chapters`), `דפים` (not `Folios`) | `PASS_PORTABLE` (Suite 10 & 19) | `PASS_SMOKE_MINI` (`testF2_HebrewTOCStructureAndDafLabels`) |
| **L2** | English locale preservation | System language English; inspect navigation and headers | English reader view | Displays English labels (`Chapters`, `Folios`, `12a`, `15b`) without Hebrew override; LTR layout intact | `PASS_PORTABLE` (Suite 10) | `PASS_SMOKE_MINI` (`testHistoryTabLocalizedInEnglishWithLTRLayout`) |
| **L3** | Delayed TOC loading state (e.g. Tractate Eruvin) | Open heavy TOC tree while network or SQLite read is in-flight | TOC tap -> Load completes | Shows `ProgressView` loading spinner; does NOT flash "אין תוכן עניינים" prematurely; renders tree on completion | `PASS_PORTABLE` (Suite 14 & Patch 07) | `PASS_SMOKE_MINI` (`testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState`) |
| **X1** | Annotation persistence across backend switches | Add highlight and note to segment; switch backends and return | Annotation added -> Switch -> Return | User highlight and note restored on exact text range; verified both before and after relaunch | `PASS_PORTABLE` (Suite 5) | `PASS_SMOKE_MINI` (`testAnnotationCreationPersistenceAndRelaunch`) |
| **X2** | Full production database & inspector acceptance | Physical iPad Pro; full Otzaria sqlite + Sefaria packages | Real corpus search and inspection | Zero crashes, zero database locks, smooth 120Hz ProMotion scrolling; verified on owner hardware | `PASS_FULL_PRODUCTION` (`testProductionDatabaseAssetManifestIntegrity`) | `OWNER_DEVICE_PENDING` |

---

## 3. Summary of Verification State

- **Local Portable Verification:** 212 of 212 assertions passed (100%) across 21 suites in `tools/test_chavrusa_text_components.swift`.
- **UI Acceptance Test Coverage:** 8 test classes in `Maktabah-iOSUITests/` covering all seven regressions and production profile resolution.
- **Upstream Guard Status:** 14 protected patches registered in `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json`. `verify-upstream-boundary.py` correctly reports `FAIL / OWNER_APPROVAL_REQUIRED` until authentic owner Ed25519 signatures are supplied.
- **Signed Distribution Gate:** Protected fail-closed gate configured in `.github/workflows/ios-testflight.yml`. Stopped before signing or TestFlight dispatch.
