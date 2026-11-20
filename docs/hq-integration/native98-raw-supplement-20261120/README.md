# Native98 exact raw artifact supplement

This docs-only supplement completes durable publication of the **original small evidence ZIP** for run 44723902453. It follows summary commit 421af5c303b09c13811ff5a687404fa3db1765c6. It does not run or retry a test.

- Checkout: 60a57972acb28739ec738565083bf17fb7503028; app/tests: 87b783ac3f0257e8461762e0ea9dfa5248dd06e8; attempt 1.
- Workflow conclusion: **cancelled**. The actor and cause remain unknown.
- Original Simulator build: SIMULATOR_BUILD_FOR_REAL_UI_PASS, with 996 source inputs reported verified by the original build record.
- Complete XCresult exports: **31 unique iPad leaves: 22 PASS, 9 FAIL, 0 SKIP**.
- Remaining 67 selected cases: one completed raw INDEX failure, one raw start with no terminal result, and 65 whose start is not observed in retained logs. iPhone and HID acceptance are not established.
- Full 98-case acceptance remains incomplete. No result is transferred to a newer source.

## Byte integrity

ARCHIVE_REASSEMBLY.json binds five ordered parts under raw/archive that reconstruct the complete unchanged 35,944,918-byte artifact: SHA256 1dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310. Splitting is necessary because the Git connector rejects requests over 16 MiB; no original byte is omitted or transformed. All 102 ZIP members passed CRC and are individually SHA-bound in ZIP_MEMBERS_SHA256.json. The partial INDEX .mp4.sb member is retained exactly as received; its presence does not prove a complete video or additional test outcome.

ARTIFACTS.json binds the original ZIP and selected lossless gzip payloads by original and stored byte lengths, SHA256, and canonical Git blob IDs. The selected payloads retain full build output, all three raw test logs, complete XCresult trees/summaries/receipts, the matrix and original Reader log.

The four original verified receipts describe canonical JSON hashes, while the ZIP members contain pretty JSON. RAW_CANONICAL_HASH_VERIFICATION.json proves both independently without rewriting any raw byte. This was a packaging comparison error, not a failed Native test.

## Preserved failed packaging attempts

The exact sources and actual receipts of job_11a81e864442, job_50418e0d76b8, and job_4f77deafc2da are included. They respectively failed on raw-versus-canonical hash comparison, an absent optional input path after source/leaf checks, and Windows argument length before process launch. The later Windows finalizer is explicitly marked NOT_EXECUTED. The local validator included here only checks evidence.

## Capture boundary

This supplement does **not** download or publish the 775,094,118-byte capture archive. Its previously selected, range-authenticated original bytes still reside on the disconnected Windows host. Summary 421af5c303b09c13811ff5a687404fa3db1765c6 preserves the prior observations and this publication limit. The full capture-archive digest remains advertised-only, not independently verified.

## Reproduction

Run python3 VERIFY_PACKET.py from this directory. It verifies the packet SHA/Git identities, all gzip round trips, the complete ZIP and CRCs, all four canonical receipt hashes, the 31 named leaves and 98-case classification, and both raw INDEX observations. This is evidence validation; it grants no compile, UI, HID, physical-device, or final-source acceptance.
