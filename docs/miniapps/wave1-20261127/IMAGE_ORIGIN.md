# Paired MiniApps loaded-image evidence

This CI-only change restores the original producer image observer and applies it to the two actual applications selected by the existing native acceptance runner. It does not change either application's product behavior, replace a runtime, or supply native acceptance evidence before the paired run executes.

## Source and historical evidence

The unchanged original is retained as native_final_image_audit.py.original (12,398 bytes; SHA256 b81ca6bf99098f81c7330065c46a5cad0e2dd6bc47c509a57ceee46d54f5bdc7). It was recovered from member ./native_final_image_audit.py in the retained Oracle archive:

/mnt/development/projects/evidence/otzaria-shared-agent1-20261126/miniapps-86-first-attempt.tar.gz

The archive is 40,949,760 bytes; SHA256 edd4ce5efa007c447d1b3d78782b3ffa5d34619082f94a9409fb7e3487031cb0. IMAGE_ORIGIN_ADAPTATION.patch records the full observer adaptation.

The recovered first-attempt result is **FAIL**, not accepted paired-product evidence: original producer source 86a6dde354947be9329fe1e8f4d45a433fe488c4, original UI selectors 3 passed / 0 failed / 0 skipped, but image-origin **IMAGE_ORIGIN_INCOMPLETE** because one scoped launchctl list timed out after five seconds. Its 33 observations covered all seven referenced PIDs. The image result SHA256 is 234d4c324e86807d3654080071d1834cc5db2ca27719b8a78e07cc37a56d4a22. That historical failure remains a failure. This recovery provides observer provenance only.

## What the adaptation verifies

- Discover the actual app and UI runner PIDs only in the owned simulator's launchd records. The producer bootstrap PID must equal the PID returned by the real simctl launch.
- Admit each built app through the existing miniapps-local-producer.py file inventory. Each observed process must identify the installed bundle's executable in both vmmap and Apple's sample.
- Retain the actual loaded paths, independently sampled Mach-O UUIDs, raw reports and their hashes. Every private loaded image must be an admitted artifact file with identical installed bytes and a matching artifact UUID from dwarfdump.
- Reject unqualified images, wrong process identities, modified binaries, UUID differences and private images missing actual UUID proof. Require the main executable in the installed app and forbid relocated debug images.
- Require the producer's original NativeScript image. Require each app's own debug image whenever it exists in the admitted app.
- Preserve the original generated Xcode targets, runner/native environments and exact UI selectors. The original observer's xctestrun adaptation constrains only the actual UI application's framework lookup to its verified app Frameworks and removes target debug-library relocation overrides.
- Read explicit PID attachments from actual XCTest app snapshots at producer launch and existing screenshot checkpoints. Every independently referenced app PID must have complete live UI image evidence. Empty sets, missing PIDs, observer errors and changed admitted artifacts fail collection.

The two reports distinguish com.itorah.hanlinminiapps (original standalone producer) from com.davidpovarsky.chavrusatext (Otzaria consumer). Producer source and consumer shared SDK source remain separate exact pins, checked by the existing source-equivalence admission; the observer does not substitute one pin for the other.

## Verification already performed

test_miniapps_runtime_image_origin.py: 12 focused integrity controls passed. They exercise both positive path/hash/UUID admission and refusals for wrong PID, altered installed bytes, wrong UUID, missing sampled private image, relocated debug image, foreign image, absent/missing independently referenced PID, changed admitted artifact, ambiguous UUID, and loss of original test configuration. These fixtures confer no native product acceptance credit.

A single owned /bin/sleep process on the authorized Mac validated the actual vmmap, sample and dwarfdump output contract. PID 1086 produced an actual arm64e UUID D9F36BE8-D4E2-3E7A-A29C-8B8BA9E6219A, matching the artifact UUID; the parser read 82 real image rows. IMAGE_ORIGIN_TOOL_CONTRACT.json names the raw Mac and Oracle evidence and hashes. This is tool-contract evidence only; no product application or simulator was launched by that check.

The changed Swift acceptance file receives a syntax parse before handoff. Full application compilation and genuine paired execution remain required on the final integrated source. That run must execute the existing TextStudio, File Workshop and phone picker selectors, retain the exact producer and consumer source receipts, and produce passing image-origin reports for both applications. No previous producer/consumer acceptance result is rewritten or broadened by this change.
