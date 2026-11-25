# Maktabah final execution continuation — 2026-11-25

## Current state

**Development and acceptance remain in progress. No new TestFlight build has been
uploaded, and no full release acceptance is claimed.**

The integration branch is `codex/otzaria-final-delivery-20261125`.
The latest tested source checkpoint is
`820f4724908dec654cf976988fa3f9c1a59557ab`; its new product changes were committed
at `a04c32c7284bdfb1efbd2720b56be1cf48d1dd73`. This includes:

- Original integration `08f50a5646b7669d15f8c53cb13c84ac504a02bd`.
- Empty native editor input correction `6b330a2964adf30932cfb7e86fc984068c7c5d10`.
- MiniApps source `8cdc0c0833154e71af5047983c47115db0005e35`, latest producer controls
  `2c86aa9725a73fb2b4c6575e9c32312ec33f491b`, and the original transactional
  requirePlainWrite guard preventing a MiniApps result from overwriting rich content.
- Original full-snapshot Library update policy
  `74ae9510d90b50343e961967616e5630d1682295` and strict current-build v40 wrapper
  `387ddd7551d9ab15c36df7f75798e5f79fc62864`.
- Original native annotation sharing
  `82c1bc16e49b76fd1e8cb16b5be9e0d643db8b57`.
- Explicit legacy identity mapping
  `d0bc03f9a3767e4c14e50324a29ceb3cff38a874`, exact-source archive verification
  `cf1314b30f8d483a2dbad3953aa6c89de2bdca45`, and complete original Foundation
  source closure `797fd73a795517ea0a02a8651670b6c63f401864`.
- Explicit, bounded preparation of existing notes from the normal iOS Settings
  interface. It preserves original CloudKit names, annotation rows, tags, clocks,
  pending uploads/deletes and saved rich bodies. It creates local preparation
  receipts only, with no selected network destination.

Shared Hanlin is currently `4e921b9517f2fc28fcaebcb2ba7441ab1fb46a90`, with
Swift AI Core `3f38f1302764635c9991d0d00fd7b12471a5373c`. Newer active shared
branches were found, including Hanlin cache integration `8ec309c0`,
MiniApps `d4fbdf73`, and original NativeScript metadata `06b7274b`.
Their owners are still validating native changes. Do not overwrite those
worktrees or claim their incomplete app runs passed; review compatible completed
changes and synchronize the final shared pin before heavy SDK/app builds.

## Verified milestones

| Gate | Actual result and scope |
| --- | --- |
| Original Anytype 34b8 Release Simulator continuation | PASS, job `job_82a54c1b8ad1`, 72.11s, without rebuilding the original framework or consumer |
| Symbol ownership | Full nlist plus actual dyld-export union; parity checked on four existing images; ownership requirements retained |
| Empty input fix | Actual original iOS view compilation/link PASS, `job_477cfbd202e7`; integrated normal UI remains pending |
| Hanlin manifest | Actual Mac generation and --check PASS, `job_efa2cbfb43ad`, 513 original Swift files / 113 targets / zero remaining local edges, at Hanlin4e921 |
| Library update policy | 15/15 PASS at exact74ae, `job_c6a681d1d057`; full native download/install/update acceptance remains separate |
| Original SDK facade typing | Actual full-context Apple frontend typecheck for nine changed primaries PASS, `job_cd0a03dac039`, at SDKc50838; 112 public + 22 Debug requirements, no complete new framework qualification claim |
| Original remote synchronization | Actual two-process, two-repository same-object roundtrip PASS, `job_e8f0acde2861`, 8.68s, LAN disabled and original AccountStop clean on both sides |
| Explicit local backfill | 13/13 PASS on real Mac at820f4724, `job_bf333b32e69a`; complete original Foundation source, independent SQLite/hash verification, cold reopen and committed-batch crash/resume |
| Backfill project and syntax | Actual Mac plist graph and iOS syntax PASS, `job_a21c9baf06cb`; 12 added PBX objects, five array extensions, all other existing objects preserved |
| Final source admission controls | 16 tamper controls PASS for the historical3a product composition; independent review of 34 changes, historical receipts and original engine inputs |
| Distribution identity preflight | Actual unsigned probe signed and strict-verified using the existing Apple Distribution identity through the pinned m1 SSH session; this is not an app Archive |

### Release Simulator retained artifacts

