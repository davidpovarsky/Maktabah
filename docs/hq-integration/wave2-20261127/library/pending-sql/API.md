# Root integration API — separate pending-SQL phase

This is a **new standalone production-study phase** for one registered selector. Do not add it to the original two-case v40 `execute`, historical v32 run, shared driver or an active resource/Inspector epoch.

## Committed source closure

Before freezing the qualified source/build, the root registers all required paths in the **actual v40 profile's `execution_input_paths`**. The original `core.source_context(require_frozen=True)["execution_inputs"]` must contain exact `{bytes, sha256}` for the collector's existing six paths and:

- `Scripts/CI/study-ui-pending-sql.py`
- `Scripts/CI/reader-v40-perbook-mode-performance.py`
- `Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift`
- `docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift`

The controller's additional `study_ui_execution_sources` section alone does not meet this gate. Do not use an out-of-profile closure override. Use the real original source context, same-source build receipt, current installed images and retained installation owner.

## Call sequence

Load a **fresh original v40 core module** for this phase, retaining the original `ObservationHost` class. Set a fresh owned `core.OUT` and write its exact `source-before.json`. The caller already owns runtime/device/source/build and original installation-result admission, and reserves space for all other active owners.

```python
# Owner and source/build setup are the original controller's actual admission.
# No API here installs/downloads, starts a simulator, or launches an app.
database, installation = wait.bind_admission(
    core, retained, retained.admit_current_installation,
    config, udid, build,
)

pending_dir = core.OUT / "pending-source-catalog"  # must not exist
pending_catalog = pending.prepare_catalog(
    core, config, installation, pending_dir,
    reserved_other_bytes=actual_concurrent_reservation_bytes,
)

observer = pending.PendingSQLHost(
    core, udid, actual_current_data_container, installation,
    pending_dir, pending_catalog,
)
runner_environment = observer.start()
# Start/retain the controller-owned original R27 URL transport and the
# exact registered native case using the same owned simulator/current build.
# ... existing native execution and independent xcresult export/verification ...
proof = observer.stop()
```

`prepare_catalog(...) -> dict` invokes the shared complete-source compiler and original Swift `pendingSQLModes` branch once. It writes the real compiler log/result/inputs/executable, exact input JSON, actual execution command/log/exit, complete output references and `execution-result.json`. A failure keeps the complete failed attempt and raises. No native UI pass is manufactured. `PendingSQLHost` consumes the sealed execution, compiler and source witnesses against the same fresh current installation admission.

The original host receives this **actual three-mode catalog** as its map. There is no default ten-target compile just to initialize an unused map. `TEST_RUNNER_FULL_V32_CATALOG_FILE` is explicitly omitted, so no nonexistent `catalog.json` is advertised.

## Environment and actual native case

The host returns the original `TEST_RUNNER_FULL_V32_OBSERVER_TOKEN` and these additional variables:

| Runner environment | Meaning |
| --- | --- |
| `TEST_RUNNER_PENDING_SQL_MODES_CATALOG` | Actual immutable `pending-sql-modes.json` absolute path |
| `TEST_RUNNER_PENDING_SQL_MODES_CATALOG_SHA256` | Exact raw catalog SHA-256 |
| `TEST_RUNNER_PRODUCTION_SEARCH_CONTAINER_PARENT` | Fresh current MCM app-container parent; native code rediscovers the actual owner |

The native runner sees the names without `TEST_RUNNER_`, as in the existing original driver. The root also supplies its existing `R27_URL_TOKEN`, `R27_URL_UDID`, actual `SIMULATOR_UDID` and original runtime/build configuration. The host does not own the URL transport or native process group.

Only-testing selector:

`Maktabah-iOSUITests/FullV40ReaderModeAcceptanceTests/testOriginalLargeChapterPendingFetchRemainsInteractiveAndRejectsSupersededContent`

The genuine earlier Reader/Notes UI work must leave a nonempty original `Annotations.sqlite`. Run this phase **before Books Updates**, while the exact installed original production v40 manifest/database and both-package/other phase state are still retained. No fixture or namespace seeding can satisfy this dependency.

New native attachment stems:

- `pending-sql-original-nonempty-annotations-before`
- `pending-sql-original-focus-route-<UUID>`
- `pending-sql-original-cohort-overview`
- `pending-sql-original-cohort-unit-supersession`
- `pending-sql-original-cohort-backend-and-tab`
- `pending-sql-original-final-<cohort>` and its hierarchy
- `pending-sql-original-failed-<cohort>` / `pending-sql-unqualified-status-<UUID>` when applicable
- `pending-sql-original-three-cohort-summary`
- `pending-sql-original-host-completion` only after every assertion and host cohort succeeds

## Output and qualification

`<OUT>/pending-fetch-correctness/INPUTS.json` binds the actual admission, retained `hostClock`, source execution, complete source references and exact selector/schedule. `installationManifestCopy` identifies the byte-exact artifact `admitted-installation-manifest.json`, copied from the already verified original admission metadata. Under each cohort UUID, every raw request/viewport/SQLite companion, capture receipt, marker, correlation and post-window source comparison remains immutable. `RESULT.json` under a cohort binds the actual terminal, changed-UI requests, marker order, baseline/final and actual identity. The root result and `HOST_COMPLETION.json` remain explicitly **native-xcresult-required / not-performance**.

