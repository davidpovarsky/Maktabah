# Original full-v40 offline case execution and final evidence join

This is a source implementation with synthetic validator controls. It does not qualify a live watchdog exercise, transport request, native case or offline suite. No application Source, UI test, shared core or existing prerequisite file is changed by this helper.

## Root hooks

The root controller owns two distinct phases, each with one existing selector:

| Phase | Existing class/method | Page coverage |
|---|---|---|
| offline-zayit | PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity | 50 / 100 / 150 |
| offline-otzaria | PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata | 100 / 200 |

Keep the existing XCTest allowance of 1800 seconds. Only the host process timeout is shortened to the actual remaining coordinated window. Each selector needs a fresh separate owner-approved lease. The root excludes these phases from PRE_UPDATE_PHASES; the separate offline prerequisite requires both final phases and the aggregate suite.

After ordinary source/build/SDK/runtime/retained-owner admission, boot and image admission, set installation_before in the original root report. Construct:

```python
active = offline.OfflineStudyCase(
    core=core, settings=settings, retained_owner=owner,
    root_report=report, engine=engine,
    case_directory=case_dir, output_directory=out / "offline-host",
    private_lease=actual_private_lease_path,
    coordination_receipt=actual_coordination_file_witness,
    simulator_probe=qualified_simulator_probe_manifest,
    host_probe=qualified_host_probe_manifest,
    image_path_resolver=image_resolver(core, udid, products, build),
    on_prepared=emit_ready_to_waiting_oracle_launcher,
)
try:
    active.prepare_window()
    attempt = active.run_native_actions(
        lambda budget: run_original_native_actions(
            core, test_run, udid, case, 1800, case_dir, environment,
            host_timeout_seconds=budget,
        )
    )
    active.finish_transport()
    # Denial and the owned watchdog are now cleaned up. Keep the original
    # verifier/exporter unchanged; their duration is outside the denied window.
    result = verify_original_case(core, udid, attempt)
    sealed = active.seal_case(
        oracle_relay_receipt=actual_ended_relay_log_file_witness,
        source_after=source_context(core, phase, True),
        build_after=core.build_identity(context)[2],
    )
    report["offline_case"] = sealed["witness"]
except BaseException as error:
    # Retain the original RUN_ATTEMPT, log and xcresult even if exports or a
    # subsequent postcheck fail. This call never deletes those artifacts.
    try:
        active.record_failure(error)
    finally:
        cleanup = active.abort()
    raise
```

The existing root finally block still verifies actual database, original receipts, app/runner image closure, source/build and retained Simulator cleanup. It writes its immutable RESULT.json only after those checks. A successful offline phase uses the helper constants OFFLINE_PHASE_PASS and OFFLINE_NETWORK_SCOPE; an ordinary-network status is rejected by the offline join. A failed postcheck leaves the inner case insufficient for admission.

After both immutable root RESULT files exist:

```python
suite = offline.seal_suite(
    case_receipts={"zayit": zayit_case_file, "otzaria": otzaria_case_file},
    phase_results={"zayit": zayit_root_result, "otzaria": otzaria_root_result},
    evidence=original_prerequisites_evidence,
    output=fresh_suite_result_path,
)
```

The future explicit prerequisite hook is validate_suite(suite_file_witness, evidence=evidence). It re-reads original files, original zero-skip/declaration/export verification, every source/SQL page and all transport joins. The current prerequisite's pending-offline rejection remains unchanged until the integration owner admits and wires this producer. No manual boolean or arbitrary PASS may waive it. The aggregate is written only after both final root phases validate; there is no self-referential hash.

## Genuine coordination and runtime PID

The helper does not create lease approvals. Root first admits the original native context and emits its actual Mac controller PID and current source to the already running Oracle coordinator. That coordinator obtains real, current acknowledgements from every Mac owner for one identified window. Root then creates its private lease using the actual runtime PID; all supplied control tuples, deadlines and owner acknowledgements remain explicit inputs. Lease controllerPID must equal os.getpid() in this same root process.

The coordination FileWitness points to a private JSON object:

- schema: otzaria.coordinated-mac-network-window/1
- status: ALL_LISTED_OWNERS_PAUSED
- windowID, hardDeadlineUnix, selectedCaseID and simulatorUDID exactly matching the lease
- observedAtUnix, evaluated at preparation, no more than 120 seconds old
- owners: one record per exact lease coordinatingOwners entry, containing ownerID, paused=true, windowID, acknowledgedAtUnix, and originalAcknowledgement FileWitness

Original acknowledgements must be retained from the actual coordinator/owner exchange. This structure records authorization; it is never used as network or native acceptance. The helper neither discovers a fictitious owner list nor renews old acknowledgements or deadlines.

## Independent Oracle heartbeat rendezvous

prepare_window deploys the already reviewed sealed watchdog, writes RENDEZVOUS.private.json and immediately invokes on_prepared. The callback must flush one unambiguous ready record to the already waiting Oracle stdout reader; it must not wait for the outer asynchronous Sentinel job to finish. The ready record includes the actual controller PID, selected case, UDID, exact window ID/deadline, source witness of study-ui-offline-heartbeat.py, and the original freshSSHCommand.

The Oracle launcher verifies the local relay source bytes against that source digest and starts it as the existing non-root pinned SSH owner. It uses only the existing scaleway-mac alias, strict host-key verification and fresh non-multiplexed connections. No credentials are copied and no alternative route is invented. The Mac waits at most 12 seconds for the watchdog's actual fresh authenticated heartbeat nonce; a local Mac timer cannot satisfy this condition.

