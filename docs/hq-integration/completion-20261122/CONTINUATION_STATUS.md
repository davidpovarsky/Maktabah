# Otzaria / Maktabah — current development checkpoint

Snapshot: 2026-11-22T04:22:58.713322+00:00.

This report records executed work and its limits. It does not declare product, full Native, Release or original-editor acceptance.

## Current integrated application

The canonical branch is [codex/otzaria-completion-20261122](https://github.com/davidpovarsky/Maktabah/tree/codex/otzaria-completion-20261122). Its current integrated application source is [67518e8df6975c976e8f1cd9e622328dc45985fc](https://github.com/davidpovarsky/Maktabah/commit/67518e8df6975c976e8f1cd9e622328dc45985fc); source-binding metadata is577ea1472da2e127a7068046e6b8c3e40293b98b. This adds the independently reviewed durable native-creation fence to the earlier application385ee84a. It is not the frozen input of the still-separate Native4 run.

| Product tree | Exact Git tree |
|---|---|
| Source | ac887bdbfbfce2d30d9591bb867d61b11da31cc6 |
| Vendor | 4065c0e62af325e83a65fe0c70270985229807ae |
| Maktabah.xcodeproj | 8c0fa1ccfbcfae01fae3c267512864e00efcf078 |
| Maktabah-iOSUITests | cd108ec2cec9f8c6089a1eeff2ec77bc9372a469 |

[Current integration proof](native-fence-integration/INTEGRATION.json) verifies the exact two-parent merge, the sole product-file delta, all107 indexed evidence payloads,42 compiled inputs and current trees. Ordinary HQ, future original-editor Native and future Hanlin Live bindings target67518. The original ordinary source-only preflight passed once on metadata577ea in7.5seconds, with no downloads/build/tests. [Raw preflight](native-fence-integration/preflight/RUN.json) records that invocation. Its native Windows CRLF stdout was retained byte-for-byte; correcting Git evidence attributes did not rerun the validation.

The historical [four-case source freeze](native-four-application-freeze/APPLICATION_FREEZE.json) remains application385ee84a8acb3fbc3c013c0977417b61fd3d8a17, metadata46a18524. Actual [run44980625976](https://github.com/davidpovarsky/Maktabah/actions/runs/44980625976), attempt1/push at03:26:17 UTC, uses frozen wrapperc107c8ac. Its original app and UI-runner builds, exact Host48 reuse and HID preparation passed; actual four-case Native execution started. No final case outcome is yet credited. The sole observer is job_d3c08232bc6c. The three previously passed selectors are excluded, and no provider key, Connect or Send is supplied. [Wrapper evidence](../native-four-20261122/) retains the original275-input preflight and Windows encoding correction.

Those four selectors are outside Native116. The two Search cases also occur in Release114 in both iPad configurations; focused results cannot replace its exact five-configuration aggregate. Full Native116/Release114 manifests remain pending the final qualified source. Their counts, ordering, real-execution requirements and24-hour Release freshness have not been weakened.

Original-editor distribution integration, device/runtime work and later verified corrections may require another application freeze.

## Requested runs and temporary secret cleanup

| Run | Actual result | What the evidence establishes |
|---|---|---|
| [Native 44969361774](https://github.com/davidpovarsky/Maktabah/actions/runs/44969361774) | FAILURE, 22 November 02:36:42 UTC | Original app and UI runner built. Six Native cases executed: three PASS, three FAIL, no skipped or missing cases. |
| [Hanlin Live 44969637013](https://github.com/davidpovarsky/Maktabah/actions/runs/44969637013) | FAILURE, 01:40:07 UTC | The exact locator assertion failed before consent, Connect or provider execution: source line523 versus canonical paragraph start522. |
| [Hanlin Live6 44974028362](https://github.com/davidpovarsky/Maktabah/actions/runs/44974028362) | FAILURE, 02:47:08 UTC | Original app/UI build and corrected exact locator assertion passed. The consent switch remained0 after a native tap at HanlinConsumerAcceptanceTests.swift:469. Connect and provider completion were not reached. |

Both Live attempts completed zero verified provider conversations. They remain separate historical failures.

The temporary OTZARIA_LIVE_GEMINI_API_KEY was deleted after each relevant run, with exact metadata matching and an absence check:

| Secret instance | DELETE | Subsequent GET | Verified time |
|---|---:|---:|---|
| Original run, created01:03:09Z | 204 | 404 | 01:40:14.523327 UTC |
| Live6, created=updated02:00:10Z | 204 | 404 | 02:47:33.815508 UTC |

Receipts: [original cleanup](hanlin-live5-paragraph/secret-cleanup-44969637013.json) and [Live6 cleanup](hanlin-live6-consent/secret-cleanup-44974028362.json). Both lifecycle owners are terminal. No further cleanup or duplicate Live observer is required. The next focused Native route supplies no provider credential.

The Live6 artifact14735424221 was downloaded once, verified at83,455 bytes, SHA256 aac873daf6657ef014ed1c1b3db48a44162d240e95408ef39df846fbfac8e880, and passed ZIP CRC. All21 admitted files match their original size/SHA256 records; source-before and source-after are byte-identical. [Retained Live6 evidence](hanlin-live6-consent/README.md) preserves the failure and its scope. Private provider input, raw xcresult attachments and video were excluded by the original policy.

## Native findings, repairs and next execution

The three passing original cases are ReduceMotion, pointer plus hardware Escape, and HIDComparison including the narrow-window Inspector journey. They are retained and excluded from the next focused selection.

The two Search failures occurred only in restored initial-Search comparisons. Original AX and images show the TabView container beginning at different heights while native tab buttons remain at the same position. Both original and candidate branches can enter the early-restoration mismatch. Code f5d53f3928e8a2319de19373103dcbe3f3153e3c initializes the canonical, available saved destination and its existing navigation manager before the first TabView mount. It preserves the original onAppear/session behavior and changes no offsets, geometry assertions or tolerances. Eighteen new portable restoration controls and full-file Swift syntax passed; UIKit behavior is awaiting the actual rerun.

The keyboard calibration failure was an incorrect identity comparison. Verified before/after AX shows selection moving from RECENT בראשית at y238.5 to the separate main ספרים בראשית row at y314.0. The test compared equal display labels. Code a43aa9d8a658d5afbadc66edaa3c109a28edcad8 exposes the existing original item.id as an accessibility identifier. The test now requires unique real row identities, the exact first selection, the exact next row after DownArrow and the original row after UpArrow. Key dispatch, selection logic, Escape/HID routes and timeouts are unchanged. Both complete Swift files passed syntax and an independent review; no Native PASS is inferred.

Code18ed08f80c0c6760e8003a70733637945192f8c9 adds the actual original Reader/Chat consent interaction without a key, Connect or Send. It records native AX/screens before and after one switch tap, waits for the actual ON value, taps OFF, closes and verifies the exact original book text, locator and workspace owner. This makes the Live6 failure observable without collecting private provider input. It is a new diagnostic, not a substitute for live-provider or saved-conversation acceptance.

The original Native evidence ZIP14735253756 was verified at20,480,209 bytes, SHA256228e3fd02e3063afbc3cb8a59cc3d85907219399c48ab7fb870a1ff1585971a6. The full captures ZIP14736147772 was verified at433,737,125 bytes, SHA25697e5a1de4128a282d631abe104fa273ad77b5b1ba010e6fbc84ef47290c0252d, with all3015 ZIP entries CRC-checked. The17 priority entries match the fully verified archive byte-for-byte. [Native raw evidence and controls](../native-followup-20261122/) and [integration proof](native-current-integration/MERGE_PROOF.json) preserve both successful and failed outcomes.

## Repository identity and shared Cloud worker

The original Repository defect was reproduced with the actual Repository, Annotation, SQLite and SyncPendingStore. Six defective cases failed in the original writer and separate reopen process; three valid controls passed. Code5d0a11f6a799bee9deb23dc91b29e832bec14335 persists backend locator/context for same-UUID imports and prevents UUID-less positional fallback from adopting another backend/work/position or malformed locator. Schema, timestamps and original pending-upload/delete records were preserved.

[Apple run44977823319](https://github.com/davidpovarsky/Maktabah/actions/runs/44977823319) completed SUCCESS on checkout385fffafb5b014f0777b3100151b5b6d0e75eed9, application5d0a11f6:

- Original Cloud48:48/48.
- Actual original Repository imports:9/9.
- Distinct-process SQLite reopen:9/9, process IDs19651 and19652.
- Apple Swift6.4.2, SQLite3.54.0 and original OSLog.
- All93 source inputs unchanged during execution.

The raw artifact14736950047,656,371 bytes, SHA25657d265b96541376c07c683a099b3888518d23163a508d604facf7b18a65c8844, was verified against GitHub metadata and locally CRC-checked. It was independently verified again from its exact Git blob before merging. [Full original Apple evidence](cloud-import-identity/apple-44977823319/) is integrated through mergeae9790022b5f1c07157781d07fba6df239594a55. These are component results; live CloudKit transport, Anytype and Native UI were not executed by that route.

The earlier HTTP worker correctioneaa971f9 retained16 passing Foundation response/error controls. The original Core termination flush had the same false-success pattern: a rejected HTTP response with no transport error was logged as successful. Code5f862ea7d785de813fc28680cfe403a3e082ba22 reuses the exact pure classifier and moves its single declaration into the existing shared Core file. Its callback writes a typed failure into the original Mutex and signals the same semaphore once. The three-second wait, pending queue, ACK, cancellation and retry behavior are unchanged.

Four new exact-callback controls reproduced the original HTTP503 false success and verified accepted204, rejected HTTP, missing response and original transport-error identity. The prior16 cases were not rerun. All three original application targets and the original local/cloud acceptance closures include the shared declaration. [Core evidence](core-worker-termination/README.md) retains source relocation, target membership, original receipts and the270-input source preflight.

The original Apple import9 compiled closure is unchanged across the Core correction and remains reusable. The Cloud48 run remains an actual result for application5d; it is not claimed to have executed the later Core changes. Actual original app/UI-runner compilation has now passed in Native4 on application385ee; this does not compile or execute the newly added ledger in67518 on Apple.

## Original Anytype producer

The original51-pin graph has real Apple resolution evidence. Strict-only run44975218662 passed on the original locked graph, without repeating the prior successful unrestricted resolution. The original44 records were retained and seven manifest-proven Hanlin transitive dependencies added; no fictitious originHash was introduced.

Producer44976039281 onfc03 passed source controls, original Hanlin, Heart and toolchain checks, then failed at ComputeTargetDependencyGraph before Swift compilation because Xcode required authorization for EquatableMacros. The correction authorizes only the reviewed Equatable1.4.1 package/revision/target and restores the prior macro trust bytes. It does not disable macro validation globally.

Producer [44978502186](https://github.com/davidpovarsky/anytype-swift/actions/runs/44978502186), frozen atcb2df9baa201db0ce404ba37eac853424bae6204, finished FAILURE. Its genuine framework step failed at03:12:36 UTC and its job completed03:12:45 UTC; the sole observerjob_f81168b93de0 ended03:13:20. Scoped Equatable approval, actual macro compilation/link/sign, and exact trust-store restoration passed. Artifact14737027101,1,088,166 bytes, SHA256ee74d656be583028f8891a102197e06378bbd59bcdc282a63afc756400b8b7f0 preserves the actual Services compiler errors.

Both original Services repairs were reviewed in full. PublishingService preserves the caught Swift.Error existential and its existing null-error policy. TemplatesService resolves the actual referenced type through strict original ObjectShow under the existing task-local Owner: exact root, exactly one returned row, exact ID and Space. Each original RPC obtains a fresh permit; no new Owner, passive-parent reentry or weakened restriction is introduced. The original app-only predicates are replaced by the original available module values.

The completed peer property16 source388a3726/evidence06b639ff was independently reviewed against cb2: all16 preimages/outputs,80 evidence payloads,14 actual new controls and the13 intended production control inputs verified without rerunning the controls. Services commitb5b4869660415cbc5f273141162482a32f68f9fd and exact peer source cherry-pickfcdff77b3e75dd0b38cb939d15affd68cf43c180 are composed together; peer evidence is retained at2b39d5e3f0161b1a8a0b8724b43a8f5f464592fc.

Producera5fffd7f0ead01b3086019f4c1bef7c01f3a699d / [run44982412759](https://github.com/davidpovarsky/anytype-swift/actions/runs/44982412759) failed the actual Xcode framework build with exit65 at04:00:16 UTC, before framework success, export, consumer or runtime execution. The two reported diagnostics are ObjectSettingsViewModel.swift:399/408, where nil-tested generic multi-statement callbacks require explicit Void return inference. Earlier Publishing/Templates diagnostics are absent from this actual compile log. Artifact14738955400 was downloaded once at1,278,926 bytes, SHA25636a8977310cfa3cb1e88b754dbc3aeaef7b6813b33013e94e9a9d4fb5cfc3dee; all38 ZIP members passed CRC. Source-before/after are identical,221 source controls passed, and macro trust restoration passed.

The exact two-line repair was fully reviewed and passed syntax plus four bounded extracted inference outcomes. It changes no callback body, ordering or ownership check. Sourcee084ccaa54e516cebc83821b5d576976f0be9b5a is sealed as553d4ae90eb8fb0ec21b5ecc319b43db40d2dba2. Actual [run44983797493](https://github.com/davidpovarsky/anytype-swift/actions/runs/44983797493), attempt1, began04:09:33 UTC and was independently verified IN_PROGRESS on that exact SHA. The sole observer is job_3e7ae6631939; the a5 observer is terminal. The original2252 source count,49 execution inputs,51 package pins, resources and facades are retained. No qualified framework or binary-consumer result is yet credited.

A separate reviewed six-callback type annotation patch remains unapplied to that frozen producer. It also repairs an actual nil-session legacy action suppression reproduced with exact generic semantics. It will enter the next controlled source composition; no passing original ownership suite is rerun for unchanged inputs.

Ordinary HQ keeps optional original-editor admission and canImport guarding. An UNFINALIZED producer blocks dedicated StageB, not every ordinary app build. StageB still requires the genuine qualified original distribution and actual native two-block save/reopen evidence. Source-only and portable controls are not editor runtime acceptance.

The new production annotation work is isolated from the frozen producer. Exact original Heart source shows that creation and indexing can diverge; a zero-result index query cannot prove no object was created. The reviewed direction preserves an uncertain create intent and permits recovery only through a positively verified original native identity. It does not issue a second create or ACK after an uncertain outcome. Dedicated annotation classification, stable destination identity, visibility and original-service integration remain unfinished.

The peer continuation owns the property-modal source chain. Its files and frozen producer are not being modified by competing writers.

Current original-editor consumer mount/qualification/source-observation files are DEBUG, iOS and Simulator guarded; StageB admission requires arm64 IOSSIMULATOR products. Ordinary device and TestFlight workflows do not yet restore/admit this distribution. A future StageB PASS therefore qualifies the scoped original-editor Simulator path only. Genuine device products, original production account/runtime bootstrap and device embedding remain separate requirements; those guards stay in place.

The original synchronous Owner admission/drain ordering is retained for the future receipt seam. A new consumption must be admitted after the real SQLite lock is acquired, with the exact pending/source witness rechecked inside a top-level transaction. Already-admitted work may finish while retirement drains it; this is not instantaneous revocation. A COMMIT followed by retirement/postvalidation failure must be reported as durable-without-current-publication, never rollback or permission to recreate. No public receipt/writer exists until actual Owner+SQLite races, native schema and original readback establish this boundary. The local fence does not guarantee global uniqueness between two independent first writers.

## Retained dependency evidence

The peer's [M17 run44976915323](https://github.com/davidpovarsky/anytype-swift/actions/runs/44976915323) passed one original strict CocoaPods-workspace resolution for Maktabah813fbe79c1b325ee21a8c2be78bb86577f44bf6c. All17 pins/checkouts,268 prepared workspace inputs and424 original Hanlin records were preserved. There was no automatic resolver or second strict invocation. Evidence commit538b2c9ca153c81a593faa08fab3b6a080d428e8 is retained by the peer.

The requested exact reuse comparison for application385ee/execution metadata46a is now verified and published in9ced75da7726b55668f1341a1ff5a241a65abc4a. Root independently checked23 actual Git input comparisons, the7 unchanged PBX package/owner/build sections, all17 pins and the4 original preparation functions. The project difference is exactly8 added source-registration lines. The complete26-member peer packet contains25 verified payloads; ZIP SHA2569bd73752aaf5bd1587d98a57053f4b48c5281356cb68c227203b737d206b167b, CRC PASS. [Reuse report](m17-reuse-385ee/README.md) and [root admission](m17-reuse-385ee/ROOT_REVIEW.json) preserve exact scope. No resolver, compiler or test was rerun. The historical strict17-package resolution is reusable; the historical268-file generated workspace stamp is not transferred. Current Pods/workspace/privacy/provider preparation and actual build gates remain required.

Historical Core194, Host48, Store11, Foundation55 and full-v32 results remain limited to their proved unchanged dependency closures. A successful component does not accept the current full application. Passed tests are rerun only for a concrete changed dependency or a required final gate.

## Current dev history integration

True merge031e3cfde4bd072c7e6f6a8ecc6d0a364b4af219 joins completion9ced75da7726b55668f1341a1ff5a241a65abc4a and the freshly verified dev9859c754545aed8c34b311b63490778a51db5d7e. Proof commit879d1e0e5148bb1ce9d93512746b510a622affe6 is its direct child. All11 conflicts were resolved after an independent full three-way review. All18 existing dev-touched files retain their exact current completion bytes; current workflows already include dev's notification changes. The sole effective addition is dev's original54-line Live Activity Bridge workflow,1,923 bytes/SHA256427678d3ae83c659912b2b009d0c8a5aed72027e6fd9f35ce300370a1690f4f6.

Independent post-merge review verified both actual parents, all18 retained blobs, all4 product trees, every receipt payload, and unchanged owner verifier/baseline, TestFlight/UI-before-signing and release gates. The removed old inline release upload was not restored. [Actual merge proof](dev-history-integration/INTEGRATION.json) records source-preserving integration. No component, resolver or Native suite was rerun for this history/CI-only change.

## Durable native-creation fence work

Sourcee78ddef1cd156bd2118e1ed23eb56376e65d0a7c and evidence0cdb968f2c1330e7235c22304ca982b532a78a60 are integrated by true merge67518e8df6975c976e8f1cd9e622328dc45985fc. Only AnnotationExchangeLedger.swift changes in the product:326 appended lines, with the original33,283-byte prefix unchanged. The three native tables require explicit opt-in installation and preserve original v1 tables, PRAGMA user_version, startup behavior and existing ACK.

The uncertainty transition rejects an enclosing transaction and holds the original SQLite connection lock through the true outermost COMMIT. A released SAVEPOINT cannot establish durability. The actual UUID-case RED showed that a lower-case stored uncertain row could otherwise hide from the next revision. Three UUID-only NOCASE predicates and strict canonical decoding now refuse noncanonical or colliding rows; destination/account/Space/namespace/native IDs remain case-sensitive. No stored row is repaired or adopted silently.

The final ledger SHA256 is26dc7075df6d73f9dc9c5d2cc46547d9496d71c96469fe8adf3a4e779d9b53cc. On Windows Swift6.3.3/SQLite3.53.4,19 affected/new controls passed and5 unchanged schema controls are reused exactly:24 distinct new-component cases covered. Three real abrupt exit73/distinct-process reopen pairs passed on the final source. Exact payloads, source rows and CloudKit queue were preserved. The original compiler timeout,18-case earlier result, UUID RED and final GREEN all remain in [component evidence](native-creation-fence/README.md). No historical28/Core194 suite was rerun.

Root and an independent reviewer read the full additive source and original SQLite/ledger dependencies. All107 indexed evidence payloads and42 compiled inputs match actual incoming Git blobs. [Merge proof](native-fence-integration/INTEGRATION.json) and [source-only admission](native-fence-integration/preflight/RUN.json) preserve the composed source. No production identity writer, native RPC, body application, transport, ACK hook or startup call is enabled.

A separate Apple route is being prepared with all24 unchanged assertions and the existing actual Apple SQLite3/CryptoKit/_exit path. It has not been dispatched or credited. Windows persistence results do not establish Apple/native authority or application acceptance.

The isolated SDK policy files511c648c/12beaebc passed52 pure controls and were published at53392efc0010ac0c75b9c104b51bc144b545eb5e. They separate identity recovery from body application, alias durable attempt identity to the existing messageID, and never confer authority through a DTO or caller boolean. Original native schema, held account/Space/Owner capability, body readback and actual joint commit-boundary controls remain necessary before production wiring.

## Signing and remaining external requirements

Mandatory authentic owner approval before TestFlight signing/upload was integrated through mergef802143e. It uses immutable verifier source978db8b3 and SHA2569733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676, exact candidate/source coverage and the original policy baseline031df357. The actual audit atf802 refused50 protected paths with zero verified approvals; [raw gate evidence](owner-gate-f802/) remains unchanged.

The coupled-policy diagnostic applies to unapproved violating paths. Valid authentic approval of all protected paths removes those entries; it does not require inventing a new baseline. The last authority check found no external owner verification key or authentic signatures. Operational development authorization is not a fabricated cryptographic signature. The final full-index owner package must be regenerated after the final source is established, including the later protected Core change.

Other requirements remain open:

- Full Native116 and fresh Release114 UI plus2 independent oracles on one qualified final source/build; the24-hour Release evidence limit remains.
- Actual original-editor StageB and classification,100/1000/5000 behavior, durable outbound delivery and separately verified bidirectional conflicts.
- Native RTL/LTR, VoiceOver, lifecycle, multiwindow and physical-iPad acceptance where required by each task.
- Books Updates provider contract: the last verified feed lacked authoritative backend/schema/source-hash/migration fields; the original refusal remains.
- Physical execution: the last verified host inventory exposed no usable Apple mobile-device bridge. Actual owner iPad QA follows a valid internal TestFlight build; it is not a circular pre-upload gate.

## Asana acceptance and coordination

[Handoff1220763167870295](https://app.asana.com/0/0/1220763167870295/f) is an administrative delivery record, not product completion.

[TEAM1219611682682931](https://app.asana.com/0/0/1219611682682931/f) was completed after all six reviewed documentation fixes and26 evidence files were integrated by true merge5f019f29486dbe53b4b48f0773119079e536fec5, exact payload/product-tree checks, publication and read-back. Existing76 documentation checks and original ensure-team were reused. The review was technically delegated under the current explicit authorization; no personal owner reading of old PR3 is asserted.

The last task inventory has49 top-level tasks:31 open and18 completed. No additional task met its actual complete definition of done. Core/API still require real client/native/live-consent evidence; ReaderHistory explicitly needs physical iPad; research-only scope was superseded by implementation acceptance. Those tasks remain open.

Canonical continuation context: sxc_NCA3K3YC. Peer context: sxc_WAXQV0PW. Each run has one designated observer. Dirty legacy worktrees, original databases, failed runs and earlier raw evidence are preserved.
