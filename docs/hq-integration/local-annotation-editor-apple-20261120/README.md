# Exact Apple gate for the original local annotation consumer

## Delivered state

Prepared and published CI source: `6cd53aae3dbf6b443ab74ad6eff926e8ea529338`, parent `b19d30d9db402ef267e0d3afcc4dece0be013f24`, on author branch `codex/otzaria-local-annotation-editor-apple-ci-20261120` in `davidpovarsky/Maktabah`.

The commit adds four CI files. It changes no application source, project, Swift acceptance declaration, original driver, engine, dependency, user data, or previous workflow. The complete original local-body implementation remains source `4be6c9b27fa6c882275cddf209f5959cb9b9690b` and its evidence remains under `docs/hq-integration/local-annotation-editor-20261120`.

**Apple execution is NOT_RUN.** Actual local verification is Python 28/28, zero failures/errors/skips, 30 source inputs unchanged, two Python AST parses, YAML parsing, original command/driver preservation, Git compare and ref readback. The first 27/27 Python attempt is retained. The final attempt adds a discriminating check that changed or missing source bytes are retained as `UNVERIFIED_AFTER_FAILURE`, never as acceptance.

The exact activation branch is `codex/otzaria-local-annotation-editor-apple-reviewed-20261120`. GitHub returned 404 for that branch during preparation. It was not created, pushed, dispatched, or otherwise activated by this author. Root owns integration, review and activation; existing immutable CI branches are untouched.

## Selection and original behavior

The one Apple job executes these original commands, sequentially:

```sh
python3 tools/hq-local-annotation-editor-acceptance.py --artifacts-dir build/local-annotation-editor-acceptance
python3 tools/hq-annotation-exchange-acceptance.py --artifacts-dir build/local-annotation-editor-exchange-regression
```

| Component | Required actual outcome |
| --- | --- |
| Maktabah local annotation consumer | All 43 exact named component cases, no failures or omissions |
| Local durable body | Three separate executable processes: initial write, cold reopen/save revision 2, second cold reopen; three distinct observed PIDs and exact lineage; two completed reopen gates |
| Original exchange regression | All 28 unchanged named cases, including existing concurrency, unknown-version, queue and identity assertions |
| Original abrupt recovery | Both unchanged after-commit and before-outer-commit termination/reopen gates, actual exit 73 followed by successful separate verification |

These are **Maktabah local-body 43 cases**, not the separate original Anytype 43 suites. The local driver compiles the whole original AnnotationStore, AnnotationRepository, SQLite, queue, codec, ledger and new local session with the whole local Core package. Catalog/UI/CloudKit boundaries remain explicit component doubles. The old exchange driver and its Swift assertions are byte-identical to b19d.

The workflow uses the existing `xcode-27` runner and unchanged `select-runtime27-toolchain.py`. It installs no compiler, SDK or runtime, changes no global Xcode selection, and boots no simulator. The helper selects the original available Xcode/runtime pair; selection itself earns no Native result.

All original internal deadlines remain unchanged: local compile 480s, binary-path lookup 30s, cases 180s and each of three cold processes 45s; exchange compile 300s, cases 150s and each of four termination/verifier processes 40s. Outer workflow steps allow 960s for local and 840s for exchange; the job allows 3000s with headroom for source/toolchain/control/evidence work. The original exchange `--show-bin-path` lookup has no inner timeout and is unchanged; the outer step bounds a stuck process without changing an assertion.

Both driver steps retain their actual outcomes. `continue-on-error` only allows the second independent regression and final collection to run after a failure. The final `always()` gate requires both original step outcomes to be `success`, all exact rows and process results, independent SQLite/byte checks, and unchanged source. It returns nonzero for any failure, skip, missing report, wrong source or partial result. Artifact upload is also unconditional.

## Exact source binding

`Scripts/CI/local-annotation-editor-apple.inputs.json` pins 26 complete original source, driver, fixture and provenance files by byte count, Git blob and SHA-256. It also binds the entire original Core tree:

`Source/Otzaria/Actions` = `5d0ee482c8f10726fe3863792dac94c18e94d792` (53 files, 644,479 bytes).

That is the Core source at b19d. It is **not** the separately repaired Core194 source. Root explicitly selected this exact component-source gate; later integrated app/Native acceptance must use and qualify its own combined source. A changed Core tree fails this gate and requires an explicit reviewed repin.

At execution, current Git HEAD must equal the push SHA and workflow SHA, on the exact repository ID, workflow path, ref, run and attempt. All tracked inputs must be clean and match their Git blobs. The gate captures all 26 pins, every file in the 53-file Core tree and the four new CI files before and after execution: 83 original/CI files. It rejects added untracked Core `.swift`, `.json` or `.resolved` inputs and linked source files. Copied executable source files are compared to those exact repository files after execution.

Both complete raw source archives are uploaded on the successful path. A source rejection after execution also attempts a separate unverified capture of the original before-inventory paths, preserving actual changed bytes and missing/unsafe-file errors without granting acceptance. The local preparation packet authenticates the full Core Git inventory; it does not pretend that the 53 Core files were compiled locally.

Final verification reuses the original local driver's cold-process and independent SQLite functions. It checks the same original annotation UUID and row, immutable two-version payload bytes, current head, tags, durable original pending upload, unrelated pending delete and zero external destinations. The original exchange payload hash and before/after queue bytes are independently read again, together with its WAL/crash/verifier logs. Original exchange child PIDs are not invented: its unchanged driver records process commands and exits, while the new local cold gate records its three actual PIDs.

## Evidence and replay

`SOURCE_PROOF.json`, `WORKFLOW_PROOF.json` and `SOURCE_PUBLICATION.json` bind the source, selection, preservation checks and actual Git publication. `PEER_REVIEW.json` records B's source-only review and its limits. `RAW_INVENTORY.json` binds all 43 retained raw files, including the 30 current source inputs used by the Python controls, the authenticated Core tree, original plan, both Python attempts and publication receipts. The three changed files from attempt 1 were recovered by exact inverse of the later failure-capture addition; each recovered byte count, SHA-256 and Git blob equals that attempt's original before/after receipt. The other 27 inputs are identical. This recovery is not a rerun or a new execution claim. All JSON and source artifacts in this packet use UTF-8 LF.

```sh
python3 docs/hq-integration/local-annotation-editor-apple-20261120/verify-evidence.py
python3 docs/hq-integration/local-annotation-editor-apple-20261120/verify-evidence.py --replay-controls
```

The optional replay extracts only this verified small source projection into a temporary owned directory and runs the Python controls. It invokes no Swift, Apple toolchain, engine, app, network or user database.

## Acceptance still open

This preparation grants no Apple compile/runtime result, XCTest UI result, actual Maktabah application relaunch, Anytype importable renderer/mount, Anytype opaque-format compatibility, live exchange, account/Space authority, remote rollback or physical-device result. The unchanged CloudKit pipeline's later detached/debounced transport and account/profile completion isolation remain a separate integration boundary. Passing this future component job would qualify only the stated actual Apple Foundation and owned SQLite component behavior on its immutable source.
