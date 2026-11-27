# Inspector generation ownership after a library update

## Defect and repair

The reader workspace retains `MaktabahTorahInspectorSession` while its Inspector is hidden. The previous host put its generation observer inside the visible branch. A closed panel could therefore reopen the same Kit repository and adapter link/unit/locator caches after the managed database had changed. The caches use provider/reference keys; those keys alone do not identify a release.

The adapter now binds each repository to `BackendCoordinator.generation`. Its ordinary repository and selection entry points synchronously discard the previous repository and clear all adapter dictionaries and LRU lists when that generation changes. New fetch closures capture the admitted generation; old callbacks fail before reading, and suspended Sefaria document/link/topic responses are checked again before they mutate adapter state or return. Existing Otzaria detached-work cancellation and generation checks remain in place. All ownership state stays on MainActor, with no new storage/cache locks.

The host observes generation outside its visibility branch and performs initial admission. A host that just remounted refreshes the retained session without closing the Inspector that the user has just opened. An actual generation change while mounted keeps the existing close behavior. The generation-bearing view identity creates the current Kit subtree. The host never hands its new subtree a retired repository.

The pinned Kit has no general document/link/snippet invalidation API. The repair uses its existing initializer and leaves SDK source untouched. A previously retained external reference to an old Kit repository can still read that object's already-cached snapshot; this is why the host's ownership/admission boundary and new repository identity are part of the fix. Old asynchronous fetch callbacks are rejected. This is not a claim that every external reference to an SDK object is globally revoked.

## Actual Apple controls

On the Scaleway Mac, attempt 2 ran **2026-11-27 01:55:23.630929–01:55:49.596544 UTC**. Baseline: **2/12**, candidate: **12/12**, no skips. Baseline and candidate adapter files were compiled whole, unchanged, including their original `#if os(iOS)`. The runtime target was **Mac Catalyst**, `arm64-apple-ios17.0-macabi`, using the actual MacOSX27.0 SDK, Swift 6 strict concurrency, and Debug configuration. It did not launch a simulator or Maktabah application.

The same run compiled the complete pinned TorahInspectorCore and TorahInspectorUI sources at `23db0f84e88d9ee9c7053c49de86903fc7bb5785`, and typechecked each complete host file. Explicit host boundaries supply deterministic provider payloads, reader state, annotations and routing. The real adapter, actual Kit repository caches, actual LibraryBackendModels, reading-unit and line-anchor models remain in the control. A `Bundle.module` stand-in only supplies the package resource accessor for UI module typechecking. No linked-content classification, SQL, source corpus or rendered UI acceptance is inferred from these boundaries.

The controls cover same-generation cache reuse; reopening current documents, links, topics, notes and snippets; simultaneous Kit/adapter link-cache retirement for an unchanged reference; preserving the reader's open state during session admission; rejecting a retired repository's new callback; and generation changes during three independently suspended provider requests. The structural host witness records observer placement and conditional close behavior separately from runtime component results.

Attempt 1 is retained. Core/UI compiled, but the host boundary omitted its UI-only `TorahStudyTool` import. The harness was corrected using an explicit host-typecheck conditional; product source did not change between attempts. Attempt 1 is not counted as a product test or a passing run.

The final native receipt is `attempt-2/RESULT.json`, SHA-256 `949a8d016e0b0937887e5eeed6405655768bebb5ebfc4f9d2b95b087d43188ad`. Full commands, source SHA-256 values, stdout/stderr and case witnesses are retained. Logs are gzip-compressed with decoded hashes in `SHA256SUMS.json`. Native working directory: `/Users/m1/builds/otzaria-wave2-library-controls-20261127/inspector-generation-attempt-2`.

## Provenance and remaining acceptance

Baseline product files at worktree HEAD `7facfd4b167c2e3c3701dd5d40798ba8e5436844` are byte-identical to root integration `cce695b38e801c1121524ed8776d6606604d7778`. Both paths are absent in exact upstream `4203de5fd77beb119e5826e039be1a61325f7be0`; these are project adapter/host additions, not edits to upstream SDK internals.

| Source | Baseline SHA-256 | Candidate SHA-256 |
| --- | --- | --- |
| MaktabahTorahInspectorAdapter.swift | 96be0359332277861cc7731c92727fee975c05b838f7464978124801e12ac53e | b9b64795eee6afdb204fde4f31d96e38a2513c8caf4929dee1acfd03410e4c4b |
| OtzariaReaderSourcesInspectorHost.swift | 2f53c4136145100382ea86dd2b659c8457ec7b56e19173eafb8d7c0ba464fa25 | 2fc2eaf83bb56c63be833691a6e8d0df96bde09660f377f2dca06138460a92b7 |

Original application UI acceptance remains **NOT RUN** for this repair. The combined candidate must close/reopen the actual Inspector across Books Updates and backend/resource changes, with real source/content witnesses. The existing full-v40 source hash/count receipts, published search artifacts, SQL relationships and prior reader performance receipts retain their original scope.
