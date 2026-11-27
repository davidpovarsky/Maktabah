# Original loaded-hit reveal and one-page search continuation

## Delivered scope

This packet implements the separate original-UI continuation requested by Wave3. It reveals a currently loaded hit with its exact version through the existing list, or consumes one opaque token to ask the existing backend owner for one next page. It does not add public App Intent hit/cursor parameters, start a replacement search, clear filters, decode arbitrary locator tokens, open a reader, or modify the old first-page service/query.

The feature is ready for source intake and combined app/native qualification. **It is not accepted as an Apple build, provider run or UI test.** Wave3 must wire the real scene/registry/Composition authority, reconcile project membership, and perform the native cases listed below before exposing the system surface.

## Integration identity and ownership

- Original integrated baseline: `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`.
- Direct parent of this packet: passive-ledger donor `a23ae34c74b1cde8a9344fefd1e41e87101784b0`. Its five product paths and separate component evidence are inherited, not duplicated.
- Feature branch: `codex/otzaria-search-continuation-20261127` in an isolated Oracle rootfs repository. The Data worktree's branch remains at the clean donor checkpoint.
- Separate original first-page correction to preserve in combined integration: `b5f52c446a5eba31273b6e3ee61d53ba022244d5`.
- Exact final seven-file product manifest: `FINAL_SOURCE_MANIFEST.json`, identical to `REVIEW_CANDIDATE_4.json` (`471e588de928383789a52d311dcd93a37a2e8399f44419d285e8d48930d878ee`).
- This packet is for direct Wave3 intake. It is not based on the earlier root-core source lineage and must not be reported as such.

At handoff, the coordinator reports Wave3 integration `aa5092cd9452c242a21b49442398e4c645a0d757` with Source tree `0f43c34b97246e049c729c93a8607f5bd6ee3b22`, containing the first-page correction as `35b1352e`. This packet retains its verified `a23ae34c` parent; Wave3 must reconcile the additive PBX and real Scene wiring against its current integrated source. That later lineage is not a source or native result of these component controls.

The per-file provenance matrix records the original baseline, necessary hook, exclusive owner and actual upstream SHA. Root coordinated this scope in Asana task `1220939535420506`, comment `1220949535776986`, after the request in task `1220939536336523`, comment `1220947523139777`.

## Product behavior

`ActionSearchContinuation.swift` defines a separate source observation, opaque current-hit and next-page tokens, command, effects, visible receipt and optional UI sink. `OriginalSearchContinuationClaim` atomically consumes one token before any original loader or UI setter runs. It stores metadata only; it does not copy results or implement a provider.

The original backend ledger supplies accepted request/commit identity. The binding distinguishes dispatch from actual commit, raw consumed rows from displayed rows, raw cursors from normalized continuation, and an accepted empty terminal page from failure. It registers a passive terminal capture synchronously for the actual owned attempt. A real accepted page remains recorded even if cancellation/rebinding happens before the async consumer resumes; that earlier effect does not grant current authority.

The original list resolves exact current hit/version metadata and preserves the original grouping, version controls and filters. Its UIKit witness must be mounted in the original scene/window, have an actual current layout, and satisfy clipping, adjusted-scroll-inset and modal/transition visibility checks. A scroll request or `onAppear` is not a visibility receipt. One original loader dispatch is protected from an extra automatic appearance-triggered page.

The controller's cancellation and dirty-input guards also inspect synchronous original leaf busy state, covering the interval before Unified's queued loading mirror updates. The continuation cancels only its exact still-active original attempt, never a replacement or already accepted page.

### Explicit response attribution

The revised service joins a failure by exact request ID, source and operation. Acknowledgement provenance and shape are joined before any post-apply authority check. The actual binding's failure constructor supplies the frozen command source and operation.

`Outcome.unqualified(command:originalResponse:)` retains an unjoined response unchanged under its own provenance, including nested unqualified responses. **It is not success and does not prove that the attempted command had no effects.** Downstream code must handle it explicitly and must not extract its raw effects as effects of the attempted command. Nil/partial failure origin is unqualified.

An exactly joined operation still retains its genuine recorded effects if a later authority, deadline, cancellation or native/layout check refuses. See `WIRING_CONTRACT.md` for the exact live-authority closures and API.

## Actual verification and limits

All executions below used the existing Oracle Swift 6.4.3 Linux toolchain in a private rootfs write domain. No Apple SDK, app, simulator, provider, corpus or published-package operation ran for this packet.

| Evidence | Actual result | What it establishes |
|---|---:|---|
| Initial component compile | Original 28-file ActionCore plus Candidate3 contract and one-file focused Host service compiled; control fixture compile failed | The failed fixture lacked a local `@MainActor` annotation. Its raw failure is retained; product source was unchanged. |
| Corrected Candidate3 portable controls | 26/26 | Actual DTO/service/claim behavior with explicit apply/visible/authority/retained-state fixtures. No UIKit binding or provider. |
| Verbatim controller guard controls | Baseline 3/8 passed; candidate 8/8 passed | Five caller-guard counterexamples close before the queued Unified mirror, with declared leaf and stop stubs. No engine teardown claim. |
| Candidate3 iOS-conditional parse | Exit 0 | Linux frontend syntax only; not Apple SDK typechecking. |
| Attribution baseline against unchanged old compiled service | 0/6 passed, expected exit 1 | All six foreign/unattested response counterexamples reproduced actual old-service misattribution. |
| Candidate4 attribution controls | 19/19 | Actual revised contract/service with fixture responses: foreign request/source/operation, nil/partial origin, malformed/nested responses, and preservation of joined A effects after late refusal. |
| Candidate4 changed-source iOS-conditional parse | Exit 0 | Syntax of the changed contract/service/binding constructor only. |

