# Native78 — actual run 44633736259

**FAILURE: 65 passed, 13 failed, 0 skipped, 0 not run.** All 78 selected cases have exactly one original xcresult Test Case leaf. The independent leaf count agrees with every group summary, every named driver outcome and the selected 78-case manifest. No case, assertion, receipt or UI interaction was executed by this evidence review.

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44633736259

| Provenance | Exact value |
|---|---|
| Workflow checkout | `7d05dd0bb25a7df307b35174e49e18d0f22eecee` |
| Application and test source | `5d8ef991554b01ba6bf3d39222c5ef6cc00a264b` |
| Native job | `135946853389` |
| Original case manifest SHA-256 | `bdadb6c5e7dc6edee5cfb4d2e04f26d50ce8388209b9a39795143ee2c449a06a` |
| Evidence artifact | `14596339141`, 76,651,411 bytes |
| Evidence ZIP SHA-256 | `5842cfdfe0748dcd7b2620a2dde895812bb2441694c36a63901a8530f1373968` |
| Separate captures artifact | `14597472251`, 1,913,982,366 bytes, not downloaded for this review |
| Captures ZIP SHA-256 | `6de6f2266c92b17cdcaaa818d74c14baebccdddff9e7f2aedb680cb753ae2b52` |

The original evidence ZIP was downloaded and hashed in scratch. `EVIDENCE_LEDGER.json` retains its location, immutable artifact identifiers and original entry digests. Selected original JSON/log entries are stored losslessly as deterministic gzip files; decompressing them must reproduce the recorded byte count and SHA-256. `VERIFIED_CASES.json` retains all 78 named cases, failures, source locations and provenance checks. `FAILURE_TIMELINES.json` and the compressed per-failure activity spans are direct extracts from the original native driver log. No final conclusion is inferred from the workflow's other intentionally unselected jobs.

## Actual groups

| Original execution group | Passed | Failed | Skipped | Not run |
|---|---:|---:|---:|---:|
| iPad Search (21) | 20 | 1 | 0 | 0 |
| iPad Reader/routing (34) | 28 | 6 | 0 | 0 |
| iPad Sidebar/history (5) | 3 | 2 | 0 | 0 |
| iPad Window/HID (2) | 0 | 2 | 0 | 0 |
| iPad original Hanlin (2) | 2 | 0 | 0 | 0 |
| iPhone (14) | 12 | 2 | 0 | 0 |
| **Total** | **65** | **13** | **0** | **0** |

No per-assertion execution counter is available. These are actual **case** counts. The original failure assertions are preserved verbatim in the machine-readable evidence. The two historical GlobalHistorySubmit cases were outside this 78-case selection; this report does not silently count them as executed or passed. Later 88/90-case selections and newer source commits require their own actual results.

## Thirteen failures and evidence boundaries

| Original case | Actual failing point | What the evidence establishes |
|---|---|---|
| `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` | line 480: heading `minX=0` is less than controls `minX−1=15` | The heading AX frame still extends beyond the actual Search controls. This is horizontal geometry, not height. The subsequent native accessibility audit was not reached. |
| `NativeRoutingAcceptanceTests/testHistoryURLAfterBackgroundRequiresActualVisibleReceipt` | line 197: exact credential-free success schema | The owned transport log records `delivered:false`, `error:"System URL transport timed out"`, nonce `1580879F-7A5E-4266-85ED-398BD1BEF72D`, at 00:43:18.844 UTC. Its error response has an extra error key, so the success-only assertion fails. This does not prove a credential leak or a native history receipt. |
| `NativeRoutingAcceptanceTests/testPublicV2InspectorPreservesOriginalReaderAndWorkspace` | line 1499: original panel exists but is not hittable | At 00:47:47.188 the actual Inspector witness becomes appeared/contained/visible and matches; at .198 `native_effect_uncertain` is logged, then an alert makes the surface modal/blocked. A completed Core receipt was not established. |
| `NativeRoutingAcceptanceTests/testPublicV2NewTabSameBookCreatesDistinctOriginalReaderTab` | line 639: original tab exists but is not hittable | Before failure, the test passes new actual locator/highlight, new receipt, distinct tab UUID and preservation checks. It fails returning through the original tab `13C83885-CCBC-4A83-A873-1EE70C69A447`; restoration to the original reading state is unproven. |
| `NativeRoutingAcceptanceTests/testPublicV2TOCPreservesPrivateFilterAndOriginalReader` | line 990: actual UIKit/Core receipt wait times out | The app logs `NativePresentationWait deadline_exceeded`, then `native_effect_uncertain`; the actual final requested surface/receipt gate failed. |
| `NativeRoutingAcceptanceTests/testSystemAppIntentShowsOriginalReaderInspector` | line 1562: `NativeIntentOutcome` code 1, destination changed | The actual Inspector witness becomes visible/matching at 01:02:32.244. The system intent subsequently fails and no completed receipt is proved. |
| `NativeRoutingAcceptanceTests/testSystemBookIntentCachedSourceReturnsFromBackgroundAndPreservesReader` | line 1275: `OtzariaUIRouting.UIRouteError` code 1 after Home | The actual initial canonical Reader/source/highlight checks passed, then the background system-intent path failed. |
| `BookHistoryScopeAcceptanceTests/testBookSearchRetainsControlsWithoutGlobalHistory` | line 89: distance field identifier `10` never appears | Real global submit/history and the book-search four-mode/help/absence preconditions passed. The fourth mode was tapped as `text.word.spacing`; the required distance field was not found. Whether this is a current selector/value mismatch or product behavior requires source/UI evidence. |
| `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR` | 600-second execution allowance | The log still shows genuine selected-state checks and page 0/1 interactions near t=599.88, with no preceding assertion failure. The remaining original transitions/final oracles were not completed. Timeout remains a failed case. |
| `R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector` | line 445: `reader-study-toggle` does not exist | After genuine window resize, the original Inspector launcher is missing. `isHittable` and geometry assertions on lines 446–447 were not reached. |
| `R27NativePadTests/testNormalBootstrapPaletteHIDComparison` | line 445: same missing `reader-study-toggle` | Shared missing-control failure after actual compact-window work. No HID/Inspector completion is claimed. |
| `NativeRoutingPhoneAcceptanceTests/testPhonePublicV2InspectorPreservesOriginalReaderAndWorkspace` | base line 150: application has no process ID during launch | The case fails before any Inspector operation. Xcode logs debugger lookup `noURL`; teardown later observes PID 5971. The main artifact contains no crash report. This is a launch/PID failure unless additional evidence proves otherwise. |
| `NativeRoutingPhoneAcceptanceTests/testPhoneSystemAppIntentShowsOriginalReaderInspector` | line 1598: destination changed | Actual system-intent Inspector failure, separate from the phone launch failure above. |

The original routing cases through line 1600 are unchanged in app source `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`, except the canonical Reader launch helper accepts extra arguments for later new cases. Later product changes may affect these failures, but source review is not a passing Native rerun. Current-source diagnosis and implementation are coordinated separately; all 13 original failures remain preserved here.

## Reproduce the evidence review

Run the included `review-native-evidence.py` against the original GitHub ZIP and `ORIGINAL_78_CASE_MANIFEST.json`, supplying the exact ZIP, checkout and application hashes above. It validates the original JSON summaries against all named Test Case leaves and the driver outcome, without launching an application. Unpack each retained `.gz` and compare against `EVIDENCE_LEDGER.json` to verify raw entry integrity.

The sole watcher ended naturally on the failed workflow at 03:05:11 UTC. No cancellation, replacement run or new Native dispatch was performed by this audit.
