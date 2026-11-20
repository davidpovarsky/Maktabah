# Prepared final Native116 and Release114 push routes

This is a local, unactivated CI proposal based on the original workflow and handoff at `e603d8182a1c10c4b37b14c92b5f0bc3829edea8`. No final application commit (M), frozen checkout (F), branch, or run was chosen or created. `runtime27-final-push.inputs.json` deliberately contains `UNFINALIZED` and null application/tree/four-pin values; the new admission helper rejects that state.

## Scope and original execution

There are two separate exact push branches:

| Mode | Exact branch | Original jobs and limits |
| --- | --- | --- |
| Native | `codex/otzaria-final-native116-20261120` | Original `runtime27`, 360 minutes |
| Release | `codex/otzaria-final-release114-20261120` | Original build/prototype → native matrix → production upgrade, 210/345/300 minutes |

Both workflows require the original repository, exact push event/ref and current `github.sha`. They have read-only contents/actions permissions and do not cancel an earlier running job. Release's three jobs remain in one workflow run and attempt: the original same-run product/receipt protocol cannot be satisfied by independently dispatched producer and consumer runs.

Every original selected job step, step ID, `needs`, output, shell/Python command, dependency preparation, cache policy, artifact name/path and always-upload condition is retained. The only substitutions inside those original jobs replace manual inputs with the fixed mode, actual workflow SHA, and the original inactive values for unrelated modes. Two source guards are inserted around the original executor per job. The original manual workflow itself is not changed.

The original `runtime27.py`, Release runners and complete `verify-faithful-xctest.py` declaration parser remain responsible for their real source, SDK, declaration, build, fixture, result, HID and zero-skips gates. This proposal changes neither the selected Native116/Release114+2 rows nor the original 600-second individual test budget. No Python declaration approximation replaces the original Swift parser. No build products are invented, rewritten or substituted.

## Additional Release authority case

The original manual context body is retained as `_manual_context`, with its values unchanged. The original `workflow_dispatch`/manual-workflow API predicate remains byte-identical after indentation. Original archive, receipt, artifact digest/size/expiry/repository, unique-successful-producer, run/head/attempt and producer-upload-time checks still execute.

Only the additional Release push workflow can use the new path. Its local context must match the exact event, repository name/ID, workflow/ref, actual SHA/run/attempt, finalized application trees and four original pins. The real GitHub run GET response must independently match the exact push event, workflow path, branch, repository and head-repository identities, run/attempt and head. A manual event cannot borrow the new case; a push event cannot borrow the original manual case. The artifact and producer checks are shared unchanged. The import proof additionally retains the actual API branch and repository identities for this new case, without asserting final Release acceptance.

The before/after source receipts bind the complete tracked runtime helper/test closure, both push workflows, the original manual workflow, the original complete declaration helper, all four pins and the application trees. A separate explicit `reviewed_r27_sha256` must match the actual R27 file; reversing its single quoted digest literal in `runtime27.py` must reproduce the complete original Git blob `41268a7e701d9962c6e4ea3cf54764bb9213c3f4`. Other driver logic changes or a second digest occurrence fail closed. Untracked disposable outputs do not become source evidence. The handoff also carries that source binding across its original same-run stages.

## Actual local verification

The final sealed run executed **41 new controls and all 29 unchanged original handoff controls: 70/70 passed**. Exact method inventories, return codes, commands, raw stdout/stderr and before/after input hashes are retained; no input changed. New controls use real temporary Git commits, committed and dirty files, ZIP/tar bytes, hashes, extraction and POSIX permissions. The GitHub API and Apple tool observations in component fixtures are explicit synthetic boundaries. They cover wrong event/path/ref/repository, mixed run/attempt/head/artifact/producer, malformed context, actual guard CLI before/after failures, unfinalized admission, complete original step preservation, and the fifth exact single-digest driver edit.

