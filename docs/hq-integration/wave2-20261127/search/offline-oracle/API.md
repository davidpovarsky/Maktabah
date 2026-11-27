# Original offline phase: live Oracle coordinator

This checkpoint is **source only**. The original `4cb7590` checkpoint retained forty-three synthetic admission, lifecycle and local temporary-file controls. The subsequent immutable-checkout environment correction has its own bounded baseline/candidate controls in `../offline-oracle-environment/`. Those controls perform no actual SSH, Mac, PF, launchd, network denial, signal, Simulator action or native test. Importing the helper has no runtime effects. Runtime still requires a real coordinated window and the original retained corpus/packages/build.

## Scope and integration

`Scripts/CI/study-ui-offline-oracle.py` is a new file. It does not change the app, test selectors, common/v32 runners, prerequisites, the root production controller, the original window or heartbeat. It composes the exact `OfflineRendezvous` events in the root draft `production-study-v40-ui.py`, SHA60dd4c89e7ba872e285c14c3f7cba0077ad5f5b59a34b0d0326e8d070ebfb4d8. That digest identifies the reviewed API input; it is not hardcoded as a future runtime admission. The actual runtime main and all helper files must equal their current committed counterparts on both Oracle and Mac after root integration.

The actual root run keeps all original source/build/SDK/runtime/MCM/installation/image checks, the unchanged original test selectors and XCTest1800-second allowance, the original pages/SQL and package inventory join, and final source/build/retained Simulator checks. The collector independently bounds the native callback by the real remaining ≤900-second host window minus its240-second reserve. This coordinator never extends either deadline or changes the original XCTest allowance.

Add this new file and `study-ui-offline-exercises.py` to the root controller's ordinary `FILES` inventory before runtime. Use the integrated root checkout. The search lane's isolated source worktree is not an alternate runtime image or dependency installation.

The helper calls `OwnedOracleRelay` from the exercise helper after its ownership follow-up8dba94565372a15fe232d8135e3d447494318c9c. The latter preserves exact argv/parent before Popen and refuses reused PIDs. Because the SSH remote command is one multiword argument, the new coordinator additionally reads the actual Linux `/proc/<created-pid>/cmdline` NUL-separated argv; it does not incorrectly split a `ps` display into SSH argv. Actual ps PID/parent/start/command, original still-live Popen and exact argv must all agree before adopting a fallback identity or stopping an owned process.

## Public API and launch input

Run only as the verified Oracle `ubuntu` owner, UID1001, using the already configured pinned `scaleway-mac` alias. The existing alias, BatchMode, strict host keys, ConnectTimeout5 and disabled multiplexing are fixed. The module does not discover alternative hosts, change host keys, copy credentials or read credential contents.

```python
coordinator = OracleOfflineCoordinator(
    repository=actual_integrated_oracle_checkout,
    launch_spec=actual_private_oracle_launch_json,
    output_directory=new_private_oracle_output,
)
result_witness = coordinator.run()
```

CLI, with actual qualified arguments supplied by the owner:

```text
python3 Scripts/CI/study-ui-offline-oracle.py execute
  --repository <actual canonical integrated Oracle checkout>
  --launch-spec <actual private Oracle launch JSON>
  --output <new Oracle directory with existing canonical parent>
```

The launch specification must be one current-user-owned0600 regular file with one link. The output is a new0700 directory. All private receipts, network coordination details and raw original relay rows remain outside public Git.

The exact launch JSON keys are:

| Key | Required value |
|---|---|
| `schema` | `otzaria.original-offline-oracle-launch/1` |
| `phase` | `offline-zayit` or `offline-otzaria` |
| `simulatorUDID` | Actual canonical uppercase UUID of the already owned Simulator |
| `macRepository` | Actual canonical integrated Mac checkout |
| `python` | FileWitness of the actual canonical Mac interpreter, matching resolved `sys.executable` at execution |
| `controller` | FileWitness of that checkout's `Scripts/CI/production-study-v40-ui.py` |
| `argv` | The exact original Python/controller argv listed below, not a shell fragment |
| `environment` | Explicit actual `EXPECTED_CHECKOUT_SHA` (40 lowercase hex), `FAITHFUL_RUNTIME27_IDENTIFIER`, `LC_ALL=C`, `TZ=UTC`; optional actual `PATH` and `DEVELOPER_DIR` only |
| `inputs` | `installationResult: FileWitness`, plus `runnerInputs: FileWitness` only if that original option is supplied |
| `outputDirectory` | New original phase directory under that Mac checkout's `build/artifacts`, with an existing canonical parent |
| `timeouts` | Explicit `preReadySeconds`1–1800 and `postRestorationSeconds`1–900 resource bounds |

