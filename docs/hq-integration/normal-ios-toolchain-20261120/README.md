# Normal iOS build: SDK-matched iOS 27 toolchain

## Source-backed correction

The project already declares iOS 27.0. The normal ios-build workflow still selected Xcode 26 and macos-26, and its actual earlier run 44672943654 used Xcode 26.6 / SDK 26.5. That run failed in the ActionCore deployment metadata and standalone Inspector fixture before a simulator install. This change corrects the source/toolchain mismatch without claiming an observed install failure.

The six original Apple jobs now use the existing xcode-27 runner and the unchanged select-runtime27-toolchain.py. This selector has already executed successfully elsewhere in the project; this normal-workflow integration still requires its own Apple execution. It inspects installed Xcode, SDK and available runtime/device support, publishes scoped DEVELOPER_DIR and the exact runtime identifier, and neither installs tools nor changes global xcode-select state.

Framework and SwiftPM cache identities are calculated in a separate subsequent step, after GitHub publishes GITHUB_ENV. They include actual Xcode version/build, Swift compiler version/target, device SDK and simulator SDK. The existing Rust version, source/header/resource, lockfile and package-graph portions of cache keys remain. No old Xcode26 cache key, cross-run binary or arbitrary artifact is forced into the new build.

The original iPad acceptance interface is unchanged. Its initial selection now executes the original common selector's matching logic, requires SDK27, checks the actual built app's MinimumOSVersion, honors the exact selected runtime when provided, and chooses a 13-inch iPad Pro type supported by that runtime and present in the installed device inventory. Local invocations without an explicit runtime retain automatic choice within the installed matching SDK27 pair. The previous last-array-element selection is removed. A bounded selection receipt records observations and explicitly records zero Native executions at that point.

## Original gates preserved

All other workflow steps, conditions, inputs, job dependencies, timeouts, permissions and SDK pin compare structurally equal to the original. Removing only the replaced runtime-selection block restores the entire original acceptance script exactly. Original build, standalone Inspector tests, simulator/iPad acceptance, unsigned device build, resource checks, framework validation, semantic cargo check, summary and optional heavy/corpus/live gates remain.

The Hanlin SDK stays at e00498e33f106cc43be0476ffa2e09329c8ca300, and its three materialization checks plus the exact macro-authorization helper remain unchanged. No application source, package deployment metadata, project setting, Native test selection or upstream code is changed here. The separate ActionCore platform repair 58b32dc24b480007b98027af11ce637aff37cb00 and Inspector fixture repair 2f74d05b1cf75597b3a38fa64d0939b45caa44c2 must be present in the combined source.

## Actual validation and limits

| Validation | Observed result |
| --- | --- |
| Same 29 source-contract methods against old source | 6 methods passed, 22 failed methods and 1 errored method; 34 failure entries include job subtests, and the sole error is the newly expected receipt being absent from the legacy selector. |
| Same 29 source-contract methods against candidate | 29 passed; zero failures, errors or skips. |
| Original modified acceptance shell syntax | Git Bash -n exit 0, empty stderr. |
| Source before/after execution | All four recorded source hashes unchanged. |
| Apple compilation, Simulator/Native execution, workflow dispatch | Not run by these fixtures. |

The runtime controls execute the actual embedded Python program and the original shared selector against explicit OS/SDK inventory and subprocess doubles. They use real temporary plist/receipt I/O. They cover correct pairing, explicit ownership, unordered old runtimes, supported device identity, missing/unavailable/duplicate runtime, SDK26/28 refusal, SDK minor drift, app minimum/patch requirements, missing/malformed minimum, incomplete device families and unsafe identifiers. Workflow controls parse the original YAML and check all unmodified steps exactly. They do not substitute for Apple or Native acceptance.

Reproduce from this repository, with the recorded base object present:

    python3 Scripts/CI/test-normal-ios-toolchain.py --source-ref 2f74d05b1cf75597b3a38fa64d0939b45caa44c2 --report build/normal-ios-toolchain-20261120/baseline-result.json
    python3 Scripts/CI/test-normal-ios-toolchain.py --report build/normal-ios-toolchain-20261120/candidate-result.json
    bash -n Scripts/run-ipad-simulator-acceptance.sh

The baseline command intentionally fails its new admission contract. Raw logs and reports are retained as gzip with canonical committed-file checksums. The workflow and acceptance script are the only operational modifications; the test driver and this evidence are additive.

## Next combined normal run

Root chooses a new frozen branch/HEAD after integration. The original normal inputs are all false: run_heavy_otzaria_acceptance, run_corpus_acceptance and run_live_sefaria_smoke. The workflow has no source-SHA or cross-run-artifact input; check the immutable branch and authenticate the resulting run.head_sha. Do not dispatch on the prior 127ee checkout or change a frozen Native branch.

The earlier normal Otzaria framework is based on older compiled inputs and cannot satisfy the new d5 source. Zayit source and the remote SwiftPM graph may be identical, but the selected compiler/SDK fingerprint and cache scope still govern reuse. Original same-run framework/SourcePackages artifact transfer remains. GitHub branch cache scope can prevent reuse from a sibling repair branch; a cache miss must follow the existing verified build path, not bypass it. See the primary [GitHub cache scope documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#restrictions-for-accessing-a-cache).

This source-only repair is ready to integrate. Actual Xcode27 normal build/Inspector/iPad/device outcomes remain pending.
