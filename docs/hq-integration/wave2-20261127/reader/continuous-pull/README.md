# Original continuous pull: source checkpoint, native acceptance pending

The additive native selector is:

`FullV40ReaderModeAcceptanceTests/testOriginalContinuousTouchArmedRetreatPreservesParagraphAndChapterReader`

It uses the real production v40 Reader reached from the original published
Search result, changes paragraph/chapter mode through the original controls,
and asks the dedicated host for one continuous top-edge contact in each mode.
No product Source changed. Every byte of the previous registered Build8401
file is retained as an exact prefix; the legacy selectors and the earlier
subthreshold/commit/TOC case remain unchanged. No v32 case or shared performance
driver changed.

## What was actually verified

On the existing Scaleway Mac, Xcode 27.0 (27A266a), Swift 6.4:

- Whole registered test file parse: exit 0.
- Whole file against actual XCTest/iPhoneSimulator27.0, Swift 6 strict
  concurrency, original test base and original shared Search helper: exit 0.
- Actual installed idb 1.7.8 codec/protobuf with explicit synthetic client and
  probe component doubles: 19 controls passed, 0 failed.
- Simulator connections: 0. Touches sent: 0. App builds: 0. Native UI cases: 0.

The original Mac result is retained under
`/Users/m1/builds/otzaria-wave2-reader-controls-20261127/continuous-pull-source-20261127T033549Z`.
The exact commands, SDK, hashes, exit codes and raw compiler/control output are
under `apple-source-controls/`. These are source and codec receipts; they do
not establish native delivery, app gesture handling, or UI acceptance.

## Actual installed capability

The existing pinned tools are at
`/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/original-native116-prebuilt-evidence.X0L7wYFd/local-tool-temporary.q6D5fNUv/r27-hid-tools-73pnzxjb`.
The installed Python source matches the original wheel. The companion binary
matches its original archive. The wheel and archive SHA256 are respectively
`ed8557a4c54ffee53006c1fe63f070cda567949312ab24be56faf987c5a3d04b` and
`44369a2df0b62e3a1764de61bd09280999c7e9b27ea8f20bff1ea3a9db0302a2`.

The actual client implements `send_events(Iterable[HIDEvent])` and
`hid(AsyncIterable[HIDEvent])`. The latter keeps one original
`hid(stream HIDEvent)` RPC open. Its `drain_to_stream` sends each provided
message and ends the stream only when the iterator ends. `HIDTouch(Point)` is
wrapped in `HIDPress` with `DOWN` or `UP`; there is no fabricated `MOVE` enum.
The pinned companion's own compiled `SimulatorHIDEvent.swipe` builds held
`DOWN` positions with delays and one final `UP`. The retained binary
disassembly/source inspection documents this convention. Runtime confirmation
on the actual app remains a separate native gate.

The existing two `press(...thenDragTo:)` calls in
`PullNavigationAcceptanceTests.testPullNavigationRetreatCancelDoesNotChangeContent`
are separate gestures. The existing `thenHoldForDuration` call is a two-point
drag plus endpoint dwell. Neither is credited as this single-contact retreat.

## Exact new scope

Only portrait is admitted. Actual `idb.describe().screen_dimensions` must
include point dimensions and density; its pixel/point relationship and the
original app's AX window must agree. The test sends window-point coordinates,
not inferred pixel coordinates. Every waypoint stays inside the visible
original Reader. The outbound path moves 240 points from its start, then
returns to 20 points beyond the same start, without an intervening `UP`.

During the one open stream, the host uses the existing passive viewport
request protocol. Fresh original samples must show the same app PID, native
UITextView owner, canonical locator, render generation and source length.
The actual native top overscroll must reach at least 80 points while held,
then fall below 80 while still held, before one final `UP`. The original probe
does not directly expose the pull state-machine enum; the threshold and
same-contact order are the exact observed gate. The test independently
compares every bounded source sample against the full-v40 catalog, and checks
the original canonical Reader, current document and selected TOC after release.

A failed native criterion releases within the same stream and fails. A broken
transport triggers separately recorded emergency cleanup; its two RPCs can
never satisfy the one-contact gate. The host stops only its own processes and
does not clear global idb state or delete retained evidence.

## Remaining real run

The integration owner must execute this exact selector on its qualified same
source app/test/SDK build, retained original full-v40 installation and real
published search target. Both UI and host gates must pass. This checkpoint does
not establish any PERF result, Groups100 result, full-v32 acceptance, or
Native116 completion. Database discovery and database hashing were not run.
