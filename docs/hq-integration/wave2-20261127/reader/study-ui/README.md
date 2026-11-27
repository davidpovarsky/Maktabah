# Original production study UI controller

## Current checkpoint

`Scripts/CI/production-study-v40-ui.py` implements sequential execution of the registered original study UI cases on the exact Simulator retained by a successful original production-v40 installation. It adds no application Source, fixture data, replacement reader, synthetic search response, test workspace namespace or bootstrap bypass.

This checkpoint is **controller implementation and source-control evidence only**. No app, Simulator, real UI case, positive production Settings envelope, live log capture, physical offline window or performance acceptance was executed by its focused controls. The full-v40 execution profile must be finalized against the actual integrated candidate before execution. The prerequisite helper deliberately rejects offline and PERF01–03 until their genuine producer contracts and actual evidence are implemented and admitted.

The original full-v32 driver and its two selectors are unchanged. The separate full-v40 Reader/Inspector driver and Groups100 driver retain their own original workloads and receipts. This controller does not reclassify their source checks as UI results.

## Registered phases

Each row executes in its own invocation. Within a row, selectors execute one at a time through separate `xcodebuild test-without-building` calls, with parallel testing disabled. XCTest class or method ordering is never used to establish a prerequisite.

| Phase | Original workload | Per-case timeout |
| --- | --- | ---: |
| `packages` | Discover, install and cold-reopen both published production-v40 packages through Search Data | 6,000 s |
| `pages` | Zayit cumulative 50/100/150 with SQL identity; Otzaria cumulative pages/metadata | 1,800 s |
| `preview-hit` | Observe the actual first-page נפשי hit for an independent complete-context oracle | 1,800 s |
| `preview-reader` | Complete paragraph/chapter search context; original Reader line/paragraph/chapter source focus | 3,600 s |
| `reader-selection-navigation` | Native UTF-16 selection and three-backend restoration; paragraph/chapter pull cancellation and canonical TOC | 3,600 s |
| `reader-continuous-pull` | One real held contact, arm/retreat/release in paragraph and chapter modes | 1,800 s |
| `sefaria-contexts` | Three actual search editions across pages; English result under Hebrew Source/Translation/Both controls | 1,800 s |
| `inspector` | Full-v40 semantic groups, linked bodies and source locators | 3,600 s |
| `inspector-text-modes` | Same ordinary Sefaria tab across eight visible/hidden Inspector mode observations | 1,800 s |
| `settings-update-last` | Original Books Updates transaction, rollback/recovery/final Retry, saved user state and warm/cold checks | 7,200 s |
| `search-after-settings` | Actual cold-v41 rejection of both retained v40 package readiness/query paths, plus host submit evidence | 1,800 s |

These are execution bounds, not performance targets. Actual case identifiers are the fixed `PHASES` map in the committed controller. No arbitrary selector or extra runner environment is accepted.

## Required owner, build and source inputs

Execution requires the actual original installation result whose status is `ORIGINAL_INTEGRATED_V40_NATIVE_PASS`, its retained Shutdown Simulator, and the complete original installation/evidence receipts. An Oracle corpus recovery is an independent source input and cannot supply this installation result.

The controller reuses `RetainedV40Installation` and the original shared source/build admission. The active checkout, Source/Vendor/project/test trees, frozen execution inputs, SDK route, app and runner/test images, Mach-O UUIDs, original XCTestRun, SDK-matched iPadOS 27 runtime and exact owned 13-inch iPad type must agree. It checks current installed images before and after execution; unchanged images are reused, while actual installation of admitted images is followed by a fresh owner check.

All extra execution sources, source oracles and test contracts in `FILES`, including this controller and its support modules, are captured by complete-file witnesses. Actual execution rejects dirty or missing files. `source-check` reads and reports declarations and bytes only; it does not qualify an app or execute a selector.

Example source-only command, from the actual checkout:

```sh
python3.12 Scripts/CI/production-study-v40-ui.py source-check pages
```

Native execution also requires the existing explicit `FAITHFUL_RUNTIME27_IDENTIFIER` for the SDK-matched runtime. An invocation has this shape, using actual observed paths and UDID:

```sh
python3.12 Scripts/CI/production-study-v40-ui.py execute pages \
  --owned-simulator ACTUAL_UPPERCASE_UDID \
  --installation-result /absolute/original/installation/RESULT.json \
  --reserved-other-bytes ACTUAL_CONCURRENT_RESERVATION \
  --output /absolute/checkout/build/artifacts/new-owned-pages-run
```

The output must be fresh and canonical under this checkout's `build/artifacts`. Zero concurrent reservation is legitimate only when it reflects the actual coordinated allocation. The phase capacity gate reserves possible app/runner copies, the phase work budget, 1 GiB for evidence, 2,000,000,000 bytes for the OS, and that declared concurrent allocation. Package installation retains its actual additional peak of 10,241,792,951 bytes. Settings retains at least the original 24,000,000,000-byte work budget and rechecks the original product extraction preflight; none of the original installation gates is reduced.

## Independent input and native observation contracts

Preview/Reader phases accept only the five original `PRODUCTION_SEARCH_PREVIEW_*` keys in `PREVIEW_KEYS`, supplied through `--runner-inputs` as a JSON object. The oracle is produced after the actual observed hit and must be bound to the original full source service, presentation and compile evidence. The controller does not synthesize a hit or build an oracle from its own expected UI output. Every provided file is bounded, canonical and rechecked after the phase.

Sefaria and Inspector phases use the exact committed independent oracles and retained API/source receipts. Actual Search preview edition and canonical default Reader/Inspector edition remain distinct scopes. The same-tab Inspector test's complete accessibility value is not a claim that its entire chapter is visually expanded at once.

