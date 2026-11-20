# Full Release run 44665679661 — original failure evidence

## Outcome

The workflow **FAILED** on checkout **9cc346601bdb3fdda34c2c6ac59894f71dc9ea49**, with application and XCTest source **7e777509d486a17bec5b4bd437a9ac7f51d3a43a**. This independent review reconciles the exact 96 UI + 2 separate prototype declarations, build/input provenance, finalized xcresult leaves, summaries and raw logs. It does not execute new Native tests.

| Original configuration | UI PASS | UI FAIL | UI SKIP | UI NOT_RUN | Separate oracle PASS |
|---|---:|---:|---:|---:|---:|
| iPad11 native / miniTest10 / Debug | 25 | 29 | 0 | 0 | 1 |
| iPad13 native / miniTest10 / Debug | 6 | 28 | 0 | 0 | 1 |
| iPad13 largest text / miniTest10 / Debug | 1 | 0 | 0 | 0 | 0 |
| iPhone native / miniTest10 / Debug | 2 | 4 | 0 | 0 | 0 |
| iPad13 full production / Release | 0 | 0 | 0 | 1 | 0 |
| **Total UI** | **34** | **61** | **0** | **1** | **2 separate** |

All95 Debug UI cases have finalized leaves. Three iPad11 cases exhausted their ten-minute per-case allowance and have no raw terminal Test Case line; their finalized xcresult leaves explicitly fail: testSameBookRetainsIndependentLocationsAcrossGroupsAndRelaunch, testSidebarPreservesOriginalTextKitViewport, and testTwentyGlobalTabRoundTripsKeepOriginalReaderAndBottomBar. They are not omitted or relabeled NOT_RUN.

**Production Release did not run.** The exact producer stops at runtime27-release.py184–186 when the native matrix fails; production is invoked only at187–188. No production log, acceptance report, binary execution evidence or result tree exists. Distribution was not attempted.

The original top-level counters remain initialized0/0 because the producer raises before collect_configurations and final aggregation. These fields do not mean no execution or success. INDEPENDENT_REVIEW.json independently reports34/61/0/1 and2 separate oracle passes, with **zero reconciliation errors**.

## Source and artifact binding

