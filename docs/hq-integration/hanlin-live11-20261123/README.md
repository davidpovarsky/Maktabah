# Hanlin Live11 source admission — 2026-11-23

## Purpose and actual status

Prepare one coordinator-owned continuation of the original Hanlin live native case after Live10 failed waiting for a source link at test line 674. This preparation adds bounded post-send diagnostics; it does not claim to fix the missing Host receipt. Live11 has not run, and preparation has neither accessed a credential nor called a provider.

The application source is `438de95a675f34006bee54e339b37d88c87c032a`, based directly on the original Live10 checkout `9533a8017adadecf770b19811e72b495f32e90f7`. The only application delta is `Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift`, exactly the diagnostic file reviewed at `e7f4098e9282d58b965cc6a886b79f74ff940117`. The live collector gains the corresponding fixed enum/boolean allowlists and an exact application source binding. All native assertions and the original `gemini-3.5-flash-lite` provider configuration remain unchanged.

## Evidence boundary

The accepted no-send run [45041601629](https://github.com/davidpovarsky/Maktabah/actions/runs/45041601629) belongs to `6591bba49d2b5a28d02b763c4360406843fce4cf`. Its four original application/test trees are identical to the Live10 baseline. The original no-send selector and native drag interaction, other UI tests, project and vendored dependencies are retained byte-for-byte. The added journal is the previously reviewed bounded simulator diagnostic, attached to the live input path; it does not alter consent, dispatch, results, source creation, error handling or assertions.

The current complete Source tree differs from that historical no-send tree because of those diagnostic additions. The prior run is reused as historical evidence for the unchanged components; this is not a fresh no-send pass or proof of the post-send Host path.

Original Live10 [45058647581](https://github.com/davidpovarsky/Maktabah/actions/runs/45058647581), attempt 1, published artifact `14769219319` (SHA256 `c06f5fde77b026fcd68af1a7667bc34742becb89cdd2ed409f235495d1ddcc0d`). Its journal ended at configuration completion. The artifact reports screenshot/hierarchy attachments but does not contain their payloads, so no screenshot inspection is claimed. Prior diagnostic schema controls and Swift parsing are recorded once in [the diagnostic receipt](https://github.com/davidpovarsky/Maktabah/tree/e7f4098e9282d58b965cc6a886b79f74ff940117/docs/hq-integration/hanlin-host-live10-20261123); neither is an Apple runtime pass.

## Exact admission and workflow

`LIVE11_SOURCE_ADMISSION.json` pins the application and four product/test trees, original baseline, accepted historical source, diagnostic provenance, final live driver, build inputs, model, selector and workflow bytes. `Scripts/CI/verify-hanlin-live11-source.py` checks the committed local checkout against this contract using Git objects and local reads only. It verifies the original driver logic outside the three diagnostic enum tables and reviewed source binding, and rejects unrelated functional changes.

The workflow remains `.github/workflows/otzaria-hanlin-live-native.yml` with exactly two changes: remove the historical branch-push trigger and run the source admission before credential setup. It permits manual dispatch only. A source admission pass establishes the reviewed source boundary; real build, native Host/source-link behavior and cleanup remain runtime gates.

The coordinator publishes the workflow with the connected GitHub capability, binds the final remote commit and exact admission/workflow blob hashes to the reviewed lifecycle controller, installs an owned temporary credential, dispatches once, observes one exact run and verifies cleanup. The source preparation owner performs no provider, secret or dispatch operation.
