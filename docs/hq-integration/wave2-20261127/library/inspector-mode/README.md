# Inspector text-mode admission across host remounts

## Source defect and repair

The workspace retains `MaktabahTorahInspectorSession` in `@State`, but the entire Inspector host receives an identity containing `currentReaderTextMode`. Changing that identity can create a new host whose non-initial mode observer has never seen the old value. Closing the panel while the reader changes mode creates the same admission problem. The Session's `preferredMode` is immutable; its separate resource-generation refresh cannot repair a stale mode. The initial generation fix in `9d4c6ded641fad00cb9e0ca6fd0b931731e5c3fd` retains its original scope and does not claim this additional repair.

The host now runs its mode observer on initial appearance as well as subsequent changes. The actual Session owns `replacementForTextMode`: it returns no replacement for an already matching mode and otherwise creates a distinct Session using the same coordinator/bridge and the current reader. Thus a matching initial open retains its Session, Kit repository and adapter caches. A changed mode gets a distinct cache owner. No workspace, SDK, routing, selection or reader-mode control source is changed.

Generation admission and its conditional close behavior are byte-identical to the previous host. Either callback order for a combined mode/resource-generation change admits the current generation and current mode. The component controls exercise both orders. They also exercise matching-mode close/reopen, a changed mode retained while hidden, source/translation/both/source document mappings, and completion of an old source request after the new translation repository has loaded. A separately retained old Kit repository can keep its own old snapshot; it cannot populate the new Session's repository.

## Exact source provenance

The source audit read root `a1899e8eecdea96a482df5d34ed8d988197ac82b`. Its three relevant files are byte-identical to this worktree's parent `f75eb8f16a4c826e829ebe613c88de9788b3291f`. The unchanged workspace source has SHA-256 `fa5c00a3544b2543e1e482d6f1fb97b8a2a12f87c8cae6bd67c536c1b8d7fb38`; it owns the Session and the outer identity. The affected adapter/host paths do not exist in exact upstream `4203de5fd77beb119e5826e039be1a61325f7be0`; they are app integration sources, not modified SDK internals.

| Product file | Before SHA-256 | After SHA-256 |
| --- | --- | --- |
| MaktabahTorahInspectorAdapter.swift | b9b64795eee6afdb204fde4f31d96e38a2513c8caf4929dee1acfd03410e4c4b | 722c3e6dae328a217944d5298f60a2d6afc5125fdced02821cf34f2621d3b9e4 |
| OtzariaReaderSourcesInspectorHost.swift | 2fc2eaf83bb56c63be833691a6e8d0df96bde09660f377f2dca06138460a92b7 | b5166743145329783d5650aed8caffeb6fc755b599987ae7629cb75893a6d006 |

`HOST_SOURCE_ADMISSION.json` records the missing baseline initial observer, candidate initial observer, guarded replacement and unchanged generation callback. This is a structural source witness, not execution of SwiftUI lifecycle. Its input script uses the exact full product files and unchanged workspace file, not a rewritten lifecycle algorithm. To reproduce that structural witness, obtain the baseline host and workspace from the parent commit and pass the containing directory and workspace path to `InspectorModeSourceAdmission.py`.

## Actual Apple validation

One focused Scaleway Mac run completed **2026-11-27 03:18:48.982789 to 03:18:55.262258 UTC** in `/Users/m1/builds/otzaria-wave2-library-controls-20261127/inspector-mode-attempt-1`:

- The complete candidate host and adapter passed actual Swift 6 strict-concurrency typechecking with MacOSX27.0 and target `arm64-apple-ios17.0-macabi` (Mac Catalyst), exit 0.
- The complete candidate adapter plus actual pinned TorahInspectorCore repository passed **8/8** component controls, exit 0. The source provider and reader/annotation/routing boundaries are explicit synthetic fixtures. Both source and translation payloads are supplied by those boundaries, not by a production database or network.
- The existing Kit modules and four original model files from `inspector-generation-attempt-2` were reused. Their complete original source hashes were checked against that actual successful build receipt, SHA-256 `949a8d016e0b0937887e5eeed6405655768bebb5ebfc4f9d2b95b087d43188ad`; current module/dylib hashes are recorded separately in the new receipt. Kit revision remains `23db0f84e88d9ee9c7053c49de86903fc7bb5785`. No new Kit build or module-cache directory was created.
- Free space was 4,386,676,736 B before and 4,385,751,040 B after this small run. PID 70382 was absent from the subsequent read-only process inventory. No simulator, application build, database download, corpus recount or cleanup ran.

The immutable native result is `attempt-1/RESULT.json`, SHA-256 **`8cc3ca48d5399d1696155d28cf980a8d74aad6559eb59694528a2f4bb0e41c9e`**. Exact compiler/run commands, source/module hashes, timestamps, synthetic payload witnesses and all stdout/stderr are retained. Logs are compressed without changing their decoded contents; `attempt-1/SHA256SUMS.json` contains both encoded and decoded hashes. There is no baseline runtime pass/fail claim for this new API: the baseline failure is the precisely identified source admission gap, while the runtime cases execute only the actual candidate API.

## Required original UI acceptance

**NOT RUN**: the real app must still change source to translation and back in the same reader tab, with the Inspector visible and after close/reopen, and assert actual displayed body/reference/version against the selected mode. The combined candidate should also cover simultaneous backend/resource changes. The eight component cases and whole-host typecheck do not replace this gate. Production v40 database identity, search package validation, previous generation controls, installer controls and saved-object update checks retain their own receipts and scope.
