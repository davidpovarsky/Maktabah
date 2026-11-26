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

## Second source milestone and full-v40 identity

Combined product source c84a95d28379069e15d2445301a6cb96714d8282 includes:
- Sefaria Mobile structure titles: product c1ea0378, identical actual Apple
  controls 78/84 before and 84/84 after, evidence 18877faf.
- Original Sefaria native selectors and loading accessibility: 49cfd5e8;
  syntax only so far. Both original Pad and Phone classes still need execution.
- Published production search install/page tests: f54834b9; exact three test
  selectors and environment in search/production-ui-contract.json. Only parse
  has run, no new normal-UI package acceptance.
- Search local readiness and native filter Dynamic Type: 4449813a;
  original refresh method 6 PASS / 2 FAIL before, 8/8 after. Dynamic Type
  requires the unchanged actual accessibility audit.

The read-only identity recipe in v40-source-identity ran on Oracle with
the exact full official v40 database (4,355,063,808 bytes, SHA256
8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01).
Counts were 8,259 books / 7,925,185 lines / 7,001,824 links.
Actual book IDs and counts: Berakhot 103/2,875; Tehillim 28/2,678;
Derashot HaRan 3152/528. The retained 52,332-row unit is book 8042,
toc:1948815, source line indices 0...52331, midpoint 26166.
The former 8,307,947 UTF16 length remains explicitly subject to real
Swift catalog revalidation. This identity receipt is neither new UI
acceptance nor another index-document validation.

## Outstanding execution and newly confirmed gaps

The existing Groups100 selector explicitly launches miniTest10; production
coverage needs an additive source-qualified variant. Wave 3 has been asked
to own its UI variant; Wave 2 owns actual full-data execution.
The two original full-v32 selectors remain strict and separate from the
new full-v40 observer profile being prepared by the reader owner.

F01/F02/F04 lacked complete native oracles. While preparing them the search
owner found that changing a search result's selected edition did not pass
version identity into Sefaria section loading. A narrow version-aware path
is in progress, so c84a95d2 is not asserted to solve that later defect.
Inspector F05/F06/F09/F10 needs actual source-selection, body, author-grouping
and commentary/quoting assertions beyond historical screenshots.

Books Updates is being prepared through ordinary Settings with real note/tag,
favorite/history and group creation. It will exercise v40 to the actual
official v41 release, preserving prior library and logical user data.
All native outcomes above remain pending a qualified combined build and
actual sufficient Mac space; no task completion is inferred from source
preparation, typechecking, fixture controls or a historical build.
