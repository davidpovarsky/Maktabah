# Full-v32 native occurrence probe

## Scope and source

This change adds a direct original-engine acceptance observation to
`OtzariaPrebuiltSearchAcceptanceRunner.swift` from application base
`263e6b1357c2322226bce54dc8051007b6b12285`.
It changes no installer, downloader, recovery, index builder, database, C ABI,
original Swift result model/decoder, runtime policy or Core admission behavior.
The runner is entered only by the existing explicit prebuilt-acceptance
environment. No new user capability is advertised.

Both existing phases already open one original `OtzariaSearchEngineBridge` for
the installed index and close it through `defer`. After the original three search
modes and golden query, the added code uses that same engine for `בראשית` and
`אברהם`, sequentially. The original final staging/local-indexing guards still
execute afterward. A cold reopen remains a separate actual application process;
this source change does not claim a cold OS file cache.

Each request uses the existing original limits: 60,000 ms, at most 1,000,000
candidate documents, 10,000,000 inspected positions, 262,144 positions per document
and 4,096 segments. Its global scope is explicitly `facets: ["/"]`, `bookIds: []`.
The production default limits remain unchanged. The original qualified
`original265ToExactOccurrencesD5` read contract is required; this runner cannot
enable that registry or bypass the original manifest/resource validator.

`expectedSource` comes from the actual C `buildInfo()` and the original producer
commit in the validated manifest. The original Swift/C decoder verifies the
returned proof against that source and request. The runner also requires its
live-document observation to equal the existing engine `documentCount()` result.
No expected count or revision is substituted into the observed result.

## Final additive report schema

The existing report fields retain their behavior. Three fields are added:

```text
consumerBuild: actual OtzariaSearchEngineBuildInfo
artifactProducer: actual manifest.lexicalEngine
exactOccurrences: [
  {
    query: String,
    request: original OtzariaExactOccurrenceRequest,
    result: {
      occurrences: UInt64,
      matchingLiveDocuments: UInt64,
      proof: every field of the observed OtzariaExactOccurrenceResult.Proof,
      work: every field of the observed OtzariaExactOccurrenceResult.Work
    }
  }
]
```

A private `Encodable` reporter copies all 24 fields of the decoded result and
its nested structures, preserving integer widths, array order, exact strings,
request token, generation, segments and optional delete stamp. Optional nil delete
stamps may be omitted by synthesized encoding and represent semantic nil. The
original model/decoder remain byte-identical. The private write-only `Report`
conformance narrows from `Codable` to `Encodable` so the original request can be
encoded directly without introducing a replacement request DTO.

If a probe fails, the existing `passed: false` failure report is used. Any earlier
completed probe is retained for diagnosis. Partial observations cannot satisfy
the external gate. No additional engine is created, and the observations are
**direct Swift/engine acceptance, not Core authorization or a native UI receipt**.

## Independent SQL oracle and external gate

Root owns `hq-v32-prebuilt-native.py`, its negative fixtures, source pins and
dispatch. Its gate must retain the original corpus/hash, production discovery,
native download/resume of 1 MiB, three search modes, golden identities, no local
index build, no staging and distinct install/reopen process-ID checks.

The independent Windows full SQL oracle is committed at
`df3b894cef2c8ea3dd50ccb31394635aa8fe4077`:

| Query | Exact token positions | Matching live documents |
|---|---:|---:|
| בראשית | 143,982 | 104,120 |
| אברהם | 170,515 | 109,419 |

The corpus has 7,080,797 live documents. These are **earlier independent SQL
expectations, not newly observed Apple results**. The new runner contains none
of these expected scalar values.

The qualification summary's immutable Git LF bytes have SHA-256
`3ccd704a831f4a96ec06a691bdc17e7a8988168659bad766815018c9106983a1`.
The original Windows CRLF bytes have SHA-256
`56fead3a78281ea6a1ba68d21806d5fa7505f2ba32b709fd03c1ce831c8fa3ca`.
Both represent the same JSON. The direct full SQL raw result at
`raw/full-sql-global-oracle/attempt4-partitioned/RESULT.json.gz` has uncompressed
SHA-256 `015b4ac382b8c6005d672234cfa7fc1ddaf291f7e5e0d07982f2c89db242f781`.
Root's external gate binds those bytes and verifies each phase's actual scalars
and provenance. Request tokens and generation IDs must be valid within each
result; they are not required to match between different application processes.

## Verification status

- The complete changed Swift file was parsed for `arm64-apple-ios27.0`, exit 0.
  The Windows toolchain emitted two explicit SDK/sysroot environment warnings.
  This is **syntax only**, not Apple SDK typechecking or linking.
- Source preservation checks reconstruct the exact original runner after removing
  the additive observation/report changes. The original models, Bridge, policy,
  installer, downloader and outer Python gate are unchanged in this worktree.
- Root independently reviewed the source and found no blocker in the observed
  DTO mapping, actual build/producer provenance, same-engine placement, qualified
  contract requirement or failure behavior. This was a source-only review.
- No corpus or index was downloaded, generated or copied in Windows for this
  change. No new native count, install, reopen, Apple or device success is claimed.

Actual Apple SDK compilation and the full-v32 install/reopen run remain pending
on the integrated pinned source. Existing old-consumer Native evidence and the
mini-only Native selection do not qualify this new full-corpus d5 probe.

## Additional DTO validation

The exact committed reporter and original request/model code passed four standalone Windows encoding checks. See [DTO_ROUNDTRIP.md](DTO_ROUNDTRIP.md) for the actual results and synthetic-boundary limits. Full Apple install/reopen occurrence execution remains pending.

Checksum scope: SHA256SUMS.json hashes the committed Git blobs (canonical LF for text). RAW_EVIDENCE_SHA256.json separately hashes the original decompressed evidence bytes and their gzip archives. This distinction preserves exact Windows logs while keeping repository checksums valid after checkout on Apple.
