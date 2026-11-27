# Owned no-denial exercises and original Oracle relay

This checkpoint is source only. Thirty-six synthetic admission/lifecycle controls pass. No actual child process, watchdog exercise, SSH relay, PF or launchd operation, transport request, Simulator action or native case was run by these controls. The earlier independent read-only Ubuntu SSH route check is retained in the offline-execution checkpoint; it is not an exercise receipt.

## Original UI phase: Oracle relay API

The root controller retains ownership of its actual source/build/SDK/runtime/MCM/installation checks, original native execution and final evidence join. This module supplies the already planned Oracle-side process wrapper, with no network-policy mutation or native action.

Run the Oracle coordinator as the existing verified `ubuntu` owner, UID1001, from the current integrated checkout. The helper refuses a root or Mac relay. The original relay continues to use only the existing `scaleway-mac` alias, BatchMode, strict host-key verification and fresh non-multiplexed SSH connections.

```python
relay = exercises.OwnedOracleRelay(
    repository=actual_oracle_checkout,
    output_directory=new_private_oracle_directory,
    rendezvous=actual_window_prepared_payload,
)
try:
    start_record = relay.start()
    # The existing live SSH stdout reader keeps processing the Mac's messages.
    # CONTROLLER_READY precedes fresh real owner coordination; no approval is
    # generated here. WINDOW_PREPARED invokes start() immediately.
    # On the actual TRANSPORT_RESTORED message:
    completed = relay.finish_after_restoration(
        window_id=message["windowID"],
        cleanup_sha256=message["cleanupSHA256"],
    )
    # Copy completed["rows"] unchanged to the private Mac output. Construct its
    # new local FileWitness and send ORACLE_RELAY_INPUT.private.json:
    # {"oracleRelay": actual_mac_jsonl_file_witness}
finally:
    relay.abort()
```

`rendezvous` must be the actual payload emitted by `OfflineStudyCase.prepare_window`, including `windowID`, `hardDeadlineUnix` and `oracleRelaySource`. The latter is checked against the current committed Oracle companion. `start()` returns the FileWitness of its actual START.json, binding the created PID, parent PID, process start/command, source digests and unchanged alias. It does not fabricate a successful heartbeat.

`finish_after_restoration` waits for actual relay exit0 and requires the original final `WINDOW_ALREADY_CLEANED` response to match the actual root cleanup SHA. It returns exactly `{record: FileWitness, rows: FileWitness}`: RESULT.json and the original JSONL. Both remain on Oracle until the root-owned bridge transfers them. The original collector receives the unchanged JSONL, independently joins every actual Mac nonce/root receipt and requires all original UI/source/SQL/build/zero-skip evidence; the wrapper result cannot substitute for that join. The 128-row bound accommodates the existing maximum900-second window and does not extend any deadline.

Use the actual root-owned cleanup file SHA in TRANSPORT_RESTORED. The collector's existing ROOT_RECEIPT_READER can read it. Alternatively `root_snapshot(window_module, windowID)` in this helper performs read-only operations through the original sealed source and returns `snapshot["exports"][windowID]["cleanup.json"]["sha256"]`. It neither loads rules nor changes a daemon. Do not infer the digest from a guessed JSON serialization.

`abort()` stops only the Popen and process group created by this object, using the original runtime27_interruption helpers. It checks the actual PID/start/parent/command before signaling and actual group/process absence afterward. Once completion has already verified disappearance, abort is idempotent and does not signal a potentially reused PID. Public stop/finish methods also call abort on failure; the outer coordinator still keeps its finally block. Failed logs and original JSONL are retained.

## Three actual no-denial exercises

The Mac supervisor is a separate public API:

```python
result_file = exercises.NoDenialExercise(
    repository=actual_integrated_mac_checkout,
    output_directory=new_private_exercise_directory,
    kind="controller-death",  # or "deadline", "heartbeat-loss"
    selected_case_id=original_full_target_class_method,
    simulator_udid=actual_coordinated_udid,
    request_coordination=actual_owner_coordination_callback,
    start_oracle=actual_oracle_relay_start_callback,
    control_oracle=actual_oracle_relay_control_callback,
).run()
```

Each invocation owns one newly created Mac child, one fresh UUID and one genuinely coordinated private lease. Run the three kinds separately. This supervisor never calls activation, a transport probe, a native test or a Simulator command. The original module itself rejects activation for `watchdog-exercise-no-denial`.

| Kind | Actual induced event | Required original cleanup reason |
|---|---|---|
| controller-death | Terminate only the exact created child after its actual root heartbeat proof and explicit abrupt-death boundary | controller-identity-missing |
| deadline | Keep the original child and independent heartbeat alive until the sealed deadline | hard-deadline |
| heartbeat-loss | Stop only the exact live Oracle relay after matching the actual completed root heartbeat nonce; keep the Mac child alive | authenticated-oracle-heartbeat-expired |

The child emits actual PID/start/parent/command, committed source witnesses and boot identity **before** `request_coordination` runs. That callback returns `{lease: FileWitness, coordination: FileWitness}` for actual private Mac files. It must retain real current owner acknowledgements; neither this supervisor nor its child creates or renews them.

