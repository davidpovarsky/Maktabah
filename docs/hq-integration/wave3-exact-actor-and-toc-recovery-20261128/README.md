# Exact actor sources and bounded TOC recovery

This additive documentation checkpoint preserves all 29 files (2,070,269 raw bytes) from three closed recovery scopes. Application sources and package pins are not adopted by this commit. The original scopes remain intact.

## Actor source recovery

Inspector: the 66,811-byte candidate SHA-256 e718da5aef04543036e150278154b854611a75845514286beea5c91113be7c54 is the exact previously recorded candidate. Its sole changes against the preserved predecessor are inline @MainActor annotations on the two original local Catalog and Source classes. The inverse patch reproduces the full predecessor. The original temporary staging script was unavailable and is not represented as recovered.

BookInfo: the 10,668-byte publication candidate SHA-256 839c4da8ddd9f7795b02046da7c5f778d5f85f744da14ace7819e24d2633558f matches the full previously recorded candidate. Its two initialization changes follow the exact independently recovered Library pattern, preserved here with both pattern bodies. Its inverse reproduces the full BookInfo predecessor. The old UPDATE.json was unavailable; the newly generated RECOVERY.json is distinct and does not replace that old record.

Both recovered source candidates remain uncompiled and unintegrated. Original compiler failures and capacity refusals remain in earlier checkpoints. This recovery reports no new test pass.

## Bounded TOC lookup

The raw lookup and its later handoff preserve the single search of two pinned archives: 668 top-level and 248 nested ZIP members, with bounded JSON, Python literal, base64 and gzip decoding. Neither missing exact candidate (binding 59f2b638..., field cf5fa395...) was recovered. The lookup reached 4,096 unique decoded nodes; 816 additional payloads were hash-checked without recursive inspection, and two gzip expansions reached their bound. This establishes only unavailability within that bounded lookup, not exhaustive or global absence.

TOOL_RETURN.json retains the successful scan's actual exit 0 and the subsequent response parser failure caused by trailing Python SyntaxWarnings. The scan was not repeated. New TOC work is explicitly a new implementation from pinned current originals, not a reconstruction claimed to be either missing body.

## Preservation and limits

RECOVERY_RAW.zip contains every file byte-for-byte, including original manifests, controllers, source candidates, predecessor bodies, and failure evidence. INPUT_MANIFEST.json records original identities and full SHA-256 values. Intake reads every archive member back and compares every source again before committing. Binary Git reads are logged by byte length and hash rather than decoded as text.

This checkpoint changes no non-docs top-level Git tree, current ownership registry, Apple build input or release status. Oracle preservation controls have separately completed 11/11 PASS and an intended 57 != 70 omission-negative failure; Mac focused controls and the real Native116 rerun remain incomplete. No Archive, IPA, App Store Connect validation, TestFlight availability, or physical-device success is claimed.
