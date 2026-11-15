# Inspector lease ACK — 2026-11-15

[נועם | DEV] [MAIN_SESSION]
ACK: OTZ-I-151126; transport confirmed OTZ-I-151126-DELIVERY.
Thread: 01a1dc8a-3c0e-7493-98cd-9a8062091a5d.
Manager: 01a1dc84-2697-7902-b100-9e23913eb7f4; sole dispatcher.
Worktree: C:/Users/DAVID/Code/Maktabah-hq-inspector-20261115
Branch: codex/otzaria-inspector-20261115
Base/HEAD before editing: df2a21941afa46da716387fce9de620865d2a151
Pre-edit git status --short and git diff --stat: empty.
Upstream main independently verified with git ls-remote: d46af139b3a265399c16d87f5923acd8e3444024. This object is not locally present; tree/merge-base verification pending read-only fetch before source edit.

## Explicit lease
Task GID 1219602987688876 only. Exclusive code ownership within Source/Otzaria/Reading: OtzariaLineSourcesService.swift, MaktabahTorahInspectorAdapter.swift, OtzariaInspectorRelationshipsProvider.swift, ReaderViewModel+OtzariaLineSources.swift, OtzariaLineSourcesInspectorView.swift, OtzariaLinkedSourceGrouping.swift, OtzariaLinkedSourcePreview.swift, OtzariaReaderSourcesInspectorHost.swift. Added tests/docs/tools only in Tests/HQ/inspector/**, docs/hq-inspector/**, tools/hq-inspector-*.
No AppContainer, ReadingUnitService/API, bridge, search/sidebar, Kit, project/lockfiles or shared HQ registers. No user DB, push/merge, CI, expensive builds or release. Local focused fixture checks and local commits [skip ci] authorized.

## Pre-edit provenance and plan
Read current source-repository policy, roles and registers plus HQ execution plan. Source/Otzaria/Reading is a downstream namespace; initial service history starts at ae89bf6f (Add Otzaria line sources inspector), not upstream. Verify upstream inventory before editing. Metadata-first, generation/cancel and hydration already exist and will be preserved. Diagnose only real remaining gaps; add 100/500/2000 link, failure/empty, cancellation and scope fixtures. Full production physical iPad/p95 and Sefaria/Notes runtime acceptance remain open.

## Rollback
Revert only lane commits on this branch; preserve concurrent work elsewhere. No upstream hook planned. Exact affected-file ownership matrix and checks will be appended before source edits.

## Confirmed ownership / pre-edit scope
Upstream FETCH_HEAD inventory has no Source/Otzaria files. Shallow upstream fetch prevents finding a merge base (NOT_ESTABLISHED; no ancestry claim). Source history confirms fork additions ae89bf6f (service/tap extension), 14ad47aa (shared inspector integration).

| File | Ownership | Planned edit | Alternative / necessity | Checks | Rollback |
| --- | --- | --- | --- | --- | --- |
| Source/Otzaria/Reading/OtzariaLineSourcesService.swift | DOWNSTREAM_OWNED; absent upstream d46af139 | Cancellation at DB entry, batch and row/decode boundaries | Current adapter propagates cancellation but service ignores it; keep shared SQLite untouched | Generated SQL on disposable SQLite fixtures, exact counts/snippets, pre/mid cancellation | Revert lane commit |
| Source/Otzaria/Reading/ReaderViewModel+OtzariaLineSources.swift | DOWNSTREAM_OWNED; absent upstream d46af139 | Remove unused eager commentary prefetch on tap; cancel pending anchor resolution on mapped/cached tap | rg confirms otzariaLinkedSources has no production reader; shared host uses session.repository metadata/hydration. Preserve selected locator/anchor and shell | Actual tap extension fixture with bridge call counters; source call-site review | Revert lane commit |
| Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift | DOWNSTREAM_OWNED; absent upstream d46af139 | contains only applies whole-unit membership to section scope; exact sourceLineIndices | Current contains admits neighbouring notes for segment scope and sparse gaps | Extract exact contains method into portable fixture; segment/section/backend/book tests | Revert lane commit |
| Tests/HQ/inspector/**; tools/hq-inspector-*; docs/hq-inspector/** | DOWNSTREAM_OWNED new | Small deterministic fixtures and evidence | No production DB, dependency install or broad compile | Local Swift + Python stdlib SQLite | Delete/revert lane additions |

No upstream source hook required; hook register: NONE. AppContainer and ReadingUnit contracts remain frozen.

## Same-lease follow-through: cold Notes query
Verified AnnotationManager is @unchecked Sendable, AnnotationStore/AnnotationRepository are Sendable and SQLiteDatabase serializes operations. notes(for:) currently calls loadAnnotations(bkId:) synchronously on MainActor; AnnotationStore hits SQLite on a cold book cache. This contradicts prior historical no-DB-on-MainActor claims. Adapter-only follow-up: await the existing book-scoped loader in a cancellation-linked detached task; validate generation/backend/book before applying results, preserving current in-memory annotations and note mapping. No AnnotationStore/API edits. Add exact-method fixture with a blocked loader/main-actor heartbeat plus cancellation/stale generation checks. Existing source matrix/rollback applies.
