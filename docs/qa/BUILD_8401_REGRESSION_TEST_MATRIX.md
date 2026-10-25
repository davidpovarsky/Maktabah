# BUILD 8401: REGRESSION TEST MATRIX (HARDENED)

**Date:** 2026-10-25  
**Candidate Baseline Commit:** `031df35710ab2c6015efb1acd1e65154dbcd3f24` (`031df35`)  
**Pinned Upstream Remote Ref:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (`a0ed0df`)  
**Portable Local Assertions:** Windows Swift 6.3.3 (`tools/test_chavrusa_text_components.swift`) — **164 of 164 PASSED (100%)** across 15 suites  
**Boundary Integrity Guard:** Python 3.12 (`tools/test_verify_upstream_boundary.py`) — **24 of 24 Fixtures PASSED**  
**Apple SDK / Xcode Build:** `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` (Requires explicit owner dispatch; protected patches unapplied in live tree)  
**iPad Simulator UI / XCUITest:** `IPAD_UI_PENDING` (Pending macOS 27 Xcode build)  
**Physical Hardware QA:** `PENDING_OWNER_DEVICE_QA` (Requires owner testing on physical iPad Pro after authorized build)  

---

## 1. Test Execution Level Definitions

To eliminate false-positive declarations, all acceptance criteria are evaluated across four strictly segregated execution gates:

1. **`PASS_PORTABLE`**: Verified by local Swift 6.3.3 portable components / state-machine tests (164/164 assertions passed across 15 suites).
2. **`APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION`**: Verified by full Xcode app compile (`xcodebuild` on macOS 27 / `xcode-27` runner). Blocked until owner authorizes CI push and dispatch.
3. **`IPAD_UI_PENDING`**: Verified by real XCUITest on iPad Pro 13-inch simulator. Blocked until owner authorizes CI run.
4. **`PENDING_OWNER_DEVICE_QA`**: Final physical acceptance testing on owner's iPad with production databases.

---

## 2. Hardened 21-Row Acceptance Matrix (H1–H5, P1–P4, B1–B3, T1–T2, S1–S2, L1–L3, X1–X2)

