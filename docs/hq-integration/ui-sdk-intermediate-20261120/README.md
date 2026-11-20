# Immutable intermediate SDK-only route

## Purpose and status

This additional workflow exists only because the already authorized manual dispatch route is unavailable through the current connected capabilities. It runs the existing SDK-only job on one exact push branch. It does not modify the original workflow, compiler driver, toolchain selection, membership checks, declaration checker, Hanlin preparation, Host build, source regressions, workspace tests, test selection, or acceptance assertions.

**Prepared, not activated.** Root alone reviews the final source, creates the immutable branch, and publishes the activating commit. No Apple compilation, Swift execution or Native UI execution occurred while preparing this wrapper.

The reviewed application/test source is `e603d8182a1c10c4b37b14c92b5f0bc3829edea8`, containing the merged History and Groups100 changes. Its four exact Source/Vendor/project/UITest trees are pinned in the guard. Root must explicitly review and update those pins if later B/C changes are included. This is an intermediate SDK source binding, not the final four-pin Native116/Release114 freeze.

## Exact route

- New workflow: `.github/workflows/otzaria-ui-sdk-intermediate.yml`.
- Only trigger: push to `codex/otzaria-ui-sdk-intermediate-20261120`.
- Only job: `ui-sdk-check-only`, on `xcode-27`, original 15-minute budget.
- Exact SHA checkout: `github.sha`; read-only Actions/contents permissions.
- No workflow dispatch, workflow-call input, retry, Native invocation or cancellation request.
- Concurrency is isolated to the same SDK-only branch identity with cancellation disabled, so activation cannot supersede another in-flight check.
- Original selector, typecheck, workspace and always-upload step objects are identical to the original SDK job.

Manual input conditions are represented by fixed route constants: SDK-only=true, runner=xcode-27, runtime mode=off, no source_ref, no production release, no Books Updates, no focused app, no UI diagnostics. There is no caller-controlled input to combine acceptance modes. The original workflow has no global env block to copy.

## Source authority

The new helper verifies the repository, exact branch, push event, actual GitHub SHA and checked-out HEAD. It requires a clean tracked checkout, all eleven complete source files, and exact original Git blobs for the original workflow and its selector/typecheck/workspace drivers. Each observed helper/source file must also equal its committed Git blob.

Before and after the original checks it records HEAD, the reviewed four source trees, source file sizes/SHA256/Git blobs, run identity and scope. Changed source, a missing before observation, wrong tree, wrong ref, dirty checkout, symlink or missing input fails closed. The helper does not declare compilation success. Its JSON receipts use the original uploaded `ui-acceptance-typecheck.*` prefix; a failed original command remains a failed job even if the later source comparison succeeds.

## Real compiler scope

The unchanged driver uses actual Apple `swiftc -c -whole-module-optimization`, Swift6, DEBUG, the original upcoming-feature flags and arm64 iOS27 Simulator SDK. It compiles eleven complete XCTest files, including Faithful (Profile, Groups and History), GlobalSearch (INDEX) and R27. It then separately parses selected declarations. The source tree has eighteen XCTest files; this route does not claim full-target compilation for the seven other files. It supplies no Native UI pass.

The unchanged remainder includes original source membership checks, the standalone original native UIKit/SwiftUI components, the real UIRoutingHost SDK package build, pinned Hanlin preparation and original SQLite/source/workspace regressions. This route does not execute the independent Core194 acceptance or establish app cold-engine behavior.

## Local verification

Twelve local Python controls passed on Linux. They compare the preserved original step objects/permissions/budget, check the single exact trigger, verify file admission and source authority using explicit Git/environment boundary doubles and real temporary files, and verify persistent failure receipts. These are wrapper controls only.

Raw commands, output, input hashes and all twelve names are retained. No local Swift compiler is available. Apple SDK compile and Native execution are **NOT_RUN** at preparation.

The full original workflow, exact GitHub e603 commit/tree/input observations, helper/control source snapshots and result log are retained under `raw/`. The two new runtime files are the only proposed non-document changes. No remote branch or workflow was activated by Agent A.