Continuous pull additionally requires `--pinned-hid-tools` naming the integration owner's original protected idb tools. `ContinuousPullHost` starts before the exact case and observes actual app-container/database ownership. Its returned runner token is merged without a second prefix; the token is redacted from retained host command logs. One contact, thresholds, native identity and actual case acceptance remain the original host/test contract. Host cleanup precedes Simulator lifecycle changes on both success and failure.

## Settings runs only after v40 acceptance

`--prerequisites` names an immutable JSON mapping each `study:<pre-update-phase>` plus `full-v32`, `full-v40`, `groups100`, `offline` and `perf01-03` to an actual original result's `{path, bytes, sha256}` witness. `study-ui-prerequisites.py` checks the exact committed phase map and real producer evidence. Current offline/PERF placeholders reject admission even if a caller supplies a file labeled PASS. There is no manual-sign-off bypass.

Settings also requires `--pages-phase-result` for the actual admitted `pages` phase. The controller selects the original Otzaria paging case's exported JSONL/SQL attachment through its real export manifest, verifies its positive provider trace and binds its existing namespace/PID/prefix. The separately provided pages result must be exactly the same witness admitted by the ordering gate.

After current app/runner installation and genuine v40 admission, the original context helper observes the real MCM owner and generates a fresh context. `--annotations-path` is available when the actual original annotation file needs explicit disambiguation. The immutable effective context witness is the exact file passed to XCTest; it is rechecked afterward. A late container relocation that breaks the native case is a failure, not a reason to invent a passing receipt afterward.

The target remains the actual official Latest release `459809828`, `v41-20261126162443`. Original release, multipart manifest and statistics responses are retained and independently validated. If Latest has changed, the expected-target check stops the run; a different source is not silently relabeled v41.

The actual Settings case owns the mutation and all UI assertions. Only after its passed, zero-skipped execution and the post-run source/build/installed-image/input checks does `study-ui-settings-receipts.py` seal `ORIGINAL_SETTINGS_UPDATE_VERIFIED`. Its evidence includes the actual final v41 full file hash/SQL, original rollback/recovery, preserved v40 indexes and positive trace, user state and absence of transactional leftovers. The controller neither installs the database nor modifies the context to repair a failed UI assertion.

## Cold search after Settings

`search-after-settings` requires `--settings-phase-result`, the actual successful current-source Settings phase. It admits the retained actual v41 file identity and sealed old-v40 index inventories instead of reapplying the v40 corpus hash gate. Its snapshots explicitly reuse the sealed final full hash; they are not described as fresh full-file hashes.

An observed MCM relocation before the test can be qualified through the original owner chain and a new independent seal, preserving the earlier receipt. A relocation during the case still has to satisfy the case itself. No old receipt is rewritten.

`SearchLogCapture` starts before the original cold R08 selector. The exact passed case's exported attachment must join two real original submit messages with one fresh app PID, qualified current executable, expected namespace/backend/scopes/revisions and complete bounded log/process coverage. Unchanged provider JSONL bytes alone are insufficient. The capture verifies its own exact child cleanup before the Simulator is retained. A failed case or export invokes abort and cannot produce a passing phase.

## Result and failure boundaries

Ordinary v40 phases may return `EXACT_REGISTERED_FULL_V40_STUDY_PHASE_UI_PASS`. The post-update case has the separate status `EXACT_REGISTERED_POST_SETTINGS_V41_SEARCH_UI_AND_HOST_LOG_PASS`. All incomplete cases, source/build/context/image changes, missing attachments or failed cleanup return `FAILED_OR_INCOMPLETE` and raise. These phase statuses are not Native116, Release114+2, whole PERF01–03, physical-device or TestFlight acceptance.

Each original case retains its attempted command, timing, log, xcresult, original zero-skip/declaration verification, exported attachments and exact case result. The phase keeps before/after source, build, installation and input witnesses. Background owners stop first. If host-process cleanup cannot be verified, the controller leaves the owned Simulator available for diagnosis instead of pretending that shutdown is safe or complete.

## Focused controller controls

The nine controls use explicit device/UI/SDK/owner doubles and a tiny non-SQLite file. They verify source/context mutation rejection, Settings post-image-check sealing order, original prerequisite refusal before boot, distinct v41 scope after update, native/log failures, continuous-contact failure, and cleanup-before-retention. They execute no macOS command, app, actual database, network, Simulator or XCTest.

The first captured local run is retained unchanged under `source-controls-retained-run01`; its earlier uncaptured run is disclosed in that receipt and is not counted as nine additional tests. The test loader subsequently gained an explicit candidate-path argument for running the same controls from the repository's documentation directory. Reproduction uses the current committed controller:

```sh
python3 docs/hq-integration/wave2-20261127/reader/study-ui/test_study_ui_driver.py \
  --candidate Scripts/CI/production-study-v40-ui.py
```

Actual native execution, qualified offline/PERF producer contracts, current-source SDK/app qualification and coordinated storage remain required. These source controls do not satisfy those gates.

## Recorded Oracle source checks

The integrated checkpoint was checked on `tora-social-oracle` with the exact committed support modules. The same nine controller controls passed with the explicit candidate-path loader. All eleven registered phases passed the original source-only declaration/input check. Raw stdout/stderr for all twelve commands and the complete input witnesses are retained under `oracle-source-checks/`; its RESULT SHA-256 is `e62c985344702412bb9a577e0aba5834b69ed6dd5ad6027fdb07e8089a7837dd`.

The controller bytes are SHA-256 `613bbf862725b3b5a1b7171938a34381315e5e3640dcd065637b27f65a2d522a`. This is a separate execution of the same nine unique controls, not eighteen different cases. Every source-check result remains source-only; the profile is not finalized and no native, Simulator, corpus or network workload ran in these commands.
