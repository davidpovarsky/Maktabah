# Live12 manual-only source preparation

## Scope

This packet binds the independently reviewed diagnostic application at d4b1825bd5645f4949e4b57e48a73022c3b7cba1 to one possible future original Hanlin native journey. The application code, original UI tests, model, provider endpoint, SDK gitlink and acceptance assertions are unchanged from that reviewed source.

No live run, credential installation, provider request, app build or native test was performed by this preparation. The coordinator owns any subsequent publication handback, Apple allocation decision, temporary credential lifecycle and dispatch. This branch must not be activated merely because the source admission passes.

The previous actual Live11 run45103578190 at fdb78a44778c318b277506f0b09ba91c3b678e91 failed the original source-receipt assertion. It recorded one failed native case and zero passes/skips, with a successful app build. That failure remains open.

## Reviewed original event boundary

The new diagnostic source was independently reviewed against the actual public APIs pinned at Hanlin e00498e33f106cc43be0476ffa2e09329c8ca300. Its original stream event payloads and @MainActor @Sendable completion callback match. The original lifecycle, send and callback guards, callback order, tool dispatch and receipt oracle are unchanged.

The observation completionSucceeded is only the original AgentSession completion outcome. It does not prove an original finished event or any Host receipt. The original engine also closes normally when the underlying stream ends without a finished event. The new separate event observations preserve that distinction, and no acceptance rule is changed to interpret completion alone as success.

The five diagnostic source/schema controls and portable syntax parse are reused unchanged from d4. They are not rerun by this packet and are not native or provider acceptance. See REVIEWED_DIAGNOSTIC_REUSE.json and the preserved earlier diagnostic packet.

## Exact source changes from d4

| File | Change |
| --- | --- |
| Scripts/CI/runtime27-hanlin-live.py | Only REVIEWED_SOURCE changes from the reviewed Live11 application SHA to d4b1825bd5645f4949e4b57e48a73022c3b7cba1 |
| Scripts/CI/hq-stage2-focused-apple.inputs.json | Only application_source_sha and the corresponding original application tree hashes |
| Scripts/CI/verify-hanlin-live12-source.py | New read-only exact-source admission |
| .github/workflows/otzaria-hanlin-live-native.yml | Only the source-admission step label and script path change from Live11 to Live12 |
| This packet | Source bindings, actual execution-input inventory, prior evidence boundary and exact workflow delta |

The existing workflow remains workflow_dispatch only. Its runner, step order, deadlines, original native selector, build tools, original model, credential handling, cleanup and artifact allowlist are unchanged. WORKFLOW_ONLY.patch records the only two changed workflow lines.

No Source, Vendor, project or original UI-test bytes change after d4. Application source identity is separate from the future complete CI checkout identity.

## Admission guarantees

The new guard hard-binds the actual failed Live11 source, reviewed d4 application, original Hanlin SDK and historical no-send/Live10 lineage. It verifies:

- Exact d4 Source bytes/tree and unchanged Vendor, project and UI-test trees.
- The one reviewed diagnostic Source-file delta from Live11 and the accepted historical no-send lineage.
- All nine inherited diagnostic evidence files, the exact inverse proof, and the original five-control result without replay.
- The exact single REVIEWED_SOURCE replacement and original driver behavior outside the reviewed enum/source constants.
- The exact two application source/tree build-input updates.
- The exact manual-only Live11-to-Live12 workflow source-admission step.
- The complete 19-path change allowlist from the failed Live11 source, including the inherited diagnostic documents.
- All283 actual execution-input files that the unchanged source_context function independently hashes before and after real native execution. The new guard, rebound driver, inputs and changed workflow are included.
- Honest previous FAIL and future NOT_RUN evidence boundaries.

LIVE12_EXECUTION_INPUTS.json is based on real staged blob identities and actual file bytes. It is not a list of asserted compiler outputs. The admission checks every inventory path against the actual committed checkout and the actual worktree bytes. No build or binary is inferred.

A local source admission must run on the complete prepared tree, including the reviewed workflow delta. A source-only publication parent, if used for coordinator publication, is not an executable Live12 tree until the exact API workflow tree is installed and reverified.

## Historical no-send evidence

Accepted native no-send run45041601629 at6591bba49d2b5a28d02b763c4360406843fce4cf is retained as historical evidence. Its unchanged product/test lineage matches Live10; only reviewed diagnostic additions distinguish the new Source tree. The new full Source tree is different. No new no-send runtime, live provider success, genuine Host receipt or consent-revocation acceptance is claimed from the earlier result.

## Handoff

Root reviews the exact prepared commit/tree and API publication packet before any branch publication handback. The packet supplies the admission path, SHA256 and Git blob plus the exact workflow content/hash/blob and expected final tree. After final publication the coordinator must bind its lifecycle controller to the actual remote full SHA, reverify admission, and retain the existing exclusive credential and watcher ownership.

Remaining runtime gate: actual original native test success at the final source, including genuine tools, Host-created source receipt, source return and consent revocation. Source admission alone does not close that gate.