Use the existing window lease contract, with mode exactly `watchdog-exercise-no-denial` and the additional `exerciseKind` equal to the selected kind. Its controllerPID must equal the real emitted child PID, not the parent supervisor. Selected case must be one of the two existing full target/class/method page selectors; the declared UDID remains an explicit owner-coordination identity, and no Simulator operation is performed here. The unchanged coordination contract is `otzaria.coordinated-mac-network-window/1`, including real owner acknowledgement FileWitnesses and the exact window/deadline/case/UDID.

The newly supplied lease must have more than45 and at most120 seconds remaining. This is an exercise resource bound, not a performance requirement. Use a realistic fresh90–120-second lease so preparation and the real heartbeat can complete; the non-deadline triggers separately require more than the original30-second heartbeat timeout plus8-second observation bound plus10 seconds of reserve. No code silently lengthens or replaces a deadline. Coordination may occur while the child waits without a deployment, bounded to300 seconds. An expired or insufficient lease fails.

`start_oracle(actual_rendezvous)` must immediately start the original relay on Oracle through the live stdout coordinator, not wait for an asynchronous Sentinel job's completion notification. It returns a byte-preserving transferred START envelope, described below. The child observes a fresh real root heartbeat before any failure trigger.

`control_oracle(action, payload)` has three actions:

- `heartbeat-loss`: call `relay.stop_for_heartbeat_loss(payload["heartbeat"])`. It requires that the exact live relay's last completed original JSONL nonce equals the Mac's actual observation before stopping that owned group. Return its transferred RESULT and JSONL envelope.
- `finish`: call `relay.finish(required_nonce=payload["requiredNonce"], kind=payload["kind"])`. An already intentionally stopped heartbeat-loss relay returns its unchanged completed result. Other exercises require actual relay exit0. The deadline exercise may legitimately end its relay loop at the sealed deadline without a later terminal response; any terminal response that does exist must match the actual root cleanup SHA.
- `abort`: call `relay.abort()` only on the relay object actually created for this window. It cannot target a PID from a caller-supplied list or another owner.

The Mac and Oracle clocks retain separate domains. The source validates Oracle-local intervals in order and binds the Mac's nonce to the actual original remote response; it does not claim cross-host wall-clock ordering without a measured bound. The original relay's own absolute-deadline admission remains fail-closed if host clocks make its existing resource check impossible.

## Transfer envelopes and private output

The exercise callbacks preserve the exact original Oracle files when copying to Mac. A START response is:

```python
{
    "originalRecord": actual_oracle_start_file_witness,
    "record": actual_mac_copy_start_file_witness,
}
```

A completed response is:

```python
{
    "originalRecord": actual_oracle_result_file_witness,
    "record": actual_mac_copy_result_file_witness,
    "originalRows": actual_oracle_jsonl_file_witness,
    "rows": actual_mac_copy_jsonl_file_witness,
}
```

Each FileWitness is `{path, bytes, sha256}`. The helper requires original/copy size and SHA equality and re-reads the actual local copy. It also binds the RESULT's original rawRows witness to those exact JSONL bytes. No placeholder paths, synthesized heartbeats, manually asserted pause flags or fabricated PASS records can qualify a run.

Every output directory is new, canonical and private. Root-controlled raw state and control tuples remain outside public Git. The source-only checkpoint has no such raw runtime files. Failure records preserve whatever deployment/native-independent evidence exists. If a deployment may have occurred, cleanup requests only that UUID's original finish/unload API, verifies actual root receipts and empty rules, then stops only the owned child and relay. A partial/unknown cleanup is reported as unverified rather than silently accepted. Concurrent child-finally and guardian cleanup is accepted only after a fresh actual root receipt plus current daemon/plist/rule absence prove the same UUID was cleaned.

## Admission and downstream use

The private root export reads only the exact window's original root-owned sealed/armed/status/heartbeat/cleanup/unloaded/watchdog files. It revalidates the sealed source and Python identity, current boot, actual empty owned anchor, actual daemon absence and actual plist absence. Successful exercise admission additionally requires the expected reason, an actual armed watchdog, nonempty entirely inactive history with the real nonce, empty pre-cleanup rule hashes and unchanged original host configuration. Deadline and heartbeat-loss cases must independently observe the original child still alive after cleanup. No result is created from an empty/no-op history.

After all three actual results exist:

```python
watchdog_receipts = exercises.exercise_receipts(
    {"controller-death": death_result,
     "deadline": deadline_result,
     "heartbeat-loss": heartbeat_result},
    repository=actual_integrated_mac_checkout,
)
```

This re-reads actual root receipts and original private files, requires distinct windows with one unchanged source/boot, and returns the three genuine root cleanup FileWitnesses for the real denial lease's `watchdogExerciseReceipts`. The original window deployer independently verifies those same root files before any later activation. `validate_exercise_result` is also available for one actual result. Neither method upgrades an exercise to network-denial or native UI acceptance.

The six helper dependencies must be current committed files in Scripts/CI: this module, study-ui-offline-window.py, study-ui-offline-heartbeat.py, study-ui-offline-execution.py, study-ui-settings-receipts.py and runtime27_interruption.py. The final root integration includes the new file in its ordinary source inventory. The private worker CLI (`--worker`, `--nonce`, `--output`) is an internal child entry point; it waits for the actual admitted coordinator frame and is not an alternate approval or launch path.
