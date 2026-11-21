# Current unsigned upstream provenance

Captured immutable head: 05a8d83d5f05bd8a67c2594bc3c69dfb8340a815.
This package grants no cryptographic or product acceptance. Original source, policy, register and historical payloads remain unchanged.

## Scope

| Range | Protected paths | Original guard |
|---|---:|---|
| 5c108887f142779a84ef114cd85e50fb1eaceb8b to 05a8d83d5f05bd8a67c2594bc3c69dfb8340a815 (central) | 11 | FAIL |
| 031df35710ab2c6015efb1acd1e65154dbcd3f24 to 05a8d83d5f05bd8a67c2594bc3c69dfb8340a815 (policy-baseline) | 49 | FAIL |

Original saved verifier reports are retained under guard; generation does not rerun the gate.
UNSIGNED_MANIFEST.json contains exact per-path blobs and normalized patch digests for both scopes.

## Historical records

Of 14 Build 8401 records, 2 current blobs and 0 current digests match.
Preserved historical patch integrity matches: 14/14.
See HISTORICAL_8401_COMPARISON.json for the individual comparisons.

## Material remaining for trust verification

- An authentic externally configured owner Ed25519 verifier identity.
- Authentic signatures over the final accepted base/path/head-blob/patch-digest tuples.
- Genuine approval reference and validity period in the unchanged canonical signature payload.
- Current records in the singular-path form admitted by the unchanged loader.
- Required final native/product acceptance, separately from cryptographic verification.

## Reproduction

Run the included generator with full --head, --central-base, --policy-base, --upstream, --repo, matching saved --central-report and --policy-report, and a fresh --out under docs/hq-integration.
The selected head must be checked out with no tracked edits. Existing snapshots are never overwritten.
Later product changes require fresh source-bound patches and verifier reports. Code-identical CI/docs descendants may retain this receipt with an independently checked source identity mapping.
