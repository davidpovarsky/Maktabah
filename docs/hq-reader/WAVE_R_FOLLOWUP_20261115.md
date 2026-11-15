# Reader R follow-up — complete source coverage and genuine model rendering

Same R ownership/authorization/worktree as `WAVE_R_20261115.md`. Base
`fea866a005a636bb123504a0522fa7989b42c817`; the commit containing this
report is the follow-up source tranche. Manager has accepted the first
tranche for coherent integration; no merge or workflow copy is performed here.

## Additional repairs

- A descriptor with a nonempty requested source set now fails explicitly if
  **all** requested rows disappear, matching the existing partial-row failure.
  The earlier empty-result guard had incorrectly returned `nil` before coverage
  validation. A deliberately empty descriptor still returns `nil` normally.
- A row whose `LEFT JOIN line_content` payload is SQL NULL now fails as
  `inconsistentSourceLines`. It previously passed row-count validation while
  the decoder returned empty text for NULL, creating a blank source segment.
  Real empty TEXT remains valid. No shared decoder/API is changed.
- Root-title classification counts direct root mappings once instead of
  scanning/sorting the book's entire mapping dictionary separately for each
  root. Existing three-line title attachment, four-line standalone units,
  root isolation, sparse membership, cycles and adjacency are retained.
  This removes a roots-times-lines loop; no device timing inference is made.
- The existing downstream `String.readerPlainText` skips the HTML, entity and
  paragraph-marker transformations when their ASCII trigger is absent. The
  exact existing rules/order and whitespace trimming remain. This uses the
  same neutral render model, not another renderer or text view.

## Ownership

| File | Origin/ownership | Scope and alternative |
|---|---|---|
| `Source/Otzaria/Reading/OtzariaReadingUnitService.swift` | DOWNSTREAM_OWNED; absent upstream d46af139 | Exact coverage/NULL-payload guards and single-pass root classification in existing service; no DB wrapper/engine change |
| `Source/LibraryBackend/LibraryBackendModels.swift` | DOWNSTREAM_OWNED; absent upstream d46af139 | Existing normalization extension only; avoid unnecessary passes rather than changing TextKit, UI or the upstream callsite |

Pre-edit matrix: `HOOKS.md`. No original Maktabah code, project registration,
dependency, shared contract, workflow or release gate changed. Revert only
this follow-up commit to roll back; retain fea866a0 and all other worktrees.

## Actual verification

`results/wave-R-before-empty-unit`: actual-source service compile 0 / run 1,
explicit fully-missing-rows regression. `results/wave-R-before-null-content`:
compile 0 / run 1, explicit missing-joined-content regression.

The corrected actual-source service and bridge suites passed in
`results/wave-R-followup`, using the existing test runner:

```text
py -3 tools/hq-reader-checks.py --suite service --artifacts-dir docs/hq-reader/results/wave-R-followup
py -3 tools/hq-reader-checks.py --suite bridge --artifacts-dir docs/hq-reader/results/wave-R-followup
```

Bridge fixtures retain explicit DB/decoder/app/mapper doubles. The genuine
render check extends the same runner with the SHA-verified official
miniTest10-v6 fixture. Python/zstandard prepares source strings from the
read-only released database, then Swift compiles the **complete actual
LibraryBackendModels.swift** and constructs the existing render model with
every source row. It checks all locator identities/order, complete nonempty
segment counts, nonoverlapping UTF16 ranges and exact visual substrings.
The source/translation/both mixed Hebrew/Arabic/English/combining/emoji tests
and nine escaped-markup/entity/marker ordering cases also pass.

```text
py -3 tools/hq-reader-checks.py --suite render --database build/hq-reader-corpus/seforim.db --artifacts-dir docs/hq-reader/results/wave-R-genuine-render-after
```

All **6,081** genuine source rows remain rendered: Berakhot 2,875; Tehillim
2,678; Derashot HaRan 528. Their full rendered UTF8 outputs match the old
normalization byte-for-byte by SHA256 (`output-parity.json`), respectively:

```text
103  518a41e341f0626e1b70f0d2326d0a824e8eb9f267156d0bcd160887a23ffd04
28   3c6f5956581496a2181c7884c57280f45c14f249564e46e26ae1517912482e18
3152 65947e88d7b2bf5e4a957110329866605de784e954f299fcf37a28b4716e147a
```

Only digests/counts/logs are retained in Git; full source/render strings are
temporary fixture files. Exact released-input and output hashes are in the
before/after corpus artifacts. `wave-R-genuine-render-before` is an earlier
baseline; `wave-R-genuine-render-before-hashes` is the baseline that also
captured full-output hashes. Both use the unchanged renderer at fea866a0.

Five-sample **Windows neutral-model-only** timing observations, rounded ms:

| Genuine whole-book input | Before p50 / max | After p50 / max |
|---|---:|---:|
| Berakhot | 2942 / 3096 | 540 / 571 |
| Tehillim | 1170 / 1531 | 344 / 490 |
| Derashot HaRan | 1018 / 1182 | 197 / 252 |

These are unoptimized portable fixture runs on a shared Windows workstation;
the before run also overlapped a bridge compilation. They do not establish
an isolated speedup factor, p95, first-content latency, RSS, MainActor time,
native chapters, TextKit or physical-iPad acceptance. The deterministic
result is identical output with fewer irrelevant transformation passes.

The real-corpus SQL check also still passes 18,246 metadata queries and
covering-index plans. The new Python fixture preparation does not establish
production Swift/ZSTD or SQLite concurrency correctness. Existing healthy
cache/SQL checks from fea866a0 remain attributed to that exact run; they were
not repeated to inflate test counts.

## Remaining work and integration boundary

PERF-01/02/03 and physical PERF-04 remain OPEN. No native application test,
physical iPad, full installed DB, 100/500/2000 actual app links, lock-wait/RSS,
TextKit selection/notes/scroll/highlights/relaunch or cold/warm p50/p95 result
is supplied by these portable/model checks. The full released *books* here
are still contained in a small corpus profile, not the full production DB.

Read-only callsite review found upstream `Reader+Content.swift` constructs
the neutral render model synchronously after the async section load. The
normalization optimization reduces work but does not change thread placement.
Actual native profiling on the manager's coherent candidate should determine
whether a narrowly authorized background-preparation hook is still needed;
do not claim this packet moved TextKit or that callsite off MainActor.

No native CI was dispatched from the older standalone R tree: manager owns
coherent integration with its retained Pods/workspace/R27 validation packet.
No release/user-data operation or source edit in another developer's tree.
