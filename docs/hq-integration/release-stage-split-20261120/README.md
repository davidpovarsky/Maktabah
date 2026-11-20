# Sequential Release orchestration — 2026-11-20

## Outcome and scope

The candidate moves the original full Release acceptance into three sequential jobs of the existing workflow. It retains the original Debug app, runner, test bundle, generated xctestrun, prototype app, all five configurations, 96 required UI executions and two separate prototype oracles. Only the original final Release verifier can publish full acceptance.

Actual validation so far: **76/76 portable Python controls**, **14 source-preservation checks**, Python syntax for eight changed/new Python files, and YAML parsing plus the reviewed job dependency checks. These controls execute on Linux with explicitly synthetic archive/XCTest evidence and mocked external command boundaries. **Apple builds, cross-host test execution and Native Release execution for this change are NOT_RUN.** No historical Native failure is converted into a pass.

The source base is `c24f71123818576e06cafdc8474a525be0f30811`. The owned branch is `codex/otzaria-release-stage-split-20261120`; Windows worktree: `C:\Users\DAVID\Code\Maktabah-release-stage-split-20261120`. It is a small sparse checkout. The patch changes CI orchestration and its fixtures only; app sources, upstream SDKs/engines, the Xcode project, XCTest source, data and both acceptance manifests are preserved. Root owns integration and dispatch.

## Jobs and budgets

| Job | Work and required predecessor | Job limit | Maximum named child budgets |
| --- | --- | --- | --- |
| Release build and prototype | Original source preflight, real Debug build-for-testing, original separate prototype build, exact product handoff | 210 minutes | Original Debug helper 4,200 seconds; prototype 900 seconds; original early SDK/tool preflights retained |
| Release native matrix (partial acceptance) | Authenticated build job success; unchanged original products/xctestrun; original 11-inch, 13-inch, phone and largest-text matrix | 345 minutes | Import 1,200; fresh original HID preparation 360; matrix 16,200 seconds; 49 minutes remain for hashing, packaging and uploads |
| Release production upgrade and final acceptance | Authenticated successful build and complete native matrix; original dependencies restored; original production native installer and same-container Release upgrade; original final strict gate | 300 minutes | Two imports of 1,200 each; input restoration 4,200; original production runner 7,200 seconds; 70 minutes remain for verification and uploads |

The matrix retains each original 600-second XCTest gate. The total matrix budget is bounded; a collection of slow/failing cases can still exceed it and remains an incomplete result. This change does not promise that every worst-case per-test allowance fits within one hosted job.

The workflow dispatch inputs, permissions, concurrency key, original workflow path and unrelated jobs are unchanged. The original full matrix is a mandatory dependency of production. Build-only status is `RELEASE_BUILD_ONLY_PASS` with zero UI executions. Native-only status is `RELEASE_NATIVE_MATRIX_ONLY_PASS`: when all original gates actually pass it records 95 UI executions and two separate oracles, with the production UI case still not run. Both explicitly retain `full_release_acceptance=false`. Failed stages retain raw observations and unknown aggregate counts instead of inventing successes or failures.

## Exact product and evidence transfer

The first job packages the original `build/DerivedData/Build/Products` and original prototype app. Its receipt binds every regular file's SHA256 and size, every directory and symbolic link, and exact mode bits. Hard links are serialized as independent identical bytes. Framework `Versions/Current` aliases resolve through the authenticated inventory; cycles, escapes, uncarried targets and links outside the same product root are rejected. The receiver verifies the complete tar before extraction and refuses to replace different existing files. All original products are checked again before and after Native, input restoration and production.

The receiver authenticates the immutable GitHub artifact ID, name, size and ZIP SHA256, exact repository/run/head/attempt, successful uniquely named producer job and upload time within that job. It also checks the producer tar digest passed through the actual `needs` output. GitHub exposes no direct artifact job ID: the receipt states the narrower digest/run/head/attempt/job/time binding explicitly. The workflow may still be running; only the completed predecessor job must have succeeded.

Every stage independently checks the exact checkout and source/test/project trees, actual tracked helper/workflow/test bytes, full Release manifest and source-input configuration, Xcode build, Swift compiler, Simulator SDK and selected runtime identifier/version/build. App and dependency bytes continue through the original source auditor, including its existing narrowly audited generated privacy handling. The split introduces no new source exception.

Only matching products and evidence cross the boundary. Whole DerivedData caches, app data containers and downloaded databases are not copied between jobs. The original generated xctestrun bytes are preserved, and Native invokes Apple's original `test-without-building -xctestrun` mode. Unknown plist formats, ambiguous test-run files, absolute app/runner paths or filtered plist selections fail closed. Ordinary same-job Native invocation retains its original command and gates.

The final production job restores source/dependencies using the original `hq-stage2-focused-apple.py` sequence with a new explicit input-only option. That option returns before the Debug build command and writes to a separate evidence directory. Exact original locks, package revisions, Hanlin source, generated native context, actual Source/Vendor byte inventory and Embedded resource hashes must match the accepted Debug preparation. The original Debug products and first-build evidence are never replaced. The unchanged production runner then builds the genuine Release binary, provisions a new owned Simulator through that original Debug app, and upgrades the **same ordinary data container** to Release. The original production test and final strict five-configuration verifier remain mandatory.