The root must independently establish the current source/build/device case identity, actual Passed case, zero failures and zero skips, real exported attachments and all three cohort results. No host field alone constitutes native acceptance. Exact SQL stepping/mapping remains a separate unqualified field until the actual matching native-thread trace is reviewed.

Admitted observation actions are `process` and `pending_sql_begin`, `pending_sql_mark`, `pending_sql_finish`, `pending_sql_abort`, `pending_sql_complete`. All original resource begins/ends, source validation or Reader/Inspector completions are rejected for this isolated host. The original resource-end ACK ordering is untouched.

## Read-only prerequisite API

The root's `Evidence.study_phase(...)` must first run its existing exact native, source/build/device, xcresult, zero-skip and exported-attachment verification. It then calls:

```python
raw_proof = pending.validate_phase_artifacts(root_report, evidence)
external_cleanup = pending_execution.validate_cleanup(
    root_report["pending_sql"], evidence, root_report,
)
```

`root_report["pending_sql"]` is the actual external owner's return value, with:

- `host`: the successful `observer.stop()` return value.
- `hostResult`: `<OUT>/pending-fetch-correctness/RESULT.json` FileWitness.
- `hostInputs`: `<OUT>/pending-fetch-correctness/INPUTS.json` FileWitness.
- `sourceExecution`: `<OUT>/pending-source-catalog/execution-result.json` FileWitness.
- `cleanup`: root-owned `<OUT>/pending-phase-cleanup.json` FileWitness.
- `fullPerformanceAcceptance: false`.

The helper uses the existing `Evidence.read_witness`, `read_path`, `source_identity`, `database_identity`, `installation_admission`, `files` and original Settings attachment selector. It records every actual reread in Evidence's registry. It requires the exact case RESULT to have already entered that registry through `study_phase`; it does not recursively call `study_phase` or start any job.

The function returns immutable existing proof references, three newly recomputed cohort proofs and the actual native attachment joins. Its status is `ORIGINAL_RAW_PENDING_ARTIFACTS_REVALIDATED_NATIVE_AND_EXTERNAL_CLEANUP_GATES_REQUIRED`. It writes no new files, starts no process, samples no current clock and performs no database query/hash. The root seals this return value with its prerequisite result and requires the independent external cleanup proof. The helper's return value does not itself authorize Settings, simulator retention, a whole PERF result or SQL-stepping attribution.

Every original raw request/viewport/companion and all markers/correlations/post-window source comparisons are mandatory. It reproduces arming, immutable lifetime identities, original source comparisons and `evaluate_overlap`; stored success alone is rejected. The native three-cohort summary, each cohort attachment, nonempty annotation witness and host completion must be actual exports selected from the exact case/device manifest. A historical MCM relocation is supported only by the retained exact manifest artifact; the original live admission record is unchanged and is not rewritten to a different path.

## Failure and shutdown contract

Always retain the `observer` object before calling `start()`, and stop it in the outer phase's failure path. A start attempt is recorded **before** entering `Thread.start()`. If start/exit cannot be verified, or native `pending_sql_abort` cannot prove the writer stopped, do not relaunch another app process or transfer simulator ownership.

`observer.stop()` attempts bounded shutdown and sets:

- `observer.owned_activity_exited`: actual observer and probe-writer exit proof; false for an interrupted/unpublished start.
- `observer.cleanup_state`: conservative in-memory cleanup record, set before disk sealing, also available after ENOSPC.
- `observer.cleanup_receipt`: immutable FileWitness for `<OUT>/pending-fetch-cleanup.json` only if writing succeeded.

The cleanup state also includes `ownedRequestRetirementVerified` and every `ownedRequestLifetimes` entry. Each successful original capture must have a unique UUID, the expected owned app-facing request path, actual fd-derived file identity, 36 known bytes written, and verified retirement/descriptor closure with no error. A replacement or uncertain creation/removal remains unverified. `owned_activity_exited` is false if any request lifetime remains unresolved, even when both threads exited.

The native final source sampler is a second writer of the original request basename. `watcherStopped` becomes true only after the passive loop ends, all request lifetimes are retired/closed and no observation error exists. All three native branches explicitly wait for that status and `ownedRequestRetirementVerified` before their own source probes. The final-action ACK requires the actual writer join and the same retirement condition; this does not create a source probe inside an original resource epoch.

It raises on unknown exit, shutdown error, unqualified/incomplete observation or missing completion. A successful return is `{proof, cleanup, externalExitVerificationRequired: true, fullPerformanceAcceptance: false}`. A failed UI/proof may still leave exited threads; those facts remain separate. The helper **never** sets simulator release/retention permission true.

The root's handoff/retention guard must require the actual successful cleanup receipt, both owned exits, no cleanup error, **and** independently verified exit of its URL host and complete native test process group. An in-memory liveness flag, `not is_alive()` during a start gap, best-effort stop, missing receipt or source-only model is insufficient. Preserve ownership and evidence if any exit is unknown. Do not infer external job exits from this helper and do not automatically rerun a failed cohort.