The 29 original fixture bytes are unchanged from Git blob `d94cd67e4ae134624e6ae4580538b5347463b4d2`, and execute against the candidate handoff module. The initial generator attempt's `KeyError: 'json'` is retained separately: a broad input substitution encountered a filename before producing a workflow. It was corrected to substitute only GitHub expressions; a control proves original shell/Python command bodies remain identical. Earlier successful smaller control runs, including the 63-case first seal, are retained but are not added to the final 70-case total.

C's independent read-only review found no concrete blocker in the five-hunk handoff delta, guard or derived workflows. This was a source review, without execution by C.

**Apple workflow execution, Swift declaration parsing, app/UI compilation, Simulator execution, HID and Native/Release acceptance are NOT_RUN for this proposal.** The original 116 Native and 114 UI plus 2 prototype obligations remain required. The draft is not published or activated.

## Finalization by Root after application integration

1. Choose the final reviewed application/test commit M after the remaining Core/annotation source integration. Use the original freeze preparation to update the four original pin files listed in the binding, preserving every selected case, group, oracle, source/dependency identity and timeout.
2. Make the **fifth freeze edit**: replace only the existing quoted R27 test digest in `runtime27.py`, preserving a complete single-value inverse. The reviewed e603 runner still contains `53f9db5b97784b9003eacf1bafc69e51bb64dd0580e426f0d8a17d32f4d9de9b`; e603's actual updated R27 source is `97d33e24844ea293a004d88379b95e5f534df123b58f76df1f0b6d4de059508f`. A later reviewed R27 source change must use its actual canonical digest; no other driver change is admitted by this proposal.
3. Fill the new binding with the explicit M, its four exact Git tree IDs, SHA256 of the four final original pin files, and the explicit reviewed R27 digest, then change the state to `FINALIZED`. Do not replace nulls with the intermediate e603 identity merely to pass the guard. Review the final changes and retain the original real Apple preflight/declaration execution.
4. Create the final immutable checkout F containing those pins and reviewed CI changes. Both exact branches may reference that same F; each workflow admits only its own branch. Root alone creates/activates those refs after source review. No workflow-dispatch API or automatic retry is added here.
5. Verify the actual GitHub run's branch/head/event/attempt before monitoring. Preserve source-specific raw results and all original failure uploads; no earlier source's PASS transfers to F.

`WORKFLOW_PRESERVATION.json`, `HANDOFF_INVERSE.json`, the sealed raw controls, original sources, preparation scripts and `PACKET_INDEX.json` provide the reviewable provenance. Only five runtime payloads are proposed: two additive workflows, one additive guard, one unfinalized binding, and the narrowly extended original handoff helper.

## V2 — keep the original focused-driver three-tree contract

Root's source review found that v1 incorrectly required the focused Apple input to contain all four application/test trees. The original `runtime27-release-stages.py` complete `expected_build_report()` instead requires exactly `Source`, `Vendor` and `Maktabah.xcodeproj`; its `pack_build()` invokes that gate. The original focused driver emits its input mapping into the build result. Adding the test tree would therefore reject the real build handoff.

V2 changes only the new guard predicate for that input to the exact original three-tree mapping. The new final binding and its checks against both M and HEAD still require all four trees, including `Maktabah-iOSUITests`. No original stage, focused driver, workflow, manifest or handoff behavior changed. `V2_FOCUSED_SCHEMA_INVERSE.json` and its patch prove the exact whole-file inverse.

Four new controls use the complete original stage module and real temporary Git/files. The original stage admits the three-tree build report and rejects a fourth tree. Against the old v1 guard, the corresponding new guard controls produce one ValueError and one missing-exception failure: **4 executed, 2 passed, 1 failed, 1 errored**. The repaired candidate passes those controls together with the prior37 and unchanged29 handoff methods: **70/70**. The stage's already-observed platform/runner context is explicitly doubled; no Apple build or artifact handoff occurred in this local test.

The complete previous51-payload packet, its index and all66-control evidence remain byte-for-byte in `raw/PREVIOUS_V1_PACKET.tar.gz`; its original folder also remains unchanged. The former fixture's synthetic four-tree focused input is recorded as the coverage error that allowed the mismatch. Historical successful controls remain valid for their exercised inputs and do not prove the corrected production schema. Final M/F and activation remain unselected.