Separate artifacts retain build, native and production failures. The unique final `runtime27-evidence` artifact is produced by the production job only in Release mode; it contains imported source-qualified native evidence plus production observations. Original xcresult bundles and visual captures remain separate artifacts. An archive upload or import does not itself grant acceptance. Because attempt identity is strict, rerunning only a downstream failed job cannot silently borrow a predecessor from a different workflow attempt; a fresh complete attempt is needed.

## Existing Release HID dependency repaired

The unchanged Release manifest includes `R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector`. Its existing implementation sends real A/Delete/Escape events through the original HID transport. The matrix previously started `HIDComparison` only when a phase-specific `runtime27_contract` existed; the full Release path instead uses `release_manifest`. That condition could not start the required transport for the Release case.

The new condition additionally recognizes this exact already-selected Release case. It uses the unchanged `HIDComparison`, owner/UDID checks, token delivery, evidence redaction and cleanup. The Native job executes the unchanged pinned HID preparation on its own Mac, so it does not reuse absolute tool paths from the build host. Existing Native92/focused group behavior and explicit group opt-outs are preserved. No XCTest source, gesture, UUID, assertion or timeout changes. Five source/sequence controls prove the old actual condition is false for this Release selection, the new condition is true, unrelated selections remain false, original Native opt-outs hold, and tool preparation failure prevents matrix execution. Actual Apple HID execution remains pending.

## Evidence and reproduction

`RESULT.json` binds the tested source bytes, command results and log digests. The 76 controls comprise 29 archive/provenance tests, 24 orchestration/input/HID tests and all 23 original Release-gate tests. `source-preservation.json` compares the actual original and candidate source: the original production runner, strict verifier, existing gate tests, runtime27 driver, full manifest and zero-skip verifier are identical as canonical Git bytes; removing only the new explicit input-only/xctestrun/Release-HID seams restores the complete original helper/matrix AST. The original source-audit body and final strict-gate body are AST-identical after extraction into reusable functions.

The first stage-fixture attempt had 17 passes and two errors because its synthetic positive XCTest log omitted the original `Executed N tests` line. The unchanged original zero-skip verifier correctly rejected it. `stages-attempt1.log` is retained; the fixture was corrected, and the gate was not weakened. The earlier 71-control result before the additional five HID controls is also retained separately.

The relocation/schema check additionally used an authentic retained file from failed Native75 run [44559352638](https://github.com/davidpovarsky/Maktabah/actions/runs/44559352638), exact source `ef449e640c3fd538b52627a48ea09846a785c52e`, Xcode 27.2 / build 27B52. Artifact 14566077193 is 71,825,219 bytes, verified against GitHub SHA256 `b2329e9f0263d24744c192ad03bda26bcfd8776f9459d0b6ed2481891b76a06d`. Its original 4,992-byte xctestrun has SHA256 `e8074d3ac6336b468191ea466f66df6801df09f3c04dfeba3a819d27a0389277`, FormatVersion 1 and the reviewed relative product paths. `original-xctestrun-schema.json` retains the actual fields. This is a schema observation from a failed historical run, **not** cross-host runtime acceptance for the new split.

Apple documents the build-once/test-without-building command in [TN2339](https://developer.apple.com/library/archive/technotes/tn2339/_index.html) and discusses testing built products on another machine with the same Xcode version in [Testing in Xcode, WWDC 2019](https://developer.apple.com/videos/play/wwdc2019/413/?time=2270). The implementation still requires its own actual Apple run.

Run the portable controls from the repository root:

```sh
python3 Scripts/CI/test-runtime27-release-handoff.py
python3 Scripts/CI/test-runtime27-release-stages.py
python3 Scripts/CI/test-runtime27-release-gate.py
python3 Scripts/CI/verify-release-stage-preservation.py --base c24f71123818576e06cafdc8474a525be0f30811 --out build/release-stage-preservation.json
```

The archive mode/symlink fixtures require a POSIX filesystem. The source-preservation command reads the exact base directly from Git; its optional verified baseline-directory input was used for the Linux scratch export. Its byte comparisons use canonical Git LF. On a Windows checkout with CRLF, it requires that Git's actual path-specific filter yields exactly those LF bytes and retains the separate raw-worktree fingerprints; it does not confuse those two representations. The Windows owned worktree receives only these small source/evidence files; no app binary, SDK, engine, database or index is downloaded there.

Before dispatch, Root must merge this CI-only branch normally with the current integration branch, retaining its newer R27 hash, full-phase diagnostic classification and source-pin updates. The isolated base is not itself a newly frozen app candidate. No immutable CI branch was changed or dispatched by this agent.

The same 14 source-preservation checks also passed against the actual Git base in the Windows owned worktree. See windows-source-preservation.json for separate raw CRLF and canonical LF fingerprints. Git diff --check passed; only the declared CI paths and this evidence directory are staged.