The old case titled “all-deduplicated accepted page” only validates an ordinary 50-row receipt shape. It does not prove actual display deduplication. Empty/deduplicated provider/UI behavior remains a native gate. The original historical 68-case suite was not rerun, and its past result is not attributed to this packet.

Candidate4 controls did not rerun the unchanged old 26 cases or controller controls. Their exact old source association remains preserved. The final change affects only the contract, service and one binding failure-constructor hunk. Independent root/library review verified this delta; the prior UIKit review remains scoped to unchanged implementation. `PEER_REVIEW.md` records findings, fixes and limits.

### Raw evidence

`actual-rootfs-controls-and-sources.tar.gz` is 187,868 bytes, SHA256 `03a290e078d253a8bc6fc28e87c1f2cb1ae8530bf92e4801f9bd464342fd21c6`. It contains 132 indexed original source/raw-evidence members plus its index. `ARCHIVE_INDEX.json` has SHA256 `dafed7d348ca128d3f169b035998d1364654f54b9da058b994c788e95c2c19a6`. Every member was read back and hash-checked after transfer.

The archive includes original 28-file Core inputs/resources, exact candidate revisions, all executed scripts/controls, actual compiler argv/tool receipts, both early attempts, baseline/candidate raw stdout/stderr, generated controller boundary sources, final attribution results and the explicit build-generated `Bundle.module` accessor. The readable subset in `actual-control-receipts/` preserves the same bytes.

- Candidate3 actual result: `RESULT-attempt2.json`, SHA256 `adf3bdfb240436c4b43ce3abea55e12fb4ff36273697568390669abde208983f`.
- Candidate4 actual result: `revision-2/RESULT.json`, SHA256 `6c88e30487b8a76f005858751582ba1b25f456df2c8d6c49c8912a3c607c74d7`.
- Candidate4 actual control stdout: SHA256 `1826beb98bcd6b39be6e23725b14122a49bc8e8faeb8626f53cd130170011c1d`.
- Attribution baseline stdout: SHA256 `cc8507fe8fdd8f33deabca8bf4d2e55bef235b1f3bb85774b45e07dcef184f5f`.

Original compiled modules, libraries and executables remain at `/tmp/otzaria-search-continuation-checks-c7f9cc7d8f1b41e68627c818389a4d42/output/` and `revision-2/output/`. They were not copied into Git or cleaned. `COMPILED_ARTIFACTS.json` and the actual result files contain their exact sizes and SHA256s. Compiler caches are not evidence substitutes and are not included in the archive.

The attribution run's maximum sampled aggregate owned allocation was 32,858,112 bytes, below its 40 MiB cap; its minimum rootfs free space was 3,664,875,520 bytes, above the 1 GiB floor. All recorded owned compiler/control groups exited. The separate earlier `DATA_FLOOR_BLOCKED.json` remains intact. No Data write or live capacity-gate relaxation was used to obtain these results.

## Project membership proposal

`project-membership/` includes the complete original 14-file proposal packet and its original archive (202,727 bytes; SHA256 `bed36c458b5ac23376a66cb1a4b0149d007517777ab38c937b0b712b87e06af5`). It is a reviewable patch, not an applied project mutation. It adds the ledger to all three original app targets and the claim/binding to iOS only. Core/Host files use their existing SwiftPM source directories.

The proposal observed Candidate3's binding. `FINAL_SOURCE_RECONCILIATION.json` records Candidate4's exact constructor-only change and unchanged target mapping without rewriting the original proposal. Wave3 must reconcile/apply it to the actual current project and preserve all original configurations, SDKs, source ownership and first-page correction.

## Remaining combined/native qualification

The following are still required on the actual combined app and original data/provider context:

- Real scene/registry/Composition wiring with the original authority and backend/RPC snapshot; explicit handling of unqualified responses.
- Correct current hit/version reveal, filtered and ambiguous refusal, and original selection/expansion behavior.
- Source/configuration/scene/backend/manual-state ABA, cancellation before and after actual commit, and exact owned-attempt cancellation.
- Exactly one original page including empty and deduplicated results, no appearance-triggered extra page, current page layout and source identity.
- Original footer and pan continuation, plus keyboard/VoiceOver scrolling. The sticky automatic-prefetch guard has not been qualified for non-pan input; the original explicit Load More footer remains available.
- Actual iPad/iPhone layout and visibility after resize, preserving the original first-page invariant and current original model/provider identity.

No source component result in this packet is credited as completion of those UI gates.
