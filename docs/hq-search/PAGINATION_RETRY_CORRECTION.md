# Otzaria pagination retry correction — 2026-11-15

[נועם | DEV] [MAIN_SESSION]
Desktop UUID: 01a1dc89-716c-7a01-b6fc-49cb16fe7822
Branch: codex/otzaria-search-20261115
Previous implementation: 2c3fd9868ca54ff9cfbe8e923c9462575befac73
Previous evidence HEAD: 2d121bbb4bb4221cb736071c261d645cc58d660d

Roni's independent QA found and reproduced a stale error after an Otzaria next
page failed and then succeeded. The original fixtures exercised the real Zayit
wrapper and Otzaria metadata store, but did not drive the full Otzaria view model.

Production delta: exactly two added assignments in the downstream
Source/Otzaria/Search/OtzariaTextSearchViewModel.swift, loadNextPage:

1. Clear errorMessage after all synchronous request/backend/profile guards when
   starting a valid load/retry.
2. Clear errorMessage after successful store, inside the existing generation,
   database, backend and profile guards.

No upstream hook, Vendor, project membership or production file addition.

## Actual-class regression

The harness now compiles the ENTIRE production OtzariaTextSearchViewModel class,
without replacing or extracting its methods. Its Combine/repository/storage/
indexing/backend boundaries are explicit fixture doubles. A test-only accessor
is appended in the generated temporary source file so the regression can await
the real private pagination Task; no timing-based stale-completion assertion.

The added scenario loads 100 rows, fails offset100, retries successfully to200
while hasMore remains true, verifies error clearing immediately and after success,
then holds an old page success while a new search fails and proves the old
completion cannot erase the newer generation's error.

RED: tools/hq-search-tests.py --otzaria-baseline 2c3fd9868ca54ff9cfbe8e923c9462575befac73
compiled the full frozen class successfully and failed the intended assertion:
`FAIL: actual Otzaria retry clears stale page error immediately`.
Process exit -1 from the Swift assertion; log: otzaria-retry-red.log.
QA independently reproduced the same defect using its separate temporary harness.

GREEN: current full-class fixtures are recorded in otzaria-retry-green.log.
This corrective commit supersedes the previous immutable source for current QA.
The original HANDOFF.md/COMMIT.md retain historical evidence; use this correction
and the latest Git commit for the current source snapshot.

No actual Apple Combine delivery, app/FFI/production database, device or release
acceptance is claimed. Existing physical iPad and runtime gates remain OPEN.

Rollback: revert only the corrective commit as a unit if needed; this reopens the
known stale-page-error regression. No data/schema migration or index rebuild.

Final GREEN: 191 portable assertions PASS, compile exit 0 / process exit 0; 61.06 seconds. Targeted Swift syntax parse and git diff --check PASS. No production source differences beyond the two documented assignments.
