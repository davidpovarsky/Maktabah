# PERF01: separate full-v40 book/mode measurements

This checkpoint adds measurement source and native selectors. **It has not run the new native cases, compiled their Swift, queried a production corpus, or established a performance improvement.** The 58 retained controls exercise host admission and owned-process failure paths with synthetic records; small allocated-file controls use only disposable local scratch files.

## Source and ownership

New Oracle worktree: `/mnt/development/projects/worktrees/Maktabah-wave2-reader-perf01-20261127`, branch `codex/otzaria-wave2-reader-perf01-20261127`, based on root integration `883660701dd57c049de6da6fcf51a4027675409c`. The base Faithful file was read from the real Oracle Git checkout and its SHA256 was verified as `579cd7e23e7b80a62f568e3b6691a72a92178ebd35991f2d5782512f9f3189cf` before editing. Reversing only the appended section reproduces that entire file exactly, including the prior Search history cap and Groups/Reader work.

The affected test, host and catalog paths are downstream-owned: they are absent from the observed original upstream tree at `4203de5fd77beb119e5826e039be1a61325f7be0`. No application `Source/`, project membership, SDK, common/v32 driver, root wrapper/prerequisite, Build8401 file, existing test body or original catalog branch is edited.

| File | Delta and scope |
|---|---|
| `Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift` | Append nine registered selectors and their private helpers to the existing compiled file. All previous bytes remain. |
| `Scripts/CI/reader-v40-perbook-mode-performance.py` | New bounded host/controller. Reuses actual original installation, build/SDK, URL transport, resource/source host, XCTest and file-based zero-skip producers. |
| `docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift` | Two optional, mutually exclusive measurement branches. Existing `target`, preview-hit and default ten-target code remains byte-identical. |

The actual original requirements remain Asana `1219613714504405` (PERF01), `1219613714507780` (PERF02) and `1219613651433098` (PERF03). No numeric latency/FPS/SLA or performance improvement factor is introduced.

## Exact workload

Books are the independently observed v40 identities: Berakhot 103/2,875 rows, Tehillim 28/2,678 rows and Derashot HaRan 3152/528 rows. For each book the source executable asks the unchanged original service for Line, Paragraph and Chapter units at the actual first, middle and last SQL source positions. A fallback unit cannot replace the requested mode. All original anchors, source bytes and canonical locators are retained and checked.

Each book/mode cell runs six actual cold/warm pairs, in source-position order `first, middle, last, last, middle, first`. It therefore records 12 opens and 12 original overview interactions. Across nine cells: **108 opens, 54 pairs, 216 resource epochs and nine continuous trace bundles**. These are prospective counts until genuine execution completes.

Cold means the original app was terminated and a different actual native process PID is observed. The same ordinary document/group restores a real other book before the measured target is requested. It does not mean that OS/disk caches or every unobserved internal cache is cold. Warm means a genuine away navigation followed by a return in the exact same PID. Actual `native.reader` Core/glyph receipts and original source observations bind each operation.

The original display menu selects Line/Paragraph/Chapter. There is no reading-mode launch override or defaults mutation. The original persisted preference is read after the menu action and after relaunch, and its value is joined to the actual observed PID. Source, document, group, canonical unit and selected TOC are checked outside the resource interval.

The native unit route uses the original `OtzariaAppContainer.getTOCEntries` mapping `TOC.id = resolvedLineIndex`. Its original `TOCNodeRow` publishes `toc-row-<id>`, selected trait and `value=selected`. This is kept separate from Global Search's backend-renderer path and its negative registry surrogate IDs. No backend-rendered text or provider-hit receipt is relabeled as the native raw-unit source.

Each completed cell must retain exactly 24 original resource epochs, 30 original source proofs and 31 bounded persisted-mode observations. The host joins all six real before/after process boundaries, every warm away proof, every exact Core receipt, the source/owner identities, and each actual selected TOC observation. Extra, missing, duplicated or reordered records fail. It never calls the historical `complete_reader` with invented 20-row data.

## Distribution and measurement limits

Each `(book, unit mode, temperature)` distribution has **n=6**. It is a mixture of two observations at each of three source positions. The unchanged empirical nearest-rank method yields p50 at rank 3 and p95 at rank 6 (the maximum). It is not a reliable population or repeated-single-chapter p95. Individual values and order remain available.

Recorded measures are request-to-original-glyph-receipt visibility upper bound, original overview interaction upper bound, Darwin cumulative CPU difference and sampled app RSS. The original host's CPU/RSS start/end and end ACK are unchanged. Full source hashing, preferences, TOC and source observations occur after that ACK.

The Time Profiler bundle remains raw source-bound evidence until genuine schema, timebase, PID/thread and frame coverage are qualified. The new report explicitly leaves longest main-thread slice, MainActor occupancy, layout hitches/FPS, exact first pixel, continuous memory peak and before/after comparison unqualified. Qualified SQLite waits remain owned by the separate original full-v40/pending-SQL collectors; no one-host admission is copied to manufacture nine collectors.

The output is candidate-only. Before/after claims need two genuinely qualified builds with compatible actual source/workload/corpus/SDK evidence. Historical Windows component timing cannot become a native Apple baseline. A measurement completion is not full PERF01–03 acceptance.

## Runtime storage and ownership

