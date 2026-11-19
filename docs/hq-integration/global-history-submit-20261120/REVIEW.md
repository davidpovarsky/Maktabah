# Restore the two original GlobalHistorySubmit journeys

## Confirmed source/test mismatch

Base source: `0bc6be41f03855412d7dd24ee72608a7824fb5a7`.
The existing R27 iPad/iPhone methods call `exerciseGlobalHistorySubmission`.
That helper selected `app.textFields.firstMatch` and searched for the old
Start Search button. The current `GlobalSearchHeader` mounts
`NativeGlobalSearchField`, whose exact identifier is `global-search-query`.
Its original `textFieldShouldReturn` copies actual field text, resigns first
responder and invokes the original submit callback. `SearchModeView` forwards
that callback to the existing `UnifiedSearchSessionController.runSearch()`.

Refocusing completed results also does not restore current inline history.
`GlobalSearchContent` shows history only before submission. The corrected
helper uses the genuine relaunch path already used by BookHistoryScope to
reopen the original history from persisted preferences. No product view,
engine, history value or receipt changes.

## Retained acceptance gates

The helper requires one exact original native query field, enters the original
unique Hebrew query and Return, observes the original submission settle, then
terminates and relaunches that original Search session. It focuses the original
field and requires the real native keyboard. It then requires exactly one row
for the exact submitted query, the query in its label, visibility, hittability
and geometry above the keyboard. The existing read-only SearchHistory and
recordSearchHistory diagnostic remains. Actual submit is the only history writer.

The original R27 methods and normal-bootstrap/device/orientation gates are
unchanged. Their **repository LF bytes** retain SHA-256
`d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc`.
Windows checkouts use CRLF; both raw and normalized hashes are recorded.

The prior 78 selected IDs stay in exact original order. These two existing
catalog entries are added without replacing any earlier case:

- `R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit`
- `R27NativePhoneTests/testNormalBootstrapGlobalHistoryUsesActualSubmit`

All 80 original catalog entries are now selected: 65 iPad and 15 iPhone.
Groups: search 22, reader 34, sidebar 5, window 2, Hanlin 2, phone 15.
Earlier exclusion records remain historical evidence. The separate six Phase 2
Native additions are coordinated by the notes/search agent and root; they are
not included in this count.

## Actual validation and outstanding work

The installed Swift 6.3.3 frontend resolved all 80 selected XCTest methods:
`DECLARATIONS_MATCH`. The edited file passed Apple-target **parse only** on
Windows. Both expected missing-Apple-SDK/sysroot warnings are retained.
`git diff --check` passed. No Source file changed; exact original source
hashes, Windows checkout hashes and current helper/manifest hashes are recorded.

**Apple SDK typecheck: NOT_RUN. Native UI: 0. Physical device: 0.**
Combined source pins still require the owner's freeze before dispatch.
These preflight results do not mark either restored journey or the phase PASS.
