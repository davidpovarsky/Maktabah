# Global History: require the original persisted submission before relaunch

## Result and limit

This is a **test readiness and evidence repair**, not a proven production history fix. The original app's search, history storage, query, engine, and settings are unchanged. Candidate Native execution remains **NOT_RUN (0)**.

The shared test still types its fresh UUID query into the original native field and presses Return. Within its **unchanged 90-second deadline**, it now requires both the existing settled-UI conditions and exactly one persisted copy of that query in the original app installation. It never seeds a history item, changes preferences, calls synchronization, retries submission, or extends the deadline. The final exact history row, label, hittability, and keyboard-geometry assertions remain.

## Native88 evidence

The actual failure was in [44657116407](https://github.com/davidpovarsky/Maktabah/actions/runs/44657116407), checkout `fe4df7c39aec242d00046bc454c81963ba4285a0`, app/test source `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`:

- The native field accepted the exact UUID query.
- At 45.34–45.60 seconds, the old predicate checked only that history/loading/cancel were absent.
- At 45.78 seconds the test terminated the app, without observing the submitted query in persisted preferences.
- After relaunch, the actual original history contained the earlier entries אמר and בראשית. The exact new UUID row count was 0.
- The test stopped at the row-count assertion. `continueAfterFailure=false` meant its later preferences diagnostic was never executed.
- The collected logs contain no original `[GlobalSearch] submit` record for this case. There is no before-termination preferences snapshot.

The original `runSearch`, `addToHistory`, and SearchModeView binding code are identical between the tested source and this branch's base. The original navigation manager retains and binds the SearchViewModel. The audited fixture/launch code does not seed or reset `SearchHistory`.

These observations do **not** establish whether the missing entry resulted from an asynchronous preferences write, submission/validation state, or another app issue. The previous settled predicate allowed a path without a proved write. The next Native run will distinguish these cases and retain the original UI error/missing-index/dirty/cancelled/empty state when present.

The exact original failure timeline and final AX are preserved losslessly in `original/`. Complete Native88 evidence remains in commit [982793cbdc14aa910a8b164ab1a4956b7d8e775f](https://github.com/davidpovarsky/Maktabah/tree/982793cbdc14aa910a8b164ab1a4956b7d8e775f/docs/hq-integration/native88-44657116407-20261120).

## Ownership and observations

The runner's pre-install container URL supplies only the Simulator parent. XCTest may reinstall the app, so its earlier UUID is not accepted as current identity.

The read-only helper requires one UUID-named, non-symlink directory whose original Simulator metadata identifies `com.davidpovarsky.chavrusatext`. It pins that directory's standardized path components and complete metadata bytes before submission, and revalidates them before termination and after relaunch. An existing test-namespace sidecar must corroborate the same installation; feature-off tests are not made to create a sidecar.

Metadata and preferences reads require regular files and enforce byte limits. Only the known history/settings observations, installation UUID/count, and equality results are attached; no full preferences dump is produced. Original UI hierarchy and scoped state flags are attached before the new readiness assertion and before the final history-row assertion.

**Native boundary:** availability and byte stability of the original Simulator metadata across the real relaunch are not proved by the portable fixture. A missing, ambiguous, or changed installation fails closed and retains diagnostics. No arbitrary preferences-file fallback exists.

## Actual validation

The complete file-observation helper and the existing namespace-sidecar helper were extracted without rewriting and compiled against Foundation. Twelve unique named controls exercised actual disposable XML files: missing/foreign/ambiguous installation, pre-pin rejection, valid owner, other/duplicate query, changed metadata, foreign namespace, delayed test-owned write with no sidecar, oversized preferences, and byte-identical read-only behavior.

- Final controls: **12/12 PASS**, zero compiler warnings, 2026-11-20 06:57:39–06:57:45 UTC.
- Same exact twelve cases before the helper's two path comparisons were corrected: **9 PASS / 3 FAIL**. Foundation URL equality distinguished the directory marker from the same canonical path. Standardized path-component equality now preserves filesystem identity while retaining the exact metadata-byte and ownership guards. No oracle was removed.
- Two earlier fixture attempts are retained separately. Attempt 1 raised its aggregate error before buffered per-case output survived; no case-level PASS count is claimed for it. Attempt 2 reported 1 PASS / 11 FAIL with overlong fixture paths and insufficient I/O error detail. The fixture was corrected to short owned paths, explicit directory URLs, and flushed named/error reporting before the 9/3 source comparison.
- Full changed Swift file: Windows syntax parse passed. Two cross-target warnings are retained. This is **not** Apple SDK typechecking.
- Independent source review found no remaining ownership/readiness blocker. It explicitly retained the real metadata stability and Native UI gates.

`attempts/` contains raw results, command/source hashes, generated complete-helper source, compiler/runtime logs, and exact fixture versions. `SOURCE_PRESERVATION.json` proves all source outside the added helper and the one history exercise method is unchanged from `d05fbdd1abad848282000ba0e225cab686d4210f`. The final UUID expression and original UI assertions remain.

## Native cases affected

The focused regression cases are:

- `R27NativePadTests/testNormalBootstrapGlobalHistoryUsesActualSubmit`
- `R27NativePhoneTests/testNormalBootstrapGlobalHistoryUsesActualSubmit`

The same helper is used by Release's original global-history baseline and `testHistoryRemainsGlobalAndIsAbsentFromBookSearch`. This change does not alter `BookHistoryScopeAcceptanceTests` or `GlobalSearchNativeAcceptanceTests/testSubmittedCanonicalQueryReturnsInInlineHistoryAfterRelaunch`. The R27 source file/hash and manifest remain unchanged in this tranche.

Raw compiler/runtime/parse logs are stored as deterministic gzip, preserving their original whitespace and exact output hashes. Git whitespace checks apply to authored source/docs without rewriting the raw evidence.
