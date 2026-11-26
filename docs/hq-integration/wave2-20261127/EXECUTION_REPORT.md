# Wave 2 — study core continuation, 27 November 2026

## Ownership and source
Root run: chat-d59f11936c744f0da6645be7b64a3c99.
Base: 29a731e273f9a757c743c49e182fece0e8047d46.
Upstream observed through git ls-remote: 4203de5fd77beb119e5826e039be1a61325f7be0.
Asana current handoff: https://app.asana.com/0/0/1220939536336523/f.
Integration owner: https://app.asana.com/0/0/1220939535420506/f.

One writer per Oracle worktree: library, search, reader and coordinator.
Wave 3 owns NativeRoutingAcceptanceTests, MaktabahNativeRoutingHost,
NativeSurfaceWitness and AnnotationViewControllerWrapper.

## Preserved evidence
Existing library7/7 and multipart37/37 component passes, full7,925,185-document
index validation, published Otzaria/Zayitv40 packages, real Zayit50/100/150
component pages, v32→v40 component promotion and reader performance remain
bound to their original sources. They do not establish new UI acceptance.
Native116 baseline on f2e3fecb is82PASS/34FAIL/0SKIP, not a final candidate pass.

## Official release drift discovered
At22:36UTC26November, the live official latest endpoint returnedv41
(release459809828, v41-20261126162443, published19:55:13UTC).
The user's frozen v40 remainsrelease455390662, v40-20261123094345.
The existing Debug release selector pinned only the install phase; cancel
usedlatest. That would cancelv41 before attempting to resumev40 and invalidate
the same-download resume proof.

The narrow change pins cancel/install/restore to the existing explicit
official-release ID in Debug observation mode. Ordinary app launches and
Release builds retain latest. The v40 driver verifies the live selected
release and each required asset's ID/name/size/digest/URL against frozen
official metadata before starting a payload. No synthetic database or
alternate installer is introduced. Settings updates will separately exercise
the actual availablev41 through the original UI after thev40acceptance.

## Change ownership
| File | Origin | Purpose | Alternative | Verification |
|---|---|---|---|---|
| Source/Otzaria/Bootstrap/OtzariaLibraryReleaseClient.swift | downstream, absent from upstream4203de5f | Same selected release for all explicit native observation phases | Requiring latest remainv40 would permanently stale the acceptance; changing normallatest would alter product behavior | Exact native Debug/Release controls; actual public v40 lookup |
| Scripts/CI/library-v40-focused-native.py | downstream CI | Validate selected frozen officialrelease and required assets | A second installer or relabeledv41 result is invalid | Python syntax, official immutable identities, forthcoming real app installation |
| Tests/HQ/library/LibraryReleaseIdentityControls.swift | new downstream tests | Reproducephase drift and preserve production behavior | No product doubles used | Compile four original client/profile/model files on actual Apple SDK |
| tools/hq-library-release-identity.py | new downstream test driver | Record exact source/compiler/binary/exit receipts | Do not equate compile with runtime or UI | Baseline and candidate runs retained separately |

## Current acceptance
- TOC generation fix: focused Apple34/34PASS; original baseline20PASS/14FAIL.
  Productbbc68b0d, evidence59d3bf9e, handed to wave3.
- Full v40 original install/cancel/resume/integrity/cold launch: pending current qualified Debug product.
- Books Updates normalUI/userdata preservation: pending.
- Published search package normalUI install/pagination/offline: pending.
- Full-v32 two original nativeUI/PERF scenarios and full corpusGroups100: pending shared product and coordinated runtime.
- Remaining Native116 search/Sefaria/reader regressions: in scoped workers.

No product task is marked complete by this report.

## Verified component milestones

- Release identity: exact product 47261ccf; baseline Debug 9 PASS / 6 FAIL,
  candidate Debug 15/15 PASS; Release 15/15 PASS before and after with an
  identical binary digest. The actual public v40 lookup passed.
  Receipts: release-identity/RESULT files and ARTIFACT_INDEX.json.
- Installer transaction recovery: product 0d0a010c; evidence 618dd4d1.
  Actual Apple filesystem/SQLite controls: baseline 4 PASS / 5 FAIL;
  candidate 9/9 PASS, 0 skipped. Retains old database and identity until
  final metadata commits, with recovery and cleanup failure controls.
- Global history observation: product 0b5b9375; exact extracted Swift
  helper baseline 11 PASS / 2 FAIL, candidate 13/13 PASS. Native UI remains
  pending; only the bounded preference snapshot grew from 1 MiB to 8 MiB.
- These scoped commits were combined without conflicts in the coordinator
  branch. Combining source does not imply combined-product acceptance.
