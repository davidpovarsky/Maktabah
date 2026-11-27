# Original prerequisite receipts before Books Updates

This checkpoint adds only `Scripts/CI/study-ui-prerequisites.py` and its source-admission evidence. It does not change app Source, the original v32 driver, either Reader test selector, a Simulator, or any installed corpus.

## Controller API

```python
admit_before_settings(
    receipts_path,
    core=core,
    settings=settings,
    udid=owned_v40_udid,
    source=current_source,
    build=current_qualified_build,
    installation_result=original_installation_result_file_witness,
    required_study_phases=PRE_UPDATE_PHASES,
)
```

`receipts_path` contains a JSON object mapping each `study:<phase>` plus `full-v32`, `full-v40`, `groups100`, `offline`, and `perf01-03` to the immutable original result's `{path, bytes, sha256}` witness. The complete phase map must match the currently committed original production study controller. Extra manual-approval keys cannot waive a gate.

The function writes one fresh `core.OUT/settings-prerequisites.json`. Successful admission returns `{proof, witness}`. Incomplete gates raise `PrerequisitesNotMet`, retaining the same `.proof` and `.witness` for the integration controller's failure report. `proof.receipts` contains the validated original result witnesses, so `study:pages` can be compared directly with the separately supplied positive paging result.

## Scope of admission

| Gate | Required original evidence |
| --- | --- |
| Each current study phase | Exact original phase/selector list, current checkout and app/test trees, same qualified build before/after, same owned retained v40 installation/runtime, no postcheck failures, actual installed app and test images, and a re-run of the existing file-only zero-skip verifier for every original case directory/result |
| Original full-v32 | Its original two selectors, current app/test/source/build identity, its own created Simulator and cleanup, original v32 corpus identity, twenty cold/warm opens and ten forced restores, and the original natural **at-least** Inspector workloads |
| Full-v40 | Its original two v40 selectors on the retained owned installation, twenty distinct native opens and ten new-PID restores, three original Inspector observations, and the separate v40 exact-size gate with actual counts exactly 100/500/2000 |
| Groups100 | Its original selected case, 100 retained original app operation records, 200 matching PID/RSS boundary samples, 200 original nonce-bound request/ACK files, contiguous operation sequence, and the actual passed-case exported cold proof with a changed original app PID and unchanged installation/owner |
| Offline | Explicitly unqualified until an original source-qualified UI producer proves an observed offline/denied-network condition, both real packages, query/result/metadata/paging behavior, and restoration of the network condition |
| PERF01–03 | Explicitly unqualified until the original required workload, first-content/CPU/RSS, main-thread/layout, attributable SQLite lock-wait/concurrency and correctness producers are source-qualified. No invented SLA or physical PERF04 gate |

The helper re-reads bounded evidence and current committed execution source files. It does not run `xcodebuild`, `xcrun`, `simctl`, an app, a network request, or a new full-corpus hash. Source and build/installation receipts must already have been admitted by the actual integration owner. A result named PASS or a manual sign-off cannot establish the missing offline/PERF producer contracts.

## Focused verification

`source-controls-run01/RESULT.json` and `controls.log` record **18/18 synthetic source-admission tests, zero failures/errors/skips**. The controls use original producer bytes and the original file-only xcresult verifier in a fresh temporary local Git repository. They construct explicitly synthetic export shapes to test valid field contracts and negative admission: mismatched source/build/runtime/owner, a skipped native case hidden by an outer PASS, dirty execution input, changed file witness, changed manifest/runner, incomplete open/restore cohorts, an at-least count mislabeled exact, missing/mismatched ACKs, noncontiguous original operations, and a false cold PID.

The full synthetic fixture passes the known producer schemas and still blocks the complete order gate on `offline` and `perf01-03`. It creates no actual app, native build, Simulator connection, installed database, UI result, or performance result. Synthetic Passed exports are parser inputs only. These controls do not close any user UI acceptance item.

The exact six producer source inputs are retained under `control-inputs/`, with their origin paths and hashes in `control-inputs/INPUTS.json`. They are evidence snapshots; the production helper imports the actual current checkout's original parser/controller sources. To reproduce against this checkpoint:

```sh
python3 docs/hq-integration/wave2-20261127/reader/prerequisites/test_prerequisite_admission.py \
  --candidate Scripts/CI/study-ui-prerequisites.py \
  --producer-root docs/hq-integration/wave2-20261127/reader/prerequisites/control-inputs \
  --output /absolute/new/source-control-output
```

The controller, execution witnesses and frozen inputs must be generated from the final integrated checkout before any real native acceptance. The full-v32 source files and old at-least acceptance retain their existing meaning; only the new v40 gate requires exact scales.
