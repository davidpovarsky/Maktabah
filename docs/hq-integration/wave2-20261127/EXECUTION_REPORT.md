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

## Later checkpoint — Inspector and original UIKit selection

This section supersedes only the earlier source-preparation status above. It does not upgrade historical evidence or mark any product task complete. Product source at this checkpoint is cb684f5e998592d9689cf9775f11ce2651a3c943; complete Source tree: a92ee56b382d3708510b2fbadf3357a03eab6e45.

| Work | Verified scope | Native app acceptance |
| --- | --- | --- |
| Retained library marker repair 3f062f6c + 53769b8d | Same actual Apple filesystem/SQLite controls: 10/10, baseline exposed 1 failure | Pending original install/update |
| F07 ace312925 | Actual Apple AnnotationStore: 9/9, 30 CRUD cycles and a separate 30-record cold process proof; explicit cloud/locator boundaries | Native Notes UI and full provider remain separate |
| Sefaria selected editions e3af7bc7 | Actual version-aware source and captured API payload controls: 24/24 | New registered four-case context suite prepared; not executed |
| Search preview cancellation 8c073dae | Actual task-body controls 22 PASS / 15 FAIL to 37/37, whole SwiftUI view typecheck | Pending integrated native case |
| Inspector generation 9d4c6ded, integrated cb684f5e | Actual unchanged adapter + pinned Kit on Catalyst: 2/12 to 12/12; complete host typechecks | No Maktabah UI run; semantic v40 suite prepared |
| Passive selected range 9e38d9ac, integrated 827acac9 | Whole observer iPhoneSimulator SDK typecheck and 12/12 real UIKit Catalyst component controls | Exact native selection/annotation case being completed |
| Groups100 c7330955 + controller2b00b948 | Separate production UI source, original recorder19/19, host37 source-admission controls, exact50 execution inputs present | 100 full-v40 transitions/RSS/cold proof not run |
| Inspector semantic oracle 1c1b2a2d + UI7facfd4b | Fresh full v40 hash/stat witness, actual SQL for Psalms1/75/150, registered original UI test typecheck | Not run |
| F08 47d95262 | Actual-source catalog and additive original line/paragraph/chapter open/focus/pull UI source | Not run |

A concrete managed-index defect was found during Books Updates review: retained v40 index files could remain ready/searchable against a replaced database, with a size-only admission shortcut. The search worker is binding readiness, engine cache and result publication to the original bounded source observation and correcting the Zayit missing-manifest/stamp admission. No whole-database hash is added to each query. Apple source controls are in progress.

The hidden Inspector defect is repaired: current generation admission resets both the Kit repository and adapter caches, and suspended/retired callbacks cannot publish into another generation. Whole source and actual Mac receipt were independently read by the coordinator. Pinned SDK source is unchanged.

The ordinary Settings v40-to-latest-v41 case now includes original pause/relaunch/resume, owned metadata-write failure and rollback/recovery/retry. Its final semantic extension is checking original Note/Favorite/History/copied-group reopen against captured source context and canonical identity; persisted legacy line offsets are not assumed universally stable.

Current execution plan preserves the exact two original full-v32 cases. A first genuine v40 installation may use a separately identified qualified integrated build and retain its own original source receipt. Every later observation will independently qualify the then-current app/runner/SDK images and revalidate the retained v40 database. Settings update runs last. No full Native116/Release114, production search UI/offline, full-corpus PERF01–03 or Groups100 completion is claimed here.

Storage was recovered by verifying and removing only 74 already-published compressed duplicate parts, with full local/public hash and no-live-reference witnesses. The production database and original evidence remain in place. See storage/zayit-published-duplicates. No Mac output was removed by Wave2.
