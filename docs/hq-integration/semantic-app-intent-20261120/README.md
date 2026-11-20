# Original AppIntent consumer for commentary → unsaved note

## Implemented boundary

The existing `OpenBookAtLocationIntent` now accepts two optional, paired parameters: an explicit commentary book entity and an unsaved note proposal. If both are absent, the original single-reader operation is unchanged. A supplied pair requires the original new-tab route. One missing parameter, a different backend, malformed entity identity, an oversized proposal, a changed source, or a missing commentary fails closed.

This is a production connection through the same `NativeReaderIntentService` instance registered with `AppDependencyManager`. It re-resolves the cached base location and selected commentary through the original Core metadata APIs, requires the same backend snapshot, and then invokes the existing fixed `reader.openCommentary → notes.prepareDraft` journey. No new descriptor, parser, registry, transport, tool or read grant is added. There is no model send or network fixture. The real AppIntents/Siri/Shortcuts UI has not been executed.

The implementation is based on `d78d3750ef429875568253b32410edf22becf55c`. Exact final source hashes are in `SOURCE_INPUTS.json`; source and evidence are committed together. The separate, already running frozen Native/Release references were not edited.

## Ownership and completion

The compound path captures the existing scene registration before foreground activation, rechecks the exact session after activation, and retains the original navigation manager weakly in that registration. It uses the existing navigation/discovery context with `origin: .appIntent`. It never treats catalog metadata or arguments as content-read consent.

Each step still receives its own original Core admission, binding, one-use authorization and visible completion. The Host collects the two actual receipts only after their existing completion checks. A successful aggregate requires the exact two ordered request identities; matching route/request/backend/scene revisions; the new commentary reader destination; the original unsaved note-sheet receipt; equal workspace/profile; and the same commentary locator in both Core results. Replayed, extra, swapped or internally inconsistent receipts cannot complete the journey.

After both awaits, the original scene/session/manager, foreground state, synchronous backend snapshot, authoritative workspace source, public binding, mapping source/epoch/projection, profile/group memberships, locale and every initial tab target are checked again. The newly added commentary tab is permitted; replacing or dropping an original target is not. A failed later note or a revoked final owner retains the first reader result and actual receipts in a typed `CommentaryDraftFailure`; it does not report rollback or complete success.

The existing three metadata reads, Hanlin e004 SDK, content-read grants, Core action inventory, package/project metadata, workflows and all other native destinations are unchanged. The English `LocalizedError` wording follows the original `NativeIntentOutcome` convention; no localization key was invented.

## Executed evidence

| Attempt | Actual outcome | Scope |
| --- | --- | --- |
| Service/Core RED | 35 executed; 33 passed, 2 failed cases, 6 assertion failures | Entire original portable Service/Core/Resolver/Policy with explicit native UI doubles |
| Service/Core GREEN | 35/35 passed | Same 25 new cases and original 10, unchanged assertions |
| Final-source Service/Core | 35/35 passed | Final production input hashes after the public error-contract correction |
| Host attempt 1 | 0 executed | Sparse checkout lacked one 9,467-byte original Core JSON fixture; exact Git bytes restored with matching prior hash |
| Host attempt 2 | 0 executed; compile failed | Complete factory exposed a real cross-module internal-initializer call, plus a fixture-only argument-order error |
| Host attempt 3 | 102 executed; 101 passed, 1 failed | All original 60 passed; one new boundary incorrectly echoed a saved backend snapshot |
| Host attempt 4 | 102/102 passed | Original 60 plus 42 factory/post-await controls; same assertions and final product source |
| iOS-target syntax | 6 parses passed, then 2 final count-setup parses passed | Syntax only on Windows; both cross-target warnings retained for every parse |
| Apple SDK typecheck | **NOT_RUN** | Requires the actual combined Apple build |
| Native UI / Siri or Shortcuts UI | **0 executed / NOT_RUN** | No portable result is credited as Native |

The first actual RED exposed two production defects: a completed metadata step could be described as an opened commentary, and a receipt could have inconsistent internal route identity/revision fields. Both were corrected without changing those tests.

Compiling both complete Host factory bodies exposed the existing call to the internal Core `ActionNavigationError.init`. The correction uses the existing public `ActionNativeUIFailure` contract. Supported failure statuses and known codes are preserved; unknown codes intentionally become `native_ui_failed`, with the original non-retryable sanitized message. Both known-code preservation and unknown-code normalization are executed controls. No Core API or code allowlist was widened.

