# Owned local annotation cloud completion — prepared Apple component gate

## State and exact source

The opt-in implementation is source **57e4a1cb7cd0bee72e3042e2f4567972237e7e35**, based on the already authenticated local43v2 result commit **0fe26c3c5bfbe8675e063777371dbeca6685cf4a**. CI preparation is **826711a577063cacac28ed2f24a0daa0603d2e28**. Both are published only to `codex/otzaria-local-annotation-cloudkit-owner-20261120`.

The exact future execution branch is `codex/otzaria-local-annotation-cloud-apple-reviewed-20261120`. It was absent at publication readback. Root owns any activation. No workflow rerun, dispatch, frozen-ref rewrite, Swift compiler installation, or live CloudKit request was performed by this tranche.

All 96 raw input files were independently compared with their canonical Git blobs in the published CI tree. The source gate pins 39 explicit inputs, the whole original Core tree with 53 files, and four application trees from source M. The original Core tree is **5d0ee482c8f10726fe3863792dac94c18e94d792**; this component route does **not** claim the later Core194 source or acceptance.

| Evidence | Actual state |
|---|---|
| Complete product inverse and preservation | PASS, eight product/project files; original paths below preserved |
| New Python gate controls | 43/43 PASS on Linux; synthetic process receipts and real original SQLite schema |
| SQLite pending/counter/transaction premises | 13/13 PASS on SQLite 3.53.1; zero Swift or CloudKit execution |
| New owned-cloud Swift controls | 48 declarations, **NOT_RUN** |
| Original local-body Swift controls on M | 43 declarations plus two cold reopens, **NOT_RUN** on this changed source |
| Original exchange regression on M | 28 declarations plus two abrupt-process reopens, **NOT_RUN** on this changed source |
| Original CloudKit SDK types and new adapter | Source-reviewed; whole-source Apple compilation remains **NOT_RUN** |
| Live account transitions, CloudKit transport, app/Anytype UI and physical devices | **NOT_RUN** |

The prior local43v2 Apple success remains in ancestry and is not transferred to these new cloud sources.

## Concrete consumer and unchanged original behavior

The existing `AnnotationLocalEditorSession`, obtained from the original `AnnotationStore` for an already-saved annotation UUID, now exposes an explicit `prepareOwnedCloudSave` / `saveOwnedCloud` path. Preparation captures the original local intent and real account observation before committing. The ordinary `read`, `prepareSave`, `save`, Save/Cancel/tag flows, original default CloudKit callback, and original queue schema remain unchanged.

There are eight product/project changes: two new cloud files, three existing local-editor files, a small original SQLite serialization helper, the original Core optional notification hook, and registration of the two new files in all three existing app targets. `AnnotationRepository`, `AnnotationStore`, `SyncPendingStore`, `PendingSyncCoordinator`, `CloudKitSyncManager`, the original annotation CKRecord mapping, and the original debouncer have no edits. No engine, Core package, framework version, account/Space provider, or live-exchange capability is changed.

The Core hook keeps the original completion parameter last. With its default nil notification argument, original completion-before-worker notification remains exact. The new operation suppresses only that invocation's default worker scheduling and retains the original configured request for its own later admission. `workerRequestSnapshot` only reads the original request builder.

## Account, source and completion ownership

An owned preparation uses the original configured Core/container/private database and original annotation zone through immutable client closures. Before committing, it observes `CKAccountChanged`, resolves the real current account, and binds the observed identity to a one-way lifetime. A missing or failed identity leaves a durable local pending upload and never adopts an account discovered only after commit. The observer stores identity internally; no private account identifier is reported.

After the original debounce, after account awaits, after the admitted upload, and before worker/delivery publication, the code rechecks the captured account, editor, connection, source/version, and exact pending witness. A delivered account-change notification permanently retires the preparation even if the same identifier returns. Account refusal at the locked boundary is translated specifically to `accountChanged`, without reacquiring the lifetime mutex. Errors from the protected database body keep their original identity.

The checks define local admission points. They do not make an OS account transition or remote CloudKit operation atomic. A write already admitted to the original transport may finish after retirement or a newer local write. Its actual success or error is retained independently of whether local pending acknowledgment, worker publication, or editor delivery is refused. There is no remote cancellation, rollback, retry, or conflict-resolution claim.

Only the original plain annotation record is transported by this path. The rich local body stays in the original local ledger, with explicit exchange destinations `[]`. This work does not invent an Anytype account, Space, destination or editor mount.

## Exact pending acknowledgment and lock order

The local commit runs on the captured original SQLite handle. It must own a real outer commit; a caller's surrounding transaction cannot manufacture a durable receipt. After the original note/ledger/pending writes, it captures the exact pending row, SQLite `total_changes64` and `data_version`. A post-commit failure preserves the actual saved receipt and refuses transport authority rather than throwing as though the committed save rolled back.

