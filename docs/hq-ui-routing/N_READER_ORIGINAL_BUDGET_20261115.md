# N original-budget and full native-receipt consumer boundary

Separate inactive future consumer follow-up to Nbdd1169a and immutable Pab99518f. R exclusively owns real Store/adapter/native mapping producer work. N has not written those files, connected its observer, enabled v2/content/newTab, added a reservation or changed the current URL/Intent handler. The terminal frozen run43736843778 was not polled/retried/restarted. App deployment alignment remains manager-owned.

## Original budget and original owner

`NativeSceneNavigationOrchestrator.executeReaderPlan` delegates exactly once to its existing canonical Core actor. It does not install a sink/renderer/resolver. Its actual configured sink must retain the EXACT UIValidatedRoute from P and use Core's independently issued invocation/content grant. The caller continues to own the original admission/subscription through the whole result and final scope-return checks; this method does not release or re-admit it.

The original absolute deadline encloses the entire Core call in the existing cooperative `NativeObservationDeadline` scope. Just before execution, `NativeReaderPlanBudget` projects only the remaining whole milliseconds, rounded DOWN, into the existing ActionRequest. Bounds come from **Core's bundled request schema**, currently100–60000ms, rather than a copied timeout/permission policy. Below Core's minimum, or after expiry, the consumer refuses before any Core invocation; it never rounds up/restarts the original deadline. Request UUID, expected backend/generation and canonical reader destination are retained. No new wire/public DTO field is added.

Original native authority/context/lifetime/revision and the SAME synchronous backend snapshot are checked before execution and after a successful full Core result, including after structured-scope cleanup returns. A late owner change cannot escape that final actor/cleanup boundary as completed. Core's structured noncompletion results remain Core results; outer failures after Core starts conservatively report `native_effect_uncertain`, with no rollback/retry claim. Existing Core worker/cooperative-port limits remain; no hard interruption or second semantic executor is claimed.

The exact Core-issued sink deadline in a manual-clock positive test is2,999,000,001ns for original3,000,000,000ns after the clock advances to2,500,000,001ns:499ms remain after rounding. The original admission remains held through completion on all three synthetic backends. Separate tests prove too-small/expired budgets start no Core backend read, schema cap/minimum handling, owner replacement before dispatch and revocation during outer timer cleanup after the Core operation returns.

## Full native completion and finite admission

An independent adversarial check found two omissions in the first local candidate, before it was committed: canonical Core's legitimate idempotent cache could return an earlier completed result on a repeated plan, and an alternate sink could consume/ACK the semantic reader grant without N's exact private-route witness. **Two methods / three expected assertion failures** are retained in `N-reader-result-boundary-before.log`. This identifies a consumer requirement, not a Core-cache defect or native/device result.

The corrected consumer:

* Refuses a previously attempted native request before calling Core, instead of recycling its old UI acknowledgement.
* Allows only one active reader execution per actual scene, bounded by the16 registered native drivers, and checks the existing finite dispatch ledger capacity before semantic work. Active-call tokens are process flow control, not tab reservations or permission authority. Old unregister/cleanup cannot remove a replacement call's token.
* Returns completed only when its own existing bounded native ledger records the EXACT retained validated route/context as fully acknowledged and inactive. The acknowledgement flag is set only after independent full receipt/P completion validation and a final live driver/dispatch-token check. An alternate semantic ACK alone remains uncertain/noncompleted.
* Checks the actual native driver and token after the final synchronous authority read too, so unregistering an owner inside that callback cannot produce an orphaned acknowledgement.

The two regressions then passed; the final suite additionally verifies concurrent scene admission, full-ledger refusal before Core, and driver unregistration inside final authority validation. Tests do not fabricate a new view receipt from a cached ActionResult or reconstruct/revalidate the retained route and discard its private binding guard.

## Actual evidence and remaining native gates

Final N package: **80 distinct XCTest methods / 0 failures / 0 compiler warnings**, strict Windows Swift6.3.3. This is original57, prepared-consumer7, source-observation7 and reader-budget/boundary9. Intermediate5/75/2-red/2-green runs are not added to80. Exact names, working SHA256/Git input identities and raw log hashes: `N-reader-original-budget-report.json`.

These tests run N's actual directory/authority/orchestrator and canonical Core/P code with synthetic native driver/model/clock. They are not real Store wiring, UIKit/Shortcuts, Apple SDK compilation or physical acceptance. New packet Apple/native/physical is NOT_RUN by N. Current frozen build has0PASS/0FAIL/11UI_NOT_RUN from its deployment mismatch; its failure is not retried or relabeled.

Actual producer integration remains pending the immutable R packet and any manager-reviewed real native setter connection. Store-only epoch does not cover live activeTabId/openTabs before persistProjection; global snapshot revision also includes checkpoints and cannot substitute for mapping epoch. N will independently test the actual producer's synchronous invalidation through the same authority/Core final-await path. NewTab/content/native reservation consumption, all relevant actual presentation-source invalidation and public-v2 opt-in remain unsupported/unactivated until their real source seams and acceptance exist.

Changes are confined to N's downstream host package/tests and evidence. P/Core and R producer files, app Integration/current handler, project/manifest/deployment target, Search composition, runners/workflows and signing/release/user data were not changed by this follow-up.