Execution requires explicit per-cell trace and other-artifact byte reservations, a catalog/compiler reservation, known other-owner reservations, OS margin and an owned finalization margin. Admission accounts for all nine serial cells plus possible actual app/runner copies. It does not silently reduce the original installation gate or assume an arbitrary free-space target.

The original continuous trace is one bundle per cell, not one bundle per epoch. Live allocated-byte checks cover the original XCTest subprocess and the original verification/export subprocess lifetimes. On cap/deadline failure, only the owned `Popen` process group is stopped through the original `runtime27_interruption.py` helper, and normal owned trace cleanup follows. Failed native results, logs and partial traces remain. Finalization may add bytes; any cap failure invalidates the run and cannot be repaired by truncating or deleting evidence. No foreign process, simulator or file is touched.

The externally owned retained v40 Simulator is shut down and retained on exit. Current same-source app, complete SDK/test image closure, original installation receipts and final database hash remain mandatory. Installer acceptance retains its historical source attribution. The entire matrix uses the actual installed Mac database; the retired recovered Oracle source file is not a runtime dependency.

## Public host/compiler API

`compile_original_catalog(core, config, directory)` requires an existing canonical empty owned directory. It compiles the full original `catalog_compiled_sources` plus current `FullV40ObservationCatalog.swift`, writes actual compiler argv/source hashes/SDK compiler/ZSTD identity, raw log and actual exit receipt, and returns:

```text
binary: FileWitness
compileInputs: FileWitness
compileResult: FileWitness
sourceService: {path, sha256, compileInputsPath}
presentationSource: {path, sha256, compileInputsPath}
```

It does not open a corpus or execute the source catalog. The caller owns the separately retained input JSON, source execution exit/log and output admission. This seam is shared with the independently owned pending-SQL host; it does not change any original compiler/common driver.

Input `readerModeMatrix:true` writes `reader-mode-matrix.json`, status `ORIGINAL_SOURCE_READER_MODE_MATRIX_ONLY_NOT_UI_OR_PERFORMANCE`, with 27 complete raw source targets and the actual source/compile digests.

Input `pendingSQLModes:true` writes `pending-sql-modes.json`, status `ORIGINAL_SOURCE_PENDING_SQL_MODES_ONLY_NOT_UI_OR_PERFORMANCE`. It uses exactly book 8042/focus 26166 in Line/Paragraph/Chapter and rechecks the retained chapter `toc:1948815`, 52,332 rows, indices 0–52,331 and UTF16 length 8,307,947 against actual unchanged Swift output. It never fabricates a pending operation, a provider hit, or a shortened chapter. `previewTargets` and either other measurement flag must be absent. Explicit false/ambiguous flags fail; they cannot fall back to default output.

Source-only command:

```sh
python3 Scripts/CI/reader-v40-perbook-mode-performance.py source-check
```

Future actual execution requires a frozen qualified checkout/build, exact original retained installation result and explicit owned UDID, runtime environment and storage reservations. The CLI exposes those arguments; no command here is evidence of native execution.

## Evidence retained

`CONTROLS_01.json` is the actual 58/58 local host-control result. Its report explicitly says zero Apple compiler executions, zero native executions, zero corpus queries and no performance acceptance. `source-controls.py` is the exact runnable recipe. `CATALOG_PRESERVATION.json` and `SOURCE_PRESERVATION.json` document the byte-level unaffected bodies.

The 07:22:25Z read-only Mac admission stop is retained separately. Actual free space was 3,413,528,576 bytes and another owner's Hanlin native test process was active. No third compile was started. It does not supersede the two earlier retained precompiler stops, and it does not confer compilation or UI credit on this new source.
# Owned-runtime cleanup follow-up

Parent source review of the first checkpoint `8865c304` found that a failed
observer/trace/URL stop was recorded but did not prevent the outer controller
from terminating the retained Simulator. The follow-up propagates an explicit
in-memory `owned_runtime_cleanup` record for every attempted cell. Its default
is unverified, and it survives a failed result write. Simulator retention and
shutdown are deferred whenever any owned producer or native/exporter group
has no verified exit.

The original observation Thread is joined only after an actual thread identity
exists. An observer whose start was never attempted is recorded separately
from an interrupted start with no identity. The latter remains unverified.
Trace cleanup must retain the original `GONE_CHECKED` receipt for the exact
owned recorder process group; clearing its Python process field is insufficient.
The original URL transport must have an observed actual Popen return code.
Its scope is that transport process, without a claim about off-process
Simulator agents. Original native and result-export subprocess groups also
retain mandatory exact original cleanup receipts on success and failure.
Post-recording trace export failure remains a measurement failure even when
the recorder's exit was independently proved.

`CONTROLS_02.json` records actual local exit 0 with 74/74 source controls,
including 16 focused cleanup/environment cases added to the original 58.
No Apple compiler, Simulator, UI, production database or performance workload
ran. `CONTROLS_01.json` is retained unchanged for the original checkpoint.
The Swift UI and catalog bytes remain those of `8865c304`. The new host no
longer advertises the nonexistent historical `catalog.json`: its additive
cases use only `PERF01_READER_CATALOG_FILE` and the 27-target decoder. Their
reused launch/route/source/overview helpers do not invoke `fullV32Catalog`.
