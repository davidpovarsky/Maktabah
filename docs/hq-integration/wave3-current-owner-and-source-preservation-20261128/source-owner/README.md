# Source and owner-verification preservation checkpoint

This bundle preserves six closed evidence scopes without changing their bytes. It is prepared for Root's additive documentation checkpoint; no live repository, approval record, original source, or previous evidence was edited.

## Scope and exact content

| ZIP prefix | Original scope | Files | Original bytes |
| --- | --- | ---: | ---: |
| toc-common | TOC common-source proposal | 33 | 1,215,247 |
| toc-phone | Original phone parent pre-effect-readiness proposal | 10 | 81,336 |
| owner-audit | Current owner-signature and protected-path audit | 39 | 1,549,283 |
| native-v3 | Original Native116 indexed-wire v3 proposal | 13 | 255,866 |
| native-v3-review2 | Native116 second source-review proposal | 13 | 262,074 |
| native-v3-review3 | Native116 third source-review proposal | 13 | 266,271 |
| **Total** | **Six closed scopes** | **121** | **3,630,077** |

SOURCE_MANIFEST.json maps each ZIP member to its exact original absolute path, byte length, SHA-256 and original file metadata. INPUT_PINS.json retains the independently supplied manifest/seal pins and exact closed path sets. PRESERVATION_RAW.zip contains all 121 original files, including the owner audit's already sealed ZIP as unchanged raw bytes. No line-ending conversion, source reconstruction, extraction/repacking of that inner ZIP, or source sanitization was performed.

PRESERVATION_RESULT.json records sealed-set verification, ZIP CRC and full member-byte readback, final rejoining of all original files, and resource observations. PACKAGER.py is the executed preservation controller; its inputs are the adjacent INPUT_PINS.json and README.md supplied by the recorded bootstrap. It does not import or execute any preserved source.

## What the evidence establishes

The integrated reference is HEAD 55845d215d8e6ff4559dab04ef63791920c4053a, Source 182dd74229c04959cecae82a59d16268dcbd80bc, with product bytes equivalent to 87ccd4625115eb43c650180174825b288ba2e592. These are the audit's immutable references; this bundle does not adopt any proposal into that source.

The TOC common-source and phone proposals remain **uncompiled and unintegrated**. They preserve original before bytes, exact proposed edits and their recorded inverse checks. The common proposal retains the original 514-byte attachNoteEditor body and the actual nativeStateChanged-to-directory invalidation trace. The earlier foreign-observation capture-order finding and its corrected source are both retained. Root's finite query construction/apply/readiness wiring, the UI query/view hooks and actual field/receipt qualification remain external prerequisites. No Swift, UIKit or native acceptance result is created by preservation.

The owner audit contains an actual, separate read-only verification of **55 valid and unexpired historical signatures**. Current protected-path coverage at the pinned source is **69 = 31 matching + 24 stale + 14 without an approved record**. All 69 are modified existing paths. Historical signature validity is not new approval for changed bytes. The unchanged registry, public trust evidence, trusted verifier and full canonical-patch/blob comparisons remain in the original audit. Its full release gate was not run and current external key provisioning was not probed. This checkpoint performs no additional signature mathematics and no signing, private-key, Windows, DPAPI or network-authentication action.

All three Native116 proposals are source-only. The successive copies preserve the source-review findings and their corrections, including the omitted IndexedRows import and bounded JSON integer parsing; those findings are not represented as executed native failures. Review3 also retains the exact accounting limitation: prior scopes are charged using allocated blocks, current tool/seal source lengths remain logical, and original phase-directory blocks are not separately added. The 48 MiB accounting is therefore **not** an exhaustive physical-allocation proof. The separate focused-control scope still requires an external exact closed-set and <=4 MiB allocated-byte seal before qualification. No Native116 source scan, fit claim, producer/import, focused control, upload, SDK build or native acceptance run is performed here. Historical 25-control evidence is not rerun or reconstructed.

## Preservation guarantees and limits

Every named scope was checked against its supplied closed manifest and independent seal. Missing or extra leaves, extra directories, symlinks, multiply linked files, nonregular files, changed bytes and changed retained identities cause refusal. Full member readback verifies exact raw hashes, preserving CRLF and other original byte sequences. Original file identity, mode, ownership, link count, size, mtime and ctime are rechecked after archiving. Read access can update filesystem atime; no atime-restoration claim is made.

The new output scope is limited to 8 MiB of actual allocated blocks, including its directory, controller, inputs, ZIP and metadata. Creation requires the unchanged rootfs floor of 1,593,835,520 bytes plus an 8 MiB reserve. No Data-volume output, source checkout mutation, Git operation, compiler, product test or native operation is part of this controller.

Root will separately add the Inspector Kit provenance and independent review/read-attempt receipts, then decide the documentation-only checkpoint. Those external materials are not fabricated or silently included in these six closed scopes. This bundle establishes preservation integrity, not release qualification.