Every FileWitness is exactly `{path, bytes, sha256}` with original actual bytes and digest. No launch, input, lease, owner acknowledgement, probe or PASS fixture is generated by this module.

`argv` starts with the actual interpreter path, `-I`, `-B`, `-u`, actual controller path, `execute`, and selected phase. It then supplies each of these ordinary original options once, with a value:

- `--owned-simulator`: the actual selected UDID.
- `--installation-result`: the bound original installation RESULT path.
- `--output`: the declared new Mac phase directory.
- `--reserved-other-bytes`: actual current concurrent storage reservation, a nonnegative integer.
- `--offline-coordinator-wait-seconds`: an explicit original wait of1–600seconds.
- Optional `--runner-inputs`: the separately witnessed original file.

Unknown options, duplicate options, additional selectors, source-check, caller Python code, provider/runner/proxy environment overrides and another runtime are refused. The root validates SDK/runtime compatibility and its independent runner-input allowlist again. All actual canonical paths, Python metadata and source receipts must be supplied; this file does not guess them.

The pre-ready and post-restoration waits are resource limits for the outer orchestration, not performance SLAs. The total outer bound is their sum plus the original coordinator wait,900seconds for the independently sealed window and60seconds of supervision reserve. Each stage also has its own bound. Those Oracle-monotonic waits do not renew the Mac lease or infer causal order from uncalibrated host wall clocks. Raw Oracle and Mac timestamps retain their own domains.

## Actual ready and real owner response

The fixed remote bootstrap verifies the actual non-root Mac interpreter, canonical checkout, original input witnesses and eight committed source files before executing the original main in the same observed PID. It reads actual `git rev-parse HEAD` and requires equality with the explicitly supplied `EXPECTED_CHECKOUT_SHA`; an inherited SSH value cannot supply or replace that launch requirement. It emits that checkout SHA with its actual PID/start/parent/UID first. The original main then performs its normal admission and emits its own `CONTROLLER_READY`.

The coordinator's live pipe reader saves that event immediately. It re-reads the original private Mac event file and source-before file, binds the original `checkout_sha` to that same explicit launch value, confirms the current original main PID/start/parent/argv, and verifies that the current Mac helper files equal Oracle's committed bytes. The final source join repeats the checkout binding. It then atomically publishes `READY.private.json` in its Oracle output and prints a flushed line beginning:

```text
OTZARIA_OFFLINE_ORACLE_READY 
```

An asynchronous Sentinel result is not used as the event source. The actual live SSH reader handles the main's output while it runs. Root may read the newly saved READY file during the background job to supply current real coordination.

READY includes the actual original `requestID`, controller PID, case, UDID, `controlDirectory`, source witnesses, and the exact new Oracle `responsePath`. Root supplies **only a real** `COORDINATION_RESPONSE.private.json` at that path, with0600/one-link/current-ubuntu ownership. Write it to a fresh temporary file, fsync, and atomically rename it when complete. Its exact keys are:

```text
schema = "otzaria.offline-coordinator-input/1"
requestID = the actual current READY requestID
lease = actual Mac-hosted FileWitness
coordination = actual Mac-hosted FileWitness
hostProbe = {binary: FileWitness, source: FileWitness, compileReceipt: FileWitness}
simulatorProbe = {binary: FileWitness, source: FileWitness, compileReceipt: FileWitness}
```

The lease and coordination must have been produced from genuine current owner acknowledgements and the actual Mac PID/window; the original root admission checks them. The three real no-denial exercise receipts and actual probe compilation/signatures remain required by the original window. This coordinator neither creates pause acknowledgements nor fills a missing lease with flags. No live window has yet been supplied or run for this checkpoint.

