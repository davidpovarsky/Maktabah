# Apple Foundation transport55 — actual verified result

Run [44743177022](https://github.com/davidpovarsky/Maktabah/actions/runs/44743177022), attempt 1, completed successfully on the immutable source **ce56baedf0fec15f61a117e5649e8c6865781120**. The actual three executable modes contain **55 passed cases, zero failed cases and no skipped cases**: failure/retry26, cancellation-while-held26 and URLProtocol lifetime3.

The run used macOS on ARM64, Xcode27.2 build27B52 and Apple Swift6.4.2. The compiler ran with Swift6 and complete strict concurrency. The executable compiled and all three original modes ran between14:02:30 and14:02:46 UTC on2026-11-20.

## What this establishes

The complete eight original production files were compiled with exactly one explicit same-file test appendix. The actual original Foundation URLProtocol, request-property admission, TaskLocal inheritance into a child task, one-use token binding, held request, original offline error mapping, explicit retry and held cancellation ran. The separate three lifetime cases cover stopping before rejected start, completing a declined start once and preventing late callbacks after reentrant stop. Only successful retry payload bytes are a declared canned transport.

This establishes the Apple Foundation behavior that the earlier Windows Foundation run could not accept. The Windows outcomes remain separately retained; no Windows result is relabeled as Apple success.

**This is not iOS SDK compilation, Native UI acceptance, embedded Hermes execution, a real external-network request, physical-device offline acceptance or the complete Sefaria product journey.** The twelve additional iPad/iPhone Native cases remain part of the pending Native116 selection.

## Independent evidence verification

Root downloaded artifact14634164383, verified its full59,956-byte SHA256, checked all56 ZIP-member CRCs and compared the extracted member hashes. The immutable GitHub source contents of all13 production/appendix/driver/gate dependencies matched their exact SHA256 and lengths.

Root separately verified the eight whole production inputs, the original HTTP prefix plus exactly the complete appendix, every raw evidence-index entry, actual stdout arrays against the case receipts and each original mode inventory. All55 (mode, case-name) pairs are unique. The three modes are26+26+3; shared admission names run independently in both transport modes and are not misrepresented as55 distinct test implementations.

The unchanged original Apple gate verifier was also executed against the retrieved evidence. These are independent artifact validations, not additional Swift compilations or test executions. The full original build/runtime logs and mode receipts are inside ORIGINAL_ARTIFACT.zip.

Artifact SHA256: **7fc1d299c61bf9d34eb8674cf4b262f880a7189b9b0de4171d49fc66f6ad94d7**.
Original aggregate RESULT.json SHA256: **0626e37f03977c38d94111bbf54c32cb319c938808ff556ea6d68f12521d11b4**.

## Files and reproduction

- RESULT.json records Root's independent review and all13 source identities.
- WORKFLOW_RUN.json and ARTIFACT_METADATA.json retain actual GitHub provenance.
- ZIP_MEMBERS.json binds every original ZIP member.
- ORIGINAL_ARTIFACT.zip is the unchanged complete GitHub artifact.
- CANONICAL_SOURCE_CLOSURE.zip contains the exact13 immutable source files used for the independent comparison.
- verify-evidence.py verifies the delivered bytes and original gate without compiling or running Swift.
- MANIFEST.json seals every other file in this directory.

Run `python verify-evidence.py` from this directory. It uses a new temporary extraction directory, reads the original files and prints the verified55-case result. It does not use credentials, mutate project code or call any external service.

The source/test/SDK/engine/manifest pins and frozen CI branches were not changed to obtain this result. The Sefaria task remains open until its complete original acceptance criteria pass.

