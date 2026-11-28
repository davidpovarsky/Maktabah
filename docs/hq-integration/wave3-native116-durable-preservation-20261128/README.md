# Native116 evidence preservation and exact stage-file restoration source

## Actual preserved result

The historical Native116 result remains 82 passes and 34 failures. This preservation work does not rerun or change product acceptance.

Authenticated full readback job_a02eee978d8f completed on 2026-11-28 at 09:17:08UTC (exit 0; 1678.44 seconds). It read the complete existing archive from byte 0: 1,272,863,810 bytes, SHA-256 f427758916a543b58f230c87e3d5eff1067e7db47f79a46d984315f8e155b556. It verified65,011 tar members and65,010 unique payloads totaling2,249,540,662 bytes, and mapped every original regular file to its verified payload. Both the 7,106,913-byte source snapshot and 160,216-byte preservation manifest were also read completely. Original source verification before and after the transfer passed.

The exact 65536-byte FINAL_RESULT.json SHA-256 is e9242bcf55ad96d02f5d5ad876dc65813a40699258406b360ead957cf5cda702. Its complete bytes, the actual successful job/admission, the three full-readback receipts and before/after source receipts are preserved in the bundle. Earlier upload timeout, incomplete starter asset, 1200-second readback timeout and two pre-GET refusals remain preserved and are not relabeled as success.

## Durable artifact location

The existing private GitHub repository davidpovarsky/Maktabah-preserved-evidence (ID 1474927804), draft release 461304898, tag native116-remaining-stream-20261127-wave3 retains four assets:

- 803618998: completed staged archive, native116-remaining-original-evidence-staged-20261128.tar.gz; exact size/hash above.
- 803254522: native116-source-snapshot.json.gz; SHA-256 424c2e2f95b3616e39b51cbacc621678dc2899ceba857a2dd42b72b0a0597cc4.
- 803254562: native116-stream-preservation-manifest.json; SHA-256 a8faa73411de67ead8f98856fe25cb3a368d5adb91f1d51f5e3103c9795299c0.
- 803257093: historical incomplete starter; retained separately and never accepted as the completed asset.

Use authenticated repository access. No token, private API journal, credential file or raw repository response is included here.

## Complete source preservation

PRESERVED_NATIVE_SOURCE_AND_READBACK.zip contains 73 members: all 25 preflight-family files, all 23 original-restorer files, all 8 exact actual-readback-binding files, all 7 executable-restorer/pointer files, nine actual readback receipts and INVENTORY.json. Every member was read back and compared in full. INVENTORY.json records original absolute scopes and exact per-file byte counts/SHA-256. Existing original families remain in place.

The seven current executable/pointer files are also represented under restorer/. Six are direct copies. The Mac receiver is preserved as lossless base64 JSON because its original final blank line triggers the normal Git whitespace check; the original receiver bytes remain unchanged in the complete bundle and original source scope. PUBLICATION_FAILURE.json records that first publication refusal. Root independently verified the one actual-job-output correction, eight Oracle source/family-accounting changes and four Mac terminal-I/O changes by full forward/inverse comparison. Unchanged functions remain byte-identical; the complete qualification function matches the reviewed 09e78 source. The Mac receiver keeps its original 1200-second body deadline and adds a self-only 15-second bound for terminal fsync/close/report. No restored payload is promoted before full authenticated transfer, size/hash checks, exclusive target creation and stored-byte rehash.

The unchanged global 2 MiB restorer family limit accounts for all three historical families plus the separate executable source/admission/runtime partition. The original resource floors and no-overwrite protections remain in force.

## Exact restoration and retirement boundary

The pointer concerns only:
/Users/m1/otzaria-native116-staged-archive-20261128/native116-remaining-original-evidence.tar.gz

This is the Root-owned staged transport copy. The pointer binds the actual full-readback result, exact asset, original metadata, qualified collector receipts and SOURCE_SEAL.json. It does not authorize deletion or claim restoration execution. A separate Root admission and fresh privileged descriptor/hash/no-use verification are required before retirement. A restoration would require its own exact admission and all pinned existing Oracle dependencies, and restores the opaque archive only. No full-tree restoration has been executed or qualified.

The original Native evidence tree, its five outward references, Windows Git dependencies, source repositories, retained terminal sibling and other agents' data remain protected. Captured inode allocation is not a claim of reclaimable APFS space. This packet makes no SDK/application/native/physical/signing/TestFlight acceptance claim.
