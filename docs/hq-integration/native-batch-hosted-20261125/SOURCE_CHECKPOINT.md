# Genuine hosted native batch acceptance

This adds a test-only source for the dedicated `Maktabah-iOSNativeTests` target in the real `Maktabah.app` process. The test asserts the actual main bundle is `com.davidpovarsky.chavrusatext`; it uses the unchanged app group and the closed production Anytype SDK. Root owns the target, scheme and exact framework import projection separately.

Status: **source only; actual hosted Apple typing and runtime are pending.** The source requires SDK product `86d738c662c332cec370cee6a09dd434808dbeb9` or a byte-equivalent descendant of its 237-public/22-Debug contract. The SDK source already has its separate actual iOS complete-context typing proof; that does not execute these tests.

## Fixed scenario inventory

1. `test01NativeBatchCapturesFullTextWithoutMountingEditor`: actual no-mounted-editor capture of English/Hebrew/multiline text, the UTF-8 scalar preview boundary and a complete 1 MiB saved-text seed; exact full-text comparison; actual oversize refusal.
2. `test02NativeBatchParentRetirementClosesRetainedCapturedChildAndStops`: retain a real captured child and its live row source, retire only the genuine Host parent lifetime, require the capture/editor boundary to refuse, then complete actual AccountStop without explicitly retiring that child first.
3. `test03NativeBatchRunRetirementDuringPendingChildAdmission`: observe a still-pending real public child operation, retire its original Host run lifetime and require refusal/drain.
4. `test04NativeBatchProfileRetirementDuringPendingChildAdmission`: the same actual admission control using the original Host profile-generation lifetime primitive.
5. `test05NativeBatchCancellationDuringPendingChildAdmission`: actual task cancellation plus the production Host's synchronous retirement boundary, with late completion joined before Stop.
6. `test06FiveThousandOriginalNativeAnnotationsInOnePrivateBatch`: 5,000 distinct original roots in one actual private batch Space/account; exact English/Hebrew full-text/body/provenance checks, long-note samples, refusal of the 5,001st admission, actual AccountStop and three subsequent original rich-body reopens.

The pending controls fail if the operation already completed before retirement. They do not claim that a particular native RPC had dispatched, that a private possible-effect is zero, or that a full Settings profile-switch UI journey occurred. Both parents use the actual `AnnotationLocalEditorLifetime.bindNativeBackfillRetirement` bridge; no fake native owner, replacement engine or journal adoption is introduced.

## Evidence and boundaries

Each executed case writes an isolated nonce directory in the actual host's Documents/OriginalNativeBatchAcceptance. The append-only observation log records actual UUID/account/Space/root identities, capture and text digests, original retained capture directories, timings and progress. The final JSON includes the log SHA-256, actual process/bundle identity, counts, errors, open/capture latency distribution and sampled resident memory. The JSON is also retained as an XCTest attachment. On failure, committed progress and original native evidence remain.

The public fixture source witnesses are explicit test data. This suite creates no canonical Host SQLite rows and gives no ordinary Backfill UI, CloudKit transport or remote-delivery credit. Ordinary production UI/SQLite Save and genuine separate-process network acceptance remain separate gates. No credential, recovery key, original native ZIP body or private key is printed in its evidence.

The 5,000 journey records the actual latency distribution instead of inventing a performance SLA. It must run only after a fresh Mac phase budget and an initial native/no-mount smoke pass. Preserve its source, SDK/native identity, complete actual result and zero-skip XCTest record before claiming the load gate passed.

## Ownership

Only the new downstream test source and this dedicated evidence description are added. Original Maktabah/Anytype production source, existing Native116/Release114+2 test inventories, app identifiers, native journals and account machinery remain unchanged by this commit. The target registration and shared framework projection are separate reviewed root changes.