Original SDK source `34b8a7c5ddb34e9287acdb5c189849eeac8cff86`.
Continuation evidence:
`/Users/m1/builds/anytype-34b8a7c5ddb3-sdk/build/SDK-Release-Simulator-Continuation-20261125`.

- QUALIFICATION SHA256:
  `d8c04de3ca4a5d97d28c63470d7364c8f9b26b28f01b43314108ab1618156548`.
- Distribution ZIP: 317,962,802 bytes / 2,324 members;
  SHA256 `44032267bb25372db2ff097965f67e4f47f7a7206f910bfb64e5da22f34faad3`.
- Controller correction: `616646f74170f66a252b94b4bf97676b31787947`.
  No symbol ownership gate was removed.

### Genuine original network roundtrip

[Sanitized source and proof](https://github.com/davidpovarsky/anytype-swift/tree/72c40bc653313b3bd35e024806a14bc4633cf4fb/docs/pinkha/torah-integration/original-native-network-20261125).

Two independent original engine processes used separate repositories and the
actual default remote network with LAN synchronization disabled. The consumer
exported the producer's original rich content, modified that same native object,
and the producer independently exported the reverse change. Content was not
transferred out of band by the harness. Both processes exited zero; both original
AccountStop calls completed. The initial Space-readiness failure remains retained;
the successful continuation reused the same development identity, repositories
and object.

The root read the actual terminal result:
`/Users/m1/builds/anytype-original-network-acceptance-20261125/evidence/network-result.json`,
SHA256 `ede7431f97158b826f225060c19e8e803fc7c8ee35713fc5610544508c8aba28`.
Credentials remain private on the Mac and are absent from Git.
This does not qualify integrated UI, physical-device behavior, or revision CAS.

### Explicit preparation and measured local backfill

Actual source `820f4724908dec654cf976988fa3f9c1a59557ab`, 88 canonical files verified
by Git blob, SHA256, byte count and file mode before and after the Mac execution.
The standalone package compiled the complete original Repository, SQLite, ledger,
identity, local editor and CloudKit source closure. Existing unrelated UI/catalog/
CloudKit boundaries were explicit; no native Anytype body was fabricated.

| Existing notes | Preparation seconds | Highest observed physical footprint at batch boundaries |
| ---: | ---: | ---: |
| 100 | 0.6453 | 6,914,624 bytes |
| 1,000 | 6.6604 | 10,142,272 bytes |
| 5,000 | 32.7149 | 24,969,816 bytes |

These are actual local component measurements on the Mac, not iPad or Anytype UI
latency and not peak RSS. A new process reopened all 5,000 receipts in 18.34s with
zero new versions. A separate writer committed 50 of 100 records and intentionally
exited73; a new process reused exactly50 and prepared the remaining50. Four
independent Python SQLite readbacks verified integrity, deterministic legacy UUIDs,
original rows/tags/CloudKit queues unchanged, exact version/head counts, and zero
outbound deliveries.

- Actual evidence:
  `/Users/m1/builds/Maktabah-820f4724-backfill-component-20261125/build/backfill-024342`.
- RESULT SHA256:
  `d048263a1390f7ca74f7d78c3c13a7b502a55fff0375763a9ff55eca415595d8`.
- [Committed receipts and measurements](backfill/apple-component/RESULT.json).
- Retained Oracle archive:
  `/mnt/development/artifacts/otzaria-backfill-20261125/820f4724908d/backfill-proof.tar.gz`.
- Archive: 6,411,947 bytes / 90 proof files, all members independently verified;
  SHA256 `3902a912daec2774c5c7deab0a5fba1245d701ffe553edcae295fd2c2c02f5d1`.
- Source archive SHA256:
  `e7757a2c128e1cf90e9954c0e34b8bf767adf403165de8fe269759ba9a3e678a`.
- Source manifest SHA256:
  `a60ac4a85137908f14979a7fd049cb33d9138409e2e4fda14a56137b7476b6df`.

The identity lane separately found and retained two original43 Session regressions
and two stale trigger-based28 fixtures. A focused constructor correction
`2651cbf51c3c75bfe8da4073796d047c54f906a3` is published and awaiting integration
with new actual43/28/legacy receipts. Original assertions and strict schema
ownership remain required. The backfill does not instantiate that Session
constructor; do not rerun its 5,000-note measurement merely because that separate
file changed. Record a source/reachability review when consuming its evidence.

## Active owners and next steps

1. **anytype_release** owns native revision read/conditional-update implementation,
   targeted native regression, new three-architecture ABI when native changes,
   final Debug/Release Simulator/Release Device SDK qualification and controlled
   artifact retirement. Native writer is isolated from the qualified Native66 tree.
   The actual ObjectTree lock must cover token validation and State/Apply with
   original restrictions. Import-v1 remains unchanged; unsupported graph changes
   must not be silently accepted.
2. **editor_sync** owns the original Swift revision facade, native Receive and
   conflict UI, saved-receipt mapping, original account/editor integration and
   final normal-UI/native behavior. Reverse receipt sourcec508 and network proof72c40
   are checkpoints, not a final SDK freeze.
3. **library_acceptance** owns identity43/28/legacy acceptance and the remaining
   Groups100/full-v32/full-v40 native acceptance. It must use an actually current
   built app and all qualified SDK routes, not the historicald3 projection.
4. **root** owns shared Hanlin synchronization, source merge/admission, final
   app/builds, Native116/Release114+2, owner gate, signing, CI, ASC and TestFlight.

The default R27 selection was narrowed by a MiniApps-only source branch. Restore
the exact original Native116 seven-group selection from08f50 at final source
freeze; keep the supplementary MiniApps journey separate. The original full
Release manifest still requires114 UI executions plus two distinct Safari oracles
across five configurations. No one-case run may be reported as either full gate.

Outstanding acceptance includes actual normal editor creation/rich edit/save/
cancel/reopen, identity and source anchors, classification/visibility/permissions,
native migration/backfill, reverse and concurrent updates/deletion conflicts,
real multi-device behavior, 5,000 native notes, Hanlin Live composer, MiniApps real
application roundtrip, Groups100, remaining full-v32 UI, full-v40 install/resume/
failure recovery/integrity/cleanup/reopen, English/Hebrew, and required CI.

## Signing, App Store Connect and external owner gate

Existing app verified by actual ASC read `job_83e1962844c6`:

- App6809559414, ChavrusaText, bundle `com.davidpovarsky.chavrusatext`.
- Apple team `NA6HPWARQ2`.
- Last observed build11201 VALID, not expired. Recheck latest build/version before
  Archive; no new build number has yet been assigned or uploaded in this work.
- Existing internal group `04958ecd-edac-4820-b277-8cc626e1ff64` has access to
  all builds; no public invitation URL was returned.

The existing distribution certificate is
`644940FCF25D1730DBD1BF7596AEBA7229E2B8FD`.
Actual probe signing and strict validation succeeded through the established
`scaleway-mac` SSH session as m1. Direct Sentinel's System security session
cannot use the same private key correctly. Reuse the protected signing helpers,
original keychain and ASC key; never replace them or print secrets.
Final app entitlements/provisioning, Archive, IPA export, validation, upload,
Apple processing, compliance and internal availability remain pending.

`MAKTABAH_OWNER_VERIFICATION_KEY` was absent from repository secrets/variables,
and the documented existing Windows owner-private-key file was absent.
Prepare the exact final reviewable patch manifest after source freeze, then use
the project's real owner signing/verification mechanism. Do not create an agent
identity, self-sign owner attestations, alter the trusted verifier, or bypass it.

## Evidence, storage and task status

Preserve Core4194, Library7, Multipart37, NativeHeart66, original ABI3, original
Debug89public/22SPI and atomic43+2 at their actual tested source. Changed native
code requires new impacted native/ABI evidence. Different global HEAD alone does
not require rerunning unchanged thousands of tests.

The historical3a source-admission manifest passed16 controls and independent
composition review. Its exact product bytes are now historical. Regenerate the
strict profile after final product/SDK freeze; never let it admit arbitrary HEAD
or relabel a stale generated build.

Storage follows the current mac-storage-lifecycle-v2 policy: actual incremental
need, concurrent owners and a modest OS margin;100/50GB are warning levels.
Only the SDK lane retires old shared products after complete Oracle archival
verification. Actual retirement `job_f267f968b29c` freed13,544,583,168 bytes,
preserving2,416 protected proof files and six source HEAD/dirty states. Retained
product archive SHA256:
`9acb16c572f787929692bd86fabd2fbb982d0d85cff682daf545f13c8998c8a3`.

No product acceptance task has been marked complete. The historical handoff task
was already completed before this execution; updating its notes is not a product
completion. The initial recursive Asana inventory contained59 open tasks/subtasks.
Re-read the live state before each milestone update and before final delivery.
Physical iPad checks remain separate for the owner once a qualified TestFlight
build is actually installable.