| ID | Title & Setup | Backend Data & Action | Ref Before -> After | Expected Attributed Highlight / UI / X-Button / TOC State | Portable Evidence | Apple / Device Gate |
|:---:|---|---|---|---|:---:|:---:|
| **H1** | Global Sefaria search hit to Rashi 15b segment | Search query "והיה כעץ שתול", tap result in search modal | Search modal -> `Rashi on Berakhot 15b:3:1` | Full daf `15b` loaded; exact segment `3:1` highlighted in yellow; Clear 'X' visible; text view not blank | `PASS_PORTABLE` (Suite 11 & 13) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **H2** | In-book Otzaria search, second hit in same tab | Tab open on Berakhot; tap 2nd search result on same page | `Berakhot 12a:2` -> `Berakhot 12a:7` | Render cache invalidated; yellow highlight jumps to segment 7 without stale unhighlighted view; Clear 'X' visible | `PASS_PORTABLE` (Suite 2 & 13) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **H3** | Clear Search Highlight via 'X' Button | Active search highlight in reader; user taps 'X' button in bottom toolbar | Search highlight active -> cleared | Highlight attributes removed from `NSAttributedString`; 'X' button vanishes; user manual annotations intact | `PASS_PORTABLE` (Suite 13) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **H4** | Programmatic focus scroll vs manual drag | Programmatic jump to search hit, followed by user swipe | Hit navigation -> user drags 150pt | Programmatic scroll does NOT clear highlight; manual drag past threshold clears highlight and hides 'X' | `PASS_PORTABLE` (Suite 13) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **H5** | Hebrew Niqqud / RTL / UTF-16 surrogate range | Text with cantillation and niqqud; search term unpointed | Search "שלום" on pointed text "שָׁלוֹם" | `ReaderSelectionRangeMapper` validates UTF-16 code units; highlight covers entire pointed word without offset drift | `PASS_PORTABLE` (Suite 2) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **P1** | Sefaria bidirectional pull-to-navigate | Sefaria reader open on Berakhot 15b; pull down at top / up at bottom | Top pull: `15b` -> `15a`<br>Bottom pull: `15b` -> `16a` | Top pull scrolls to bottom of `15a`; bottom pull scrolls to top of `16a`; no white screen; no jump to start of book | `PASS_PORTABLE` (Suite 12) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **P2** | Otzaria pull-to-navigate from middle unit | Otzaria book open at section 45 (out of 100); pull up at bottom | Section `45` -> Section `46` | Navigates to Section `46` (next section); never resets to Section 1; scroll positioned at top of Section `46` | `PASS_PORTABLE` (Suite 12) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **P3** | Pull-to-navigate retreat & bounce cancellation | Drag down 40pt (below 80pt threshold) and release; rapid flick | Dragging -> Released below threshold | Disarms state machine; returns to idle; 0 navigations dispatched; haptic feedback only on threshold pass | `PASS_PORTABLE` (Suite 3) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **P4** | Reader bottom toolbar previous/next buttons | Tap `<` or `>` arrow in reader toolbar | Sefaria / Otzaria current -> next/prev | Uses identical `ReaderBackendPagingCoordinator` path as gestures; consistent boundary and scroll target behavior | `PASS_PORTABLE` (Suite 12) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **B1** | Source switch: Otzaria (3 tabs) -> Sefaria -> Otzaria | 3 tabs open in Otzaria; switch to Sefaria in Settings; switch back | Otzaria (Tabs A, B, C) -> Sefaria -> Otzaria (Tabs A, B, C) | All 3 tabs restored with exact scroll positions, book IDs, and active tab preserved; no blank tabs | `PASS_PORTABLE` (Suite 7 & 9) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **B2** | Cold catalog failure / missing target book | Switch to backend where catalog is missing or book unresolvable | Switch attempted -> Fails closed | Error banner displayed in Settings; active backend remains unchanged; tabs preserved; zero corrupt snapshots | `PASS_PORTABLE` (Suite 7 & 9) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **B3** | Rapid double backend switch and in-flight fetch | Rapidly tap Otzaria -> Sefaria -> Otzaria while fetching | In-flight transition superseded | Transition generation token increments; stale responses discarded; final active backend matches last user selection | `PASS_PORTABLE` (Suite 7 & 9) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **T1** | Live TOC auto-tracking during reader pagination | TOC sidebar open; user pages through 5 sections in Otzaria | Page 1 -> 2 -> 3 -> 4 -> 5 | TOC active row highlights current section and automatically scrolls to keep visible; no runaway scroll | `PASS_PORTABLE` (Suite 14) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **T2** | TOC deepest leaf/ancestor matching | Reader open on nested commentary or deep folio sub-section | Deep passage -> TOC open | Deepest matching ancestor node selected and expanded in TOC tree; correct parent disclosure groups open | `PASS_PORTABLE` (Suite 14) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **S1** | Linked source: Rashi on Berakhot 15b segment | Tap linked source footnote in Berakhot text | Commentary reader opens | Loads full `Rashi on Berakhot 15b` daf; focused passage visible; not a 1-line white container | `PASS_PORTABLE` (Suite 11) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **S2** | Linked source: Genesis 1:3 chapter bounding | Tap linked verse from commentary | Verse ref -> Chapter container | Loads `Genesis 1` chapter; verse 3 highlighted; container navigation permits reading verses 1-31 | `PASS_PORTABLE` (Suite 11) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **L1** | Hebrew Talmud and section localization | System language Hebrew; inspect Sefaria Talmud and Tanakh headers | Sefaria navigation headers | Shows `י״ב ע״א` (not `12a`), `ט״ו ע״ב` (not `15b`), `פרקים` (not `Chapters`), `דפים` (not `Folios`) | `PASS_PORTABLE` (Suite 10) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **L2** | English locale preservation | System language English; inspect navigation and headers | English reader view | Displays English labels (`Chapters`, `Folios`, `12a`, `15b`) without Hebrew override; LTR layout intact | `PASS_PORTABLE` (Suite 10) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **L3** | Delayed TOC loading state (e.g. Tractate Eruvin) | Open heavy TOC tree while network or SQLite read is in-flight | TOC tap -> Load completes | Shows `ProgressView` loading spinner; does NOT flash "אין תוכן עניינים" prematurely; renders tree on completion | `PASS_PORTABLE` (Suite 14 & Patch 07) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **X1** | Annotation persistence across backend switches | Add highlight and note to segment; switch backends and return | Annotation added -> Switch -> Return | User highlight and note restored on exact text range; distinct from transient search highlight | `PASS_PORTABLE` (Suite 5) | `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` / `IPAD_UI_PENDING` |
| **X2** | Full production database & inspector acceptance | Physical iPad Pro; full Otzaria sqlite + Sefaria packages | Real corpus search and inspection | Zero crashes, zero database locks, smooth 120Hz ProMotion scrolling; verified on owner hardware | `PASS_PORTABLE` (Local components) | `PENDING_OWNER_DEVICE_QA` |

---

## 3. Summary of Verification State

- **Local Verification:** 164 of 164 assertions passed (100%) across 15 suites in `tools/test_chavrusa_text_components.swift`.
- **Integrity Verification:** 24 of 24 fixtures passed in `tools/test_verify_upstream_boundary.py`.
- **Compiler Fixture:** Swift access-level verification passed in `tools/test_access_control_compiler.py`.
- **Git Config Preservation:** Local git config strictly preserved in `tools/test_git_config_preservation.py`.
- **Self-Contained Bundle Verification:** Independent two-cycle reproduction using ONLY `artifacts/CHAVRUSATEXT_BUILD_8401_REPAIR_APPROVAL_BUNDLE.zip` verified clean assembly, testing, and rollback in `tools/assemble_and_verify_bundle.py`.
- **Apple / macOS 27 CI Status:** `APPLE_BUILD_PENDING_OWNER_CI_AUTHORIZATION` (runner: `xcode-27`).
- **Owner Approval Status:** `OWNER_APPROVAL_REQUIRED` on all 12 proposed patches.