Acknowledgment acquires **database serialization → editor lifetime → captured connection lifetime → account lifetime**. It validates the immutable source/version/receipt, exact pending row and write counters, executes the conditional deletion, and keeps those lifetimes through the original transaction's commit. There is no await, transport, live repository lookup, or callback added in this critical section. An unrelated intervening write conservatively defers acknowledgment.

The deletion binds rowid, original record-id bytes, upload operation and exact queue timestamp. This protects a newer same-UUID pending version; a timestamp-only cutoff is insufficient for replacement in the same second. Foreign committed replacements and ABA changes are checked with `data_version`. A foreign WAL commit after the read snapshot prevents the stale reader from upgrading to the deleting transaction. The genuine SQLite controls exercise those premises, including identical rowid/value replacement and the actual `SQLITE_BUSY_SNAPSHOT` result.

The lock review is scoped to this new path. Peer review found a **preexisting** Repository state→DB versus DB→state inversion involving disconnect/checkpoint and legacy transaction helpers. Root owns its separate investigation. This tranche does not claim whole-application deadlock freedom and does not edit that Repository file.

## Whole-source Apple gate

`tools/hq-local-annotation-cloud-acceptance.py` compiles 23 complete Swift files for the original43 executable and 23 for the new48 executable. The new executable additionally receives the exact, hashed original `LocalFixture` prefix from the unchanged original43 source. It does not substitute production persistence, ownership, database or SDK classes. `COMPILE_INPUTS.json` lists every file and the generated prefix boundary.

Whole original `CloudKitCoreManager`, `CloudKitSyncable`, `AnnotationSyncHandler` and `CloudKitUploadDebouncer` compile against the installed Apple SDK. The new controls exercise the real CKRecord mapping and one real original default two-second debounce, without a live account or transport. Explicit doubles cover account lookup outcomes, notification-center events, transport outcomes and wait scheduling. The preexisting catalog/UI/locator/color and five localization accessors remain explicit component boundaries. A disabled settings boundary prevents the Foundation test executable from constructing a real CKContainer. The exact original `AppConfig.swift` is separately pinned as boundary-declaration evidence.

The 48 cases distinguish preparation refusal, account/source changes during awaits, observed account ABA, editor/profile retirement, newer same-UUID revisions, same-second pending replacement, foreign committed changes, actual remote error/success after retirement, worker request changes, actual acknowledgment before later retirement, one-use/foreign preparation, nested transactions, ambiguous pending keys and isolated notification owners. Gates are released and retained tasks joined on both success and failure paths. These are declarations and source-reviewed controls until Apple executes them.

The driver also runs the entire unchanged original43 source, original cold validators and three separate processes with the same 480-second compilation, 180-second component, and 45-second cold-process limits. The new48 process has its own bounded 180-second limit. The original28 exchange driver and its process-termination/reopen assertions remain unchanged.

The final CI verifier requires exact named counts, zero failures/skips, original process exits, complete source before/after archives, exact compiled copies, cold lineage/independent SQLite readback and original queue bytes. `continue-on-error` retains each driver's evidence; the always-running final gate still exits nonzero on failed, skipped or incomplete outcomes. Job60 leaves nine minutes beyond the sum of stage maxima for checkout/upload, without increasing any fixture timeout.

## Retained unsuccessful preparation attempts

The first SQLite premise run was 8 PASS / 1 FAIL. Its incorrect assumption was that a foreign `UPDATE queued_at=queued_at` necessarily advances `data_version`. SQLite optimized that no-op without a physical database change. The actual original enqueue uses `INSERT OR REPLACE`. The retained diagnostic and final13 controls distinguish that original replacement, forced identical-row replacement, committed ABA and a true no-op; no product guard was weakened. This is not described as Swift product RED→GREEN.

A source-inverse verifier first expected the old Core upload signature in multiline form, while the genuine original was one line. The failed verifier source/log and corrected exact inverse are retained. A publication readback initially expected blob SHA fields in the connector's compact compare output; that output contains names/stats only. The final proof uses the complete canonical Git tree for all 96 blob checks. Neither preparation error is an Apple or product execution result.

## Remaining boundaries

Actual Apple typechecking and all new Swift race controls must run before qualification. Live notification timing, real account changes, service errors and remote effects need separate live acceptance. A setting change not delivered through an observed account or captured connection retirement is not proven as a historical permission epoch by current-state Boolean reads alone. Existing background sync and other default consumers remain unchanged and are not qualified by these controls.

After an acknowledgment really commits, later retirement can refuse delivery but cannot truthfully erase that committed effect. After an upload is admitted, later retirement can retain the pending row but cannot assert that the remote effect did not occur. Future mounted-editor and live-transport consumers must preserve those distinctions and revalidate their own current ownership.
