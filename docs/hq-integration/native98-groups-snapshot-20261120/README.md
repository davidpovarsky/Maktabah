# Native groups100: source-bound reduction of repeated XCTest work

The existing test actually exceeded its unchanged600-second allowance in Native run44723902453 on F60a57972 / M87b783ac. The complete original group log has now been read from the SHA-verified original artifact, and the exact case is retained here.

Its baseline setup ended at251.24seconds.28 distinct transitions committed before the timeout; six more committed after the timeout and the35th was attempted before the process ended. No100-transition or cold-restore acceptance is claimed. Automation observations include snapshot IPC, taps and XCTest idle handling; they are not product p95 measurements.

## Narrow test-only candidate

This changes only FaithfulReaderUIAcceptanceTests.swift, based on ProfileColor source0a493e0a362e88405fabe7a08ff60fb51820496f. The production app, SDK, original managers, engines, database and source selection are unchanged.

- The post-transition observer takes one fresh real application snapshot, checks the same original overview, app-wide error absence, enabled selector/value, exact card UUID, selected state and exact card count within that overview's collection views.
- String-based matches preserve all five identifying properties used by XCTest: identifier, title, label, value and placeholderValue. The card prefix remains explicitly an identifier condition and target group buttons remain exact label matches.
- Both original live XCUIElement.isHittable checks remain. A snapshot frame cannot replace a live hit test.
- The segmented selector uses a fresh snapshot to identify its unique original target. It additionally requires finite positive containment, actual live target hittability and identical live target/window frames, then performs an actual XCTest tap at the same midpoint relative to the original window. Ordinary XCTest idle behavior remains enabled.
- The original menu fallback is byte-identical. No snapshot is cached across a tap, transition or predicate evaluation.
- Two passive automation phase durations are recorded separately. Existing actual-app operation/memory metrics remain unchanged and are not replaced by automation timing.

The complete100-transition loop, independent group/document ownership, every full membership/profile/locator comparison, real reader checks, cold launch and restoration assertions are preserved. The original15-second observation wait, shared tap helper and external600-second case allowance are unchanged. The prior ProfileColor change is retained exactly. All40 test declarations in this file are preserved.

The snapshot walker and its recursive local function are explicitly MainActor isolated. An independent source review checked the full diff, scopes, real hit tests and original fallback. That review found no concrete source blocker.

## Validation and limits

Exact full-file inverse/source checks and independent review passed. The old M87 observer and selection helper are byte-identical to this candidate's baseline, so the retained actual failure applies to the exact code being replaced. These checks are source/evidence validation, not XCTest execution.

**Swift syntax parse, Apple SDK typecheck and Native rerun: NOT_RUN.** The Windows host disconnected before this candidate was created; the local environment has no Swift compiler. The final Apple gate must compile and run it.

The first three original taps took4.83–5.57seconds before the first post-action observation, apart from later AX queries. Snapshot consolidation and a window-relative coordinate do not prove that100 transitions plus cold restore will fit600seconds. If the rerun still fails, preserve that result and diagnose the actual app metrics and automation phase timings; do not increase the bound, skip transitions, disable idle handling, bypass the UI or discard assertions.

## Evidence

- NATIVE_FAILURE_REVIEW.json binds the original ZIP member, exact1679-line case boundary, actual attempted/committed observations and before/after-timeout distinction.
- PROPOSED.patch and SOURCE_REVIEW.json bind the exact baseline/candidate and source-only preservation checks.
- PEER_REVIEW.json retains the final independent review, API sources and its initial packaging assertion about a misidentified baseline hash.
- RAW_FILES.json maps lossless original source/log/driver/review streams to gzip objects.
- VERIFY_PACKET.py verifies all delivered bytes and the exact inverse without running app code or tests.
- MANIFEST.json seals every other delivered file.

The full original artifact is retained separately in native98-raw-supplement-20261120. The full log is262,387bytes, SHA25623a3e52329ad60253ee97fe4d5a9a63d95ea20fb77e36ee4fc605057acc5147f; the bounded case is161,069bytes, SHA2564ca5dfbb66165d175edcf476374052daffcd009173f58414cfb696bab70ff4c5.