- [Original GitHub run](https://github.com/davidpovarsky/Maktabah/actions/runs/44665679661).
- Whole evidence artifact14608089579: **69,365,070 bytes**, SHA256 **9cbc4b9b7a3fa7195430bbeb987094ac1fbc6398805641fd79981cd8f4953e63**.
- Exact full Release manifest SHA256 **7897577ded6c32d82914018e8378db95862e6eabec5fdb263887f95630c9da83**.
- Application tree, test tree, test/helper file hashes and committed package pins were independently compared to the exact checkout/source. The original build reports888 actual source inputs audited and clean pinned packages.
- Capture artifact14608653727 was **not downloaded or whole-file hash-verified**. Only the directory and20 selected entries were read with exact HTTP206 Content-Range and ZIP CRC checks. RANGE_EVIDENCE files retain metadata, transfer ranges and selected-entry SHA256. Selected bytes are preserved here; temporary range caches stay in the owned build folder.
- Comparison source is **c61213d9fcc8b80a8606ba00a1562215312ca2ed**. **No old PASS is transferred to it.**

## First failures and state propagation

The first iPad11 failure is its first case, Build8401SevenDefectsAcceptanceTests/testA1_A2_SearchResultHighlightAndClearButton, original line26: rendered search-highlight range count0. The first iPad13 failure is case4, testCandidateGlobalSearchLandscapeMatchesOriginalNavigation, original Faithful1350: navigation minY86 rather than106. The first phone failure is testIPhoneKeepsOriginalReaderWithEitherIPadFeatureSetting, Faithful823. Largest text passes its one original case.

EXECUTION_ORDER.json preserves case ordering. FAILURE_TRIAGE.json assigns all61 failures to the first observed assertion and marks ordering relative to the failed candidate-window case. A later position alone does not establish causality.

### Native navigation geometry — four failures before compact-window work

The two annotations landscape captures on iPad11 show the same full1210×834 window: flags-off NavigationBar y32 height160, enabled y32 height108. The assertion fails at old Faithful1353. Paired AX files541EAC01… and4A89F386…, paired PNGs0480… and14DD… preserve both views.

The iPad11 search landscape captures show both native navigation bars at minY106 with the flag off, minY86 when enabled, in the same full1210×834 window. Paired AX C53E… and5A77…, PNG37F8… and4E73… preserve both. The same oracle fails on iPad11 portrait and iPad13 landscape. These failures precede CandidateWindow, so its later compact state cannot explain them. No header sizes or expected geometry were changed.

### Original Inspector headings — four failures

Both orientations on both iPads fail old Faithful1364 because the visible redundant כלי לימוד heading remains. The original iPad11 video additionally shows קטע נבחר. Selected video438D4C71… is preserved; captures/heading-final-original-frame.png decodes frame297 of298 from it. HEADING_FRAME_RECEIPT.json records input hash, frame index, decoder command and output hash. Initial seeking by container duration produced no frame and no evidence; frame-index decoding succeeded. The video has a timestamp-order warning, so the frame index is the strongest extraction identifier. This is original UI evidence, not a reconstruction.

### Candidate window, cleanup and later compact state

The iPad11 candidate-window AX has app.frame=(0,0,375,486), but actual Window=(418,117,375,486). Native toolbar=(418,127,375,54), overview=(680,131,42,36), palette=(558,131,40,36). These controls are in the actual Window. Old Faithful324 compares screen coordinates against the differently rooted app.frame, failing before overview or Study actions.

The teardown was registered at old Faithful545–588 and actually ran. At relative t43.57s it records Native window controls unavailable; Full Screen was not found. This is not a claim that XCTest skipped that teardown. The old restoration uses application-relative(42,32).

The later R27 window case starts in the same375×486 window and fails old R27 line134 before registering cleanup at135–136. Here assertion abort does prevent that later registration. Its original final AX0772113F… andPNGFE0335F1… preserve the compact state. Later rotation/chrome/action-bound failures may be affected, but remain failures pending diagnosis and rerun.

The new d05 helper changes only the later Study/open-close block, not these earlier coordinate/initial-window failures. Root owns the scoped window correction; this commit changes no UI or oracle.

### Overview membership — two failures

On iPad11, portrait and landscape nonzero-position overview tests fail old Faithful399: two real documents exist where the fixture expects one. AX8DAD… shows distinct actual UUIDs: selected ספר החינוך49D57F7F… and בראשית97EC388D…. These are not duplicate AX representations of one tab. The setup and real document ownership need investigation; expected count remains unchanged.

### History and other checks

The two iPad13 History cases and phone R27 History fail at old Faithful675 before typing: the original global query field is missing or the AX query times out. Persistence/readiness repair944031 does not establish a fix for this earlier admission failure.

Other first assertions include actual highlight0, missing original sidebar/bottom-chrome actions, real document-strip collapse, actual Reduce Motion, original Escape dismissal, profile editor admission and original app termination. Exact configuration/case/messages/locations are retained; no broad product root-cause claim is made.

## Current-source comparison and limits

METHOD_COMPARISON.json hashes exact method bodies. Throughc612, palette launcher, bottom chrome selector, sidebar selector, toolbar geometry, overview replacement, trimmed Inspector and manual-scroll bodies remain unchanged. The window method changes only the later Study/close block; History gains installation/persistence observations. Relevant iPadLayout, iOSMainView, ReaderHost and iOSReaderWorkspaceView paths also have no7e→c612 diff.

The first independent review compared original verifier hashes to exported raw JSON bytes and reported four mismatches. That attempt is retained. The exact original verifier hashes sorted JSON values and then exports indented JSON; applying its actual canonicalization reconciles all four. Raw bytes were not changed and the whole ZIP SHA always matched.

No product, XCTest, manifest, workflow or fixture changes are made here. New-source Apple/Native, production Release, physical-device checks and distribution remain separate gates.

Generated Windows collector JSON/scripts are stored as readable LF copies; their exact original CRLF bytes are also retained as lossless gzip under collector-original. COLLECTOR_LINE_ENDINGS.json records both hashes. Original GitHub artifact entries are unchanged.
