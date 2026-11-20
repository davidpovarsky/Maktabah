# Normal iOS 44716258538: preserve raw runtime-27 orientation evidence

## Result and scope

The original normal-iOS workflow **failed**, on immutable checkout
[e9050ad8998a070c92c73a881b0d7deb6e216e88](https://github.com/davidpovarsky/Maktabah/commit/e9050ad8998a070c92c73a881b0d7deb6e216e88),
application/test source **c6542e412fb5b052d182aacbea685c62bdf8440c**.
[Run 44716258538, attempt 1](https://github.com/davidpovarsky/Maktabah/actions/runs/44716258538)
used branch `codex/otzaria-ios-reviewed-20261120`; heavy Otzaria, corpus acceptance
and live Sefaria inputs were false. There was one dispatch.

The failure is in the normal iOS acceptance shell's initial orientation probe.
It is not the INDEX XCTest signature failure in a separate Native workflow.
Otzaria/Zayit framework jobs, pinned Swift-package resolution, the Inspector
backend-mappings step, the simulator app build, and the unsigned device/IPA job
succeeded. This evidence does not turn the failed acceptance workflow into a pass.

The repair removes the Xcode 26-era encoded-image rotation. It preserves the
runtime's actual screenshot bytes and all existing orientation acceptance,
IDB commands, time limits, subsequent phases, and app/SDK inputs.
The same source-bound Bash fixture produced **17/23 PASS + 6 FAIL before** and
**23/23 PASS after**, with zero errors/skips. macOS tools are explicit doubles
in that fixture. **The repaired Apple/simulator acceptance has not run.**

## Actual job outcomes

| Job | ID | Actual conclusion / completion UTC |
|---|---:|---|
| Otzaria framework | 136220334549 | SUCCESS, 10:24:36 |
| Zayit framework | 136220334966 | SUCCESS, 10:22:30 |
| Pinned package resolution | 136220334961 | SUCCESS, 10:27:43 |
| Unsigned device app / IPA | 136231038212 | SUCCESS, 11:11:36 |
| Simulator build and iPad acceptance | 136231038235 | FAILURE, 11:30:29 |
| Workflow summary | 136260782350 | FAILURE, 11:30:38 |
| Downstream Native bootstrap | 136260784641 | SKIPPED |

These times are authenticated job `completed_at` values. The successor watcher
observed failure at 11:30:50.560803; that observation is not the workflow end time.
The first finite 3380s watcher timed out while the run was still active; the
successor started only after its predecessor exited and the matching-process
check was empty. Both original watch records/logs are retained.

The simulator build completed 11:15:27. Its iPad acceptance step failed 11:30:00.
Both authentic `verify-app.json` reports say
`BUILT_APP_ORIGINAL_INPUTS_VERIFIED`, `app_build_executed:true`,
`actual_source_inputs_verified:996`, and checkout e905. They retain the original
Hanlin e004 source inventory, exact package pins, macro authorization, generated
workspace/Pod inputs, and the built embedded-bundle hash.
The reports' `runtime:NOT_RUN` is their build-verifier scope; later simulator
orientation commands did run. The Inspector step's success comes from job
metadata; no new per-assertion total is inferred here.

Unsigned IPA artifact 14623836905 was uploaded. Its API metadata/digest is retained;
this collection downloaded the small reports/screenshots/build logs, not the IPA
or framework/package archives. No independent IPA inspection, signing,
installation on a physical device, or physical-device acceptance is claimed.

## First failure and the preserved image

`raw/completion/simulator-FAILED-STEP.log.gz` is the authentic failed-step output
(SHA256 of uncompressed bytes
`709965f1626aa715ed1eff274f124b7243035e8f5d18d02217485021cedd129b`).

The actual sequence was:

1. Runtime admission selected available iOS 27.2 build 24B8117, SDK 27.2, app minimum
   27.0 and the supported iPad Pro 13-inch M5-16GB device type.
2. The shell installed and launched the app, then entered PHASE0.
3. At 11:26:16 it requested `LANDSCAPE_LEFT` through original IDB.
4. `simctl io screenshot` wrote the image; the exact executed source then applied
   unconditional `sips -r 90` and replaced the captured file.
5. At 11:29:46.755633 the original strict check rejected 2064×2752 pixels as portrait.
   The shell exited before the later bootstrap/Reader/Search/RTL acceptance phases.

The original uploaded PNG is retained unchanged:

- `raw/artifacts/14625246106/orientation-probe-landscape.png`
- 6,364,500 bytes; SHA256
  `f943a3895a70b33818fd5fc4bff627a79dcd0f6af73deea98d56698e15ee55cc`
- Directly read PNG dimensions: 2064×2752.
- Visual observation: SpringBoard labels, status bar and dock are sideways by 90°.
  The app's content is not visible. This is no proof of app-interface readiness.

The pre-transform `simctl` PNG was overwritten by the original helper and is
**absent**. Its inferred 2752×2064 dimensions follow from the exact 90° transform
and the retained result; they are not a directly observed raw-file measurement,
and no pre-transform hash is invented.

Two attempts to view the original large PNG through media transport failed.
A separate JPEG re-encoding at the same dimensions, with explicit
`-noautorotate`, one thread, and no crop/scale/geometry transform, was used only
for visual inspection. Its receipt and bytes live under `inspection-only/`.
It is never acceptance evidence or a replacement for the authentic PNG.
The initial default-thread ffmpeg conversion failed with a memory-allocation
error; the bounded conversion succeeded. Both attempts are retained.

## Source change and boundaries

Base is **b9508ff7e302dcd692b97c2c510993d0c2652809**. Its acceptance shell is
byte-identical in Git to the failed e905 version.
Only `Scripts/run-ipad-simulator-acceptance.sh` changes executable CI behavior:

- Delete the obsolete `normalize_screenshot_orientation` function and its three
  call sites (bootstrap capture, current-UI capture and PHASE0).
- Explain raw-capture preservation for the admitted 27+ SDK/runtime.
- Update the failure wording to say raw screenshot orientation.

`rotate_simulator` and `require_screenshot` are byte-identical to the original.
The full inverse reconstructs every original source byte from the narrow delta.
All later acceptance phases, source pins, SDKs, package locks, project settings,
app source and XCTest files remain unchanged in this branch.

A Git caller scan binds this shell only to `.github/workflows/ios-build.yml`.
The active Native and three-stage Release workflows use their separate
runtime27 drivers; this repair neither changes nor cancels those runs.

Canonical Git/LF source SHA256:

| Input | SHA256 |
|---|---|
| Original shell | `9879532570b4bbc4720900d95ac2c1e451593847fff4c9ada1068e8fb8049bb0` |
| Repaired shell | `d263057ae4f586f0257329182e3d76edab978382ff0a74a906e13a931d46ab02` |
| Focused fixture | `93e60a94780893b3fe2ef830d2168842c9dd3f04222d432eb8f23ab22ea19dd5` |

The original Windows working copy had CRLF. `BEFORE.json.gz` records that distinct
working-byte hash and the verified equality after LF normalization. Raw reports
and logs are gzipped without newline changes.

Root independently reviewed the complete shell delta and found no new blocker.
That is a source review, separate from the executed shell controls.

## Actual focused verification

`Scripts/CI/test-normal-ios-raw-capture.py` extracts and executes the original
Bash functions and PHASE0. It uses explicit `simctl`, IDB, `sips`, and BSD `stat`
boundary doubles. The synthetic PNG fixtures are unrelated to the real screenshot.
This is no macOS `sips` execution, simulator, Apple SDK, UI or hardware test.

Baseline completed 12:08:46.864798 with 23 executed, 17 PASS, 6 FAIL, 0 errors/skips.
Candidate completed 12:09:56.142662 with 23 executed, 23 PASS, 0 FAIL/errors/skips.
The unchanged test-driver hash and before/after candidate source hash are recorded.
Whole original shell `bash -n` also returned 0.

The six red cases demonstrate:

- an already-landscape raw fixture is rejected after the historical transform;
- its bytes are overwritten in all three capture paths;
- a portrait fixture can be rotated into falsely passing PHASE0;
- the source still contains the pixel-rewrite command.

The retained green controls also exercise real extracted shell behavior for
capture/rotation errors, missing/small/malformed/square/wrong-orientation files,
both valid orientations, all four exact IDB rotation commands, unsupported
rotation rejection, and original accessibility collection after capture.

Two setup attempts executed zero tests: an unsupported sparse-checkout CLI
option and Sentinel filesystem-full failure before Python launch. They remain
separate from the actual 23-case RED/GREEN runs. No result is relabeled as success.

Reproduce after a clean checkout, choosing a new evidence directory:

`python Scripts/CI/test-normal-ios-raw-capture.py --evidence-dir build/normal-ios-raw-capture-check`

Verify the sealed source, authentic receipts and recorded results without
executing a simulator:

`python docs/hq-integration/normal-ios-orientation-44716258538-20261120/verify-evidence.py --git-ref HEAD`

## Remaining gate

Run the original normal `ios-build.yml` acceptance on the reviewed, frozen
combined source. It must preserve raw screenshots and pass the original PHASE0
and every subsequent required phase. A valid landscape screenshot alone cannot
establish that the app/Reader/Search/RTL features work. No rerun was dispatched
by this repair branch; Root owns the next shared-source freeze/dispatch.