After finish_transport restores the network, the Oracle relay must observe the actual WINDOW_ALREADY_CLEANED reply and exit. Its original JSONL receipt is transferred unchanged into the private Mac evidence directory and supplied to seal_case. Oracle-local request intervals are checked only within their own clock domain. Mac observedUnix/nonces are joined to the actual root-owned Mac heartbeat and watchdog history. No unmeasured cross-host wall-clock ordering is claimed.

## Native budget and cleanup

run_native_actions activates the owned window, performs the original positive/negative transport controls, then computes floor(hardDeadlineUnix − currentMacTime − 240 seconds). The 240-second reserve is a conservative resource allowance for the periodic worker to stop, four final negative probes including process cleanup, status/rollback and unload. It is not a performance SLA. No positive remaining budget means failure and owned rollback. The callback receives that exact host timeout; RUN_ATTEMPT must record host_timeout_seconds. The original two XCTest allowance flags and allowance_seconds remain 1800.

Receipt-write failures cannot skip abort. The helper preserves failed native/export/postcheck artifacts and requires owned watchdog removal and worker exit before the root may shut down the Simulator. The full transport proof remains private because it contains control information. Private root receipt export is read-only, restricted to the exact active window and its three actual same-source no-denial exercise directories.

## Evidence joins

The source validator requires:

- Current committed execution helpers and original application/test/source/build/SDK/runtime/installation ownership through the existing prerequisite Evidence implementation.
- Exact actual MCM ownership, database file identity and manifest, and both original package manifests plus complete file inventories before and after.
- The actual passed original XCTest selector, zero skips, actual exported attachment manifest and source/SQL attachment; each intermediate cumulative publication and all 150 or 200 canonical IDs/locators/metadata must match its independently observed SQL row.
- A fresh actual app PID/namespace launched inside the native callback and the same exact qualified Maktabah Mach-O path before/after, including on later readback.
- Native command timestamps and fresh host budget wholly inside the observed denied interval, actual continuous bounded watchdog/process observations, genuine before/during/after Foundation request outcomes and increasing owned PF packet counters.
- Original root-owned deployment/source/armed/cleanup/unload receipts, all three actual same-source/same-boot no-denial watchdog exercises, and the independent Oracle relay nonce chain.
- Final root postchecks, identical current image closure, unchanged original installation receipts and successful retained Simulator shutdown for both separate phases.

Unchanged package inventories establish retained installed files. They do not claim zero attempted network requests. Physical-device airplane mode, unrelated Reader/Sefaria behavior and PERF acceptance remain separate scopes.

## Exact launch inputs and source boundary

This module is imported by the existing root controller; it intentionally has no CLI, environment-variable parser or autonomous launcher. Keep the original page selector's launch environment, XCTest launch arguments and normal production provider unchanged. Pass only the actual manifests for the two already compiled independent Foundation probes: each is exactly `{binary: FileWitness, source: FileWitness, compileReceipt: FileWitness}`. Later admission repeats the actual kind, SDK 27.0, Mach-O platform, signature, original source and compiler-driver binding, in addition to re-reading the witnessed bytes.

The private lease is the original `study-ui-offline-window.py.admit_lease` contract. Required fields are `schema`, `status`, `windowID`, `controllerSourceSHA256`, `mode`, `selectedCaseID`, `coordinatingOwners`, `allOtherNetworkAndNativeWorkPaused`, `notBeforeUnix`, `hardDeadlineUnix`, `controls`, `oracleHeartbeatPeer`, `controllerPID`, `simulatorUDID` and, for real denial, `watchdogExerciseReceipts`. The source digest is the window module's digest, not this execution module's digest. Status must be `COORDINATED_EXCLUSIVE_OFFLINE_WINDOW`, mode `network-denial`, and the schema must equal the original module's VERSION. The three exercise witness keys are exactly `controller-death`, `deadline`, `heartbeat-loss`; each points to its actual root-owned cleanup.json. Every actual existing control state must be qualified by the original private control-tuple parser. If a translated VNC state is present, retain its complete `translatedVNC` state/rule/process/socket/owner-image records as specified by that original module; do not omit it or manufacture an owner attestation.

All nine execution inputs must be current committed files: `study-ui-offline-execution.py`, `study-ui-offline-window.py`, `study-ui-offline-heartbeat.py`, `OfflineTransportProbe.swift`, `build-offline-transport-probe.py`, `runtime27_interruption.py`, `study-ui-settings-receipts.py`, `study-ui-prerequisites.py`, and `production-study-v40-ui.py` under Scripts/CI. Their FileWitnesses are retained in executionSources. Original source/test/build/SDK/runtime and retained Simulator ownership are additionally admitted by the existing prerequisite Evidence methods. A source change after preparation cannot be silently joined to the old run.

The existing Oracle relay CLI remains `python3 Scripts/CI/study-ui-offline-heartbeat.py --window <actual windowID> --deadline-unix <sealed hardDeadlineUnix> --output <new private JSONL path>`. Run it as the existing `ubuntu` SSH owner, UID1001, through the verified `scaleway-mac` alias. The actual non-multiplexed strict route was verified with a read-only remote clock at 2026-11-27 07:14:55 UTC; the redacted receipt retains the command and configuration digest. Raw SSH config remains outside Git. This route check grants no live network-denial permission and creates no exercise receipt. The root's waiting Oracle stdout reader and fresh owner coordination still precede any deployment.
