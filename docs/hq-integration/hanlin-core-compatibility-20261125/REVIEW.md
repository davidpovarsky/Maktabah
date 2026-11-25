# Hanlin/Core compatibility before final Otzaria integration

## Recommendation

Merge Hanlin 5b69bbb52013686922efa7c4e7d9f2d44b774f94 into the existing
Otzaria integration 4e921b9517f2fc28fcaebcb2ba7441ab1fb46a90, retaining the
published Core pin abf0921c6e89e6521cc2b510ff11016b45a0ef08 throughout.
Preserve both histories and the existing Otzaria manifest-generation evidence.
No source, pin, worktree or shared Git ref was changed by this review.

The root-owned Hanlin worktree was clean at 4e921 when inspected. Git reads used
exact commit objects. Missing abf objects in the older Oracle Core checkout
initially returned exit 128; this was not interpreted as an ancestry result.
The exact published object was fetched into a separate owned diagnostic bare
repository, with the original object store used only as a read-only alternate.

## Core lineage and preserved fixes

Actual Git merge-base and --is-ancestor checks prove that
3f38f1302764635c9991d0d00fd7b12471a5373c is an ancestor of
abf0921c6e89e6521cc2b510ff11016b45a0ef08. The merge base is exactly 3f38.
There is no missing thought-signature branch to merge.

Published abf and the Oracle cache-controls head
06cd98dc874a12e56ba8864a2baa20c22363d6c0 have identical complete trees:
f094f58f7956903e740a5188cf1e9d43c126248e. The three cache commits were
published with different commit identities; their file contents are identical.

All six production/test files introduced by the thought-signature change are
byte-identical between 3f38 and abf, with their Git blob IDs retained in
REVIEW.json. This includes the original tracker, V3 wire converter, V3 provider,
tracker controls, V3 signature controls and the original signed streamText
continuation test. Existing tool-result continuation ancestry is also retained.

Since 3f38, three production files change: OpenAIPromptCache.swift,
OpenAIResponsesOptions.swift, and StreamText.swift. The StreamText diff is
limited to cache read/write/no-cache root telemetry attributes. It does not
alter the signature tracker, tool dispatch or continuation conditions. The
complete reviewed production diff is retained in core-3f38-to-abf.diff.

## Hanlin union and conflict resolution

5b69 is newer than the initially supplied 8ec309c0; current Asana C8 identifies
it as the source of application attempt03. It includes the latest composer,
MiniSDK and wave3 integrations. d4fbdf731dbadc95a13ead306a6d02ae61a88aad
is an actual ancestor.

06b7274b85bd2b1a37bed885f2a9a141ec4f9e51 is not a Git ancestor of 5b69.
Its two changed files, Scripts/NativeScript/README.md and the metadata
generator wrapper, are nevertheless exactly identical in 5b69, with Git blobs
dffbdecd67a9249fabbfe830b2f0d9d681070e0d and
25f8477169b7ec030d25d32d957a877403b4f4d7 respectively. Reapplying that patch
would duplicate an already preserved implementation.

The shared Hanlin ancestor of 4e921 and 5b69 is c309eb4028f905f0909777ce86e176ecdeb10251.
The Otzaria side differs from c309 only in the Core 3f38 pins, generated manifest
and five added generation-evidence files. It has no unique runtime source
changes to lose.

A real Git merge-tree calculation in a separate owned diagnostic object store
found exactly 11 conflicts:

- Three manifests: root Package.swift, Packages/HanlinAgentSDK/Package.swift,
  and Packages/HanlinPlatform/Package.swift.
- Seven locks: the Xcode application lock and the AgentSDK, Platform, Parity,
  Sefaria, TextStudio and Wikipedia Package.resolved files.
- docs/agent-sdk/unified-package-manifest.json.

Choose the complete current 5b69 versions for these 11 files, preserving its
current runtime graph and abf pins. The five prior Otzaria generation-evidence
files merge independently. Run the original canonical manifest/project checks
after the actual merge. The diagnostic merge output is retained verbatim;
it is not a committed or accepted merged application.

## Existing evidence that can be reused

The actual Mac Core receipt records 48 passes in two Swift Testing processes
(4 producer controls plus 44 ChatCore controls), zero process failure, and a
complete original source closure. Its Hanlin source was
04c1942bc88cd4de7deafda7dd342b9b6c401dcf, with the published Core abf pin.

This review independently verified:

- All 80 canonical source/resource/test SHA-256 values remain identical at 5b69.
- Both original producer test hashes match the exact abf Git objects.
- The raw compressed log decompresses to its recorded SHA-256
  6bf42713f4fbc1fce3d9ac6dac10d094532c8c91f869558b5cd9504a734f40a9.
- All four proof dependency pins match the 5b69 application lock: Core abf,
  OpenTelemetry 2.6.0/c6fcee77cfc21ba400366f12475217c7b6e1d605,
  argument-parser 1.8.2/6a52f3251125d74daf04fcbd5e6f08a75d074382,
  and atomics 1.3.1/0442cb5a3f98ab802acb777929fdb446bda11a34.

The original receipt SHA-256 is
cce3af5cc6bd4c090722b66b3d48658f88a2391c162b18081b68cdcbaf34f362.
The receipt and raw log are retained beside this review. Repeating these 48
unchanged controls is unnecessary. Reuse in the final Maktabah build remains
conditional on its actual resolved dependency closure matching those inputs.

The historic 4,194 Core result remains attributed to its original source. It
is not relabelled as a full abf execution.

## Remaining affected gates and limits

Run only the affected original StreamTextThoughtSignatureContinuationTests and
StreamTextToolResultContinuationTests against abf: six declared methods and
seven actual invocations, including both original stop/toolCalls parameters.
The cache/telemetry controls are already covered by the verified existing 48.
The unchanged provider/tracker inputs and historic large suite do not justify
repeating thousands of unrelated cases.

Asana C8 at 2026-11-25 02:57 UTC reports original application preparation passed,
with app attempt03 active as job6bb4e38583f9. The strict app gate requires
46 methods and 48 invocations; no full application success was available at
that observation. Its existing owner should complete that job without a
duplicate build.

The final Maktabah integration still requires the actual unified app compile,
source/dependency/product binding, real Hanlin Live Composer/source-link
interaction, original MiniApps host/metadata launches, and the project's final
native/release/distribution gates. This document is read-only source/evidence
review and supplies no new native runtime or TestFlight acceptance.