The same bytes of the supplied response are transferred through a new strict pinned SSH connection. The fixed writer checks the canonical actual0700 control directory and actual Mac UID, re-reads its original READY file and live controller identity, verifies the Mac-hosted input files, writes0600 to a fresh temporary file, fsyncs, rejects an existing destination, and atomically renames the complete file. The newly created private directory has one admitted writer. This is not an assertion of an atomic compare-and-swap against an unauthorized concurrent same-user writer. The original root never sees an intentionally partial final IPC file. Changed owner/mode/directory, an existing target, linked inputs or mismatched bytes fail.

## Ordered original events and relay

| Actual event | Bridge action |
|---|---|
| `CONTROLLER_READY` | Bind original PID/start/source/case/UDID/requestID and wait for the real owner response |
| `WINDOW_PREPARED` | Require the same actual lease and owner receipt, then immediately start one `OwnedOracleRelay` |
| `TRANSPORT_RESTORED` | Require that window's actual root cleanup SHA; wait for the relay's real terminal `WINDOW_ALREADY_CLEANED`, exit0 and verified owned group/process cleanup |
| `CONTROLLER_POSTCHECKS_PENDING` | Continue waiting; it grants no acceptance |

Sequence numbers, requestID, actual PID, control directory, case and UDID cannot change. Unknown, reordered or duplicated frames fail. An actual `WINDOW_ABORTED` at any active stage is retained and fails the bridge.

After genuine restoration, the coordinator copies the original Oracle `heartbeat.jsonl` unchanged to `oracle-relay-<actual-requestID>.jsonl` under the actual Mac private control directory. It then publishes the original root's `ORACLE_RELAY_INPUT.private.json`, containing only its schema, actual requestID and that actual Mac copy FileWitness. The Oracle START/RESULT/JSONL remain in their original private directory; the final original Mac copy must still match them byte-for-byte.

The actual root continues its unchanged native result/zero-skip validation, exports, offline case seal, image/corpus/source checks and retained Simulator shutdown. The bridge waits for actual controller/SSH exit0, complete bounded capture, and the immutable original root RESULT. It reads that RESULT and the exact actual joined case/native files. It checks the real pending-to-final boundary, same source/build/runtime/installation, original postchecks, retained shutdown, actual root cleanup bytes, same real lease and owner receipt, unchanged relay copy and every original page/SQL identity through the existing pages validator. The original root collector and later suite validator continue to own the complete transport/probe/package/native evidence admission.

The coordinator status `ACTUAL_ORIGINAL_OFFLINE_PHASE_AND_RELAY_RETURNED_PASS` describes **one completed original phase and bridge**. It is not the two-engine offline suite. Root must still seal both immutable phase results using the original `seal_suite`, and the prerequisites validator must revalidate that suite. Physical device airplane mode and unrelated Reader/PERF results are separate scopes.

## Failure, process ownership and evidence

All locally created SSH processes and their own groups use the original `runtime27_interruption` stop helpers after exact actual identity checks. Any fallback identity requires the original Popen still live before and after observation; a reaped PID cannot be adopted. The original relay uses its corresponding corrected owner wrapper. No arbitrary PID list, host-wide kill, other owner's process or network mutation API exists in this bridge.

On failure, the bridge stops its relay and can send SIGINT only to its exact created Mac controller, with current source/PID/start/parent/argv proof. It requests the original controller's error/finally path; it does not forge a root cleanup or use SSH disconnection as proof of restored transport. Before READY, it uses the observed bootstrap PID/start/parent plus the exact actual original main argv; without that proof it refuses a remote signal and reports incomplete ownership. The independent original watchdog retains its hard deadline even if the bridge is lost.

Reader threads continuously capture bounded raw output. Overflow, partial final stdout, a reader error, queued event ambiguity or missing actual identity cannot pass. A start attempted without a confirmed thread identity is treated as unverified even if `is_alive()` is false. Cleanup attempts every owned reader and input join and never closes a buffer owned by a live reader. A failed cleanup stays failed.

The original remote `original.xcresult`, `RUN_ATTEMPT.json`, case RESULT and phase RESULT are never removed or replaced. On native/export/postcheck/bridge failure, the bridge attempts a bounded read of whatever actual final/partial files exist and retains their original path/bytes/hash in its private failure receipt. An unreachable or missing result is reported as unavailable, not silently converted to success. Source and public documentation are the only files committed by this checkpoint; private live network/owner information must remain outside public Git.