The one Host runtime failure was a disclosed fixture-boundary error: the original `hanlinSource` reads `backend.currentBackendSnapshot()` on each observation, while the initial double returned a saved snapshot. The double now performs that same live read. The original product guard and test oracle were unchanged. The failed 101/102 result, original member, generated source and correction receipt are retained.

The Host driver inserts the **complete** original `semanticJourneys(manager:)`, `semanticJourneys(owner:manager:)`, `validateReaderIntentJourneyOwner` and existing continuation/advancement members. It links the actual original Core objects from the already verified 174-case Core build and checks every retained Core input hash before use. The original Core suite was not rerun unnecessarily. UIKit/workspace objects and dispatch edges are explicitly marked doubles; their simulated outcomes are not native receipts.

Final logs:

- Service/Core: `8e941cc3a105dbd8effc0d9b953bf9865101edc9d8defceafbff768972b9c9d5`.
- Host runtime: `3fc14b3c8c01836dc789c19b1065720d9d45968cdaa409721b62f7641b11aad5`.

## Existing Native cases now exercise the consumer

The existing two case IDs are retained:

- `NativeRoutingAcceptanceTests/testSemanticCommentaryThenDraftPreservesLocatorAndBaseOnPad`
- `NativeRoutingPhoneAcceptanceTests/testSemanticCommentaryThenDraftPreservesLocatorAndBaseOnPhone`

Their existing DEBUG launch gate retrieves the exact installed production service and calls `NativeReaderIntentService.open`. A temporary read-only observer records the actual aggregate only after the final production owner check. It supplies no authority, view, selection, receipt or alternative note editor.

All previous original-reader, real locator, actual unsaved proposal, visible editor, Cancel, unchanged annotation store, preserved base-tab UUID, distinct requests, same process and actual receipt assertions remain. Six additive assertions identify the production consumer and bind both actual receipt IDs/scenes. The report explicitly says `appIntentsSystemExecution: NOT_RUN`: this is planned service → Core → original UI coverage, not a claim that Siri or Shortcuts UI was exercised.

The count and catalog journey assertions remain intact. Two existing count setup calls now pass `newTab: true` to the original public reader URL helper. The pinned canonical oracle (SHA `51632762100689aa2da6a6d360a6434d4fa4caf5e57971f4ad8e327ab6e173dc`) identifies bootstrap row 3121121 as book 3891/line 523, while both count cases require book 1/line 0. The original same-tab binding requires the same work key. This is a **source-verified setup correction**, not an observed Native failure or pass. The exact two-label inverse restores every preceding byte; count, results, baselines and all remaining assertions are unchanged.

## Reproduction and verification

Reuse the existing verified cache, without a new package or SDK copy:

```text
python tools/hq-reader-intent-compound.py --repo <repo> --cache <existing-core-cache> --output <new-evidence-dir> --swift <swift.exe>

python tools/hq-semantic-journey-host.py --repo <repo> --core-cache <existing-core-cache> --core-evidence <original-core-174-evidence> --output <new-evidence-dir> --swiftc <swiftc.exe>
```

The exact executed commands, tool paths, timestamps, exit codes, source/object hashes and bounded timeouts are in the retained input/result records. Both commands enforce exact case inventories and source stability. The same compiler cache was used throughout.

Verify sealed bytes and results without running any compiler:

```text
python docs/hq-integration/semantic-app-intent-20261120/verify-evidence.py --git-ref <this-commit>
```

`RAW_MANIFEST.json` records compressed and original byte hashes. The initial Git whitespace check stopped on two CRLF JSON files before any commit; canonical Git LF handling is recorded in GIT_TEXT_CANONICALIZATION.json, with parsed values unchanged. Original Windows log/source bytes are preserved in gzip; `SOURCE_INPUTS.json` distinguishes raw working bytes from canonical Git LF bytes. `SEAL.json` binds every deliverable except itself. `PRESERVATION.json` records exact Native inverse, original factory-body inverse except its public failure conversion, original 10/60 tests and protected tree identities.

## Remaining acceptance

Actual Apple AppIntents macro/typechecking and the two existing Native cases must run on the combined frozen source. Native count setup and every unchanged count/catalog/UI oracle remain mandatory. Siri/Shortcuts system UI and physical-device performance are untested. The count → results helper still requires real supplied read authority; this change does not connect or advertise an unconsented count action. No live annotation transport, save hook, Anytype editor, provider, Hanlin SDK or data migration is involved.

Source-only peer reviews by Root and C are recorded as reviews, not execution. Root confirmed the final full factory/body coverage and required the extra ownership controls; C independently reviewed the original receipt/epoch and partial-result path. Their review boundary remains separate from the actual portable and future Native evidence.
