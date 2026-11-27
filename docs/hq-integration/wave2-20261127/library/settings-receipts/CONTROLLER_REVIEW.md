# Read-only review of the study UI controller draft

Reviewed file: `production-study-v40-ui.py`, SHA-256 `fd0ecaf9f6f93b03234b2c1e76e4a239b0d4f57a8da070c212f23958ce1b27e5`, 20,497 bytes. This is a draft-source review, not an executed native result. The root owns and edits the controller; this worker has not modified it.

## Context relocation must preserve the original receipt

The draft seals `OTZARIA_LIBRARY_UPDATE_CONTEXT` before installing the current app, then requires its absolute database path to equal the newly admitted managed database path. A real container move can therefore reject a valid installation before UI. A move caused by XCTest's installation can also occur after the host's initial check.

Keep the original input file immutable. Record a separately observed effective context, retaining same-UDID MCM app/group metadata and the unchanged source/target fields. The new helper validates that chain and normal relative database/download/workspace/qualified/annotation paths. It cannot repair a test that already consumed a stale absolute path. The original search test's bounded MCM discovery is an existing example of test-side read-only ownership admission; neither discovering the first database filename nor rewriting the original receipt is sufficient.

## Final Settings postchecks need actual attachment/official bindings

`changed_database` checks the expected release ID/tag, hashes the current database, runs SQLite integrity and requires positive counts. It does not compare those final observations with the actual `settings-update-installed` attachment or the exact counts in `settings-update-official-target`. It also omits final multipart asset identity, retained-package inventories and cleanup remnants. A changed file between the UI result and the host postcheck could otherwise be misattributed to the accepted result.

`seal_success` supplies those concrete bindings. It selects attachments through the actual export manifest for the exact one test and device, verifies original zero-skip summary/tree/log, matches verified public release/manifests/statistics, checks final database/hash/counts/stability, preserves both raw package manifests and complete inventories and checks actual transaction/download/staging absence. It does not infer semantic Note/Favorite/Group reopening from filesystem snapshots; the full passing original UI case remains required.

The draft also requires a literal `profileID == "production"`. The original `OtzariaDatabaseInstallationManifest` producer omits optional profile fields for production, and its effective accessors interpret absent/null as production/version 1. The new shared `require_production_profile` follows those exact semantics and rejects blank, foreign or malformed values. The context-preparation helper is corrected to call the same gate.

## Separate phase calls do not enforce the complete prerequisite order

The draft gives each selector its own invocation and preserves the explicit order within one selected phase. Its command-line entry points still allow `settings-update-last` to be invoked before the other v40 phases. The name alone does not establish a dependency. Updating to v41 first would invalidate the v40 source gates needed for packages/pages/reader/Inspector/Groups100/performance.

Before the update phase, root should require its exact same-owner/source/build prerequisite receipts, or bind an external orchestration receipt that actually proves the required phases and order. The Settings success helper requires a genuine prior pages trace and both actual installed v40 packages; it does not claim that those inputs alone prove every Reader/Inspector/Groups100/PERF gate.

## Settings capacity admission is currently an estimate

The draft assigns the update phase `12 * GiB` payload allowance plus measured possible app/runner copy bytes, 1 GiB evidence, 2,000,000,000 B OS margin and the declared other-owner reservation. The observed v41 full archive has 2,124,305,356 compressed bytes. The unchanged product's fresh multipart download preflight alone requires `8*C + 1 GiB = 18,068,184,672 B` of then-available space. Depending on actual app/runner image size, the draft can admit less than that and then fail in the original product preflight.

Extraction independently requires output estimate plus the existing 4,355,063,808 B v40 database plus 1 GiB. The actual v41 uncompressed frame size has not been read in this audit. If the frame does not provide it, the product's `6*C` fallback applies at extraction, after two compressed copies may already occupy space. Do not describe the 12 GiB draft allowance as a proved upper bound or silently weaken an installer gate.

This finding does not change the three existing v40 installation gates: outer 24,000,000,000 decimal work bytes, the shell's 22 GiB check and the product preflight remain unchanged. The detailed original v40 lifecycle/budget is retained separately under `storage-v40-budget`. No v41 corpus download or full-database measurement was performed for this review.
