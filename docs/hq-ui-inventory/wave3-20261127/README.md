# Wave 3 — current UI source, route, and test crosswalk

This snapshot accounts for all **294 original semantic UI requirements** at
**4a04aeb208fd0e5408a2521f2757e97982bc258c**, based on the integration point
29a731e273f9a757c743c49e182fece0e8047d46. It is a source audit and narrow
localization change. It does not certify the final integrated candidate,
Native116, Release114+2, production v40, device QA, or TestFlight.

The 18 November inventory and 20 November reconciliation remain unchanged.
Their original IDs, inputs, desired visible state, security conditions,
backend contracts, planned checks, and historical results are retained.
The exact notes of the fourteen source Asana tasks are preserved separately
in ORIGINAL_TASK_CONTRACTS.json. Those notes include later annotations as
returned by Asana; they are not a rewritten acceptance standard.

## Verified source coverage

| Observation | Result |
|---|---:|
| Original semantic rows / unique IDs | 294 / 294 |
| Current application Git source rows | 241 |
| Pinned TorahInspectorKit source rows | 8 |
| Pinned Sefaria Mobile source rows | 45 |
| Historical source anchors still present | 293 |
| Explicitly reconciled localized action anchor | 1 |
| Missing source anchors after reconciliation | 0 |
| Actual current native registry destinations | 10 |
| Current implemented Core action declarations | 21 |
| Current guide steps | 3 |
| Inspected native/portable UI test source files | 49 |
| Potential backend × ingress cells | 4,410 |
| Runtime executions claimed by this crosswalk | 0 |

TorahInspectorKit was inspected in its existing Oracle Git objects at
23db0f84e88d9ee9c7053c49de86903fc7bb5785. Sefaria Mobile was inspected
read-only in the prepared Scaleway Mac Git checkout at
2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c; all 45 Sefaria source rows still
have their original bytes. SEFARIA_PINNED_SOURCE_PROOF.json records their
Git blobs, SHA-256 values, paths, anchors, and observed source pin.

The single reconciled anchor is inventory.v1.workspace.profile.delete.
Its original Hebrew Button literal now uses
localized("Delete Profile", "מחיקת פרופיל") and retains its destructive
role. The original action, original anchor, current anchor, and matching
source line are all recorded; the requirement was not removed.

The upstream comparison uses the observed upstream commit
4203de5fd77beb119e5826e039be1a61325f7be0. Per-file path/byte comparison
does not constitute owner authorization or an upstream merge.

## What the route map actually establishes

| Mapping relationship | Original rows |
|---|---:|
| Root destination or canonical reader subset | 24 |
| Trusted original Core to original native route | 3 |
| System ingress definitions | 3 |
| Legacy URL handlers retained | 2 |
| Former future rows with current real infrastructure | 6 |
| No exact component route established by this audit | 256 |

The last number is **not a count of absent product features**. These rows
include existing controls, settings, RN screens, mutations that have
distinct original exposure rules, and originally inactive/decorative
entries. The original classification remains intact. A root screen,
containing context, or source anchor does not prove the requested
selection, focus, subsection, draft, or per-backend state.

Every row in CURRENT_CROSSWALK.json contains its original contract,
current source/Git provenance, route relationship, current Core action
declaration, related test source, literal identifier references when
present, and the three-backend/five-ingress matrix. Related suites and
literal references are labeled source relationships, not assertions of
exact-case coverage or test success. COMPONENTS.md provides a compact
human-readable index of the same 294 rows.

The previous 20 November reconciliation is historical. This snapshot
correctly recognizes these later implementations without upgrading
runtime acceptance:

- The real original guide runner and the Library → Search → History
  product tour now exist. Coaching still depends on native
  acknowledgement. Three tour steps do not establish complete guide
  coverage or three separate multistep model journeys.
- Hanlin currently declares four metadata read actions. The production
  binding conditionally adds search.query only through the original
  current-work consent. The nine transport name mappings are not a
  claim that all those tools are advertised or authorized.
- The iOS entitlement contains applinks:davidpovarsky.github.io, and the
  strict public-v2 HTTPS decoder exists. Origin/CDN HTTP 200, parser
  checks, and custom-scheme navigation do not establish actual iOS
  HTTPS handoff.
- The original Core has real search-results, note-draft, and commentary
  native paths. Their state, no-save semantics, and visible receipts
  still require the exact selected runtime cases.

## Original requirements that remain open

| Source task | Required completion beyond source presence |
|---|---|
| Sidebar 1220036734107652 | Original Library/TOC ownership and viewport; twenty direction-specific body/dot cycles in both languages; per-window query/scroll restoration; compact, rotation, resize, pointer and physical iPad acceptance. |
| Profiles/groups 1220103384037482 | Three profiles with at least three groups each; thirty-plus book tabs; original DuckDuckGo strip/grid and public ScrollableTabBar; independent duplicate-book locators; atomic migration, cold/per-window restoration, all management operations and 100 switches on the final source. |
| Safari Toolbar 1220036884173010 | Owner's continuous morph source, original CommandPalette and Gelatin motion only; canonical library query; original book/global search separation; focus, Escape, outside dismissal, 100-plus results, RTL, large type, narrow-window geometry and physical acceptance. |
| Native Side Sheet 1219643110971002 | Actual trailing system sheet in three detents, physical right edge in RTL/LTR, interactive reader behind Peek, original notes/TOC children, same owner during resize/dismissal, and physical device acceptance. |
| UI-03 1220542361203468 | Exact scene/state/component receipts, notes-screen regression, real setting subsection/control, selection/TOC/bookmark targets and cancellation/generation races. A Settings root is not a setting-control route. |
| UI-04 1220542420331748 | Actual App Intents, Shortcuts discovery, Siri, cold/warm/background lifecycle, multiwindow selection and stale/missing-source refusal for the requested destinations. Localized errors require Apple catalog/runtime verification in addition to portable state tests. |
| UI-05 1220542420330496 | Exact production HTTPS Universal Link OS delivery plus visible native receipt; retained legacy widget/history/annotation URLs; strict version, query and privacy boundaries; GET must not save. |
| UI-06 1220542467495722 | Existing SDK/Core only, live consent and honest foreground boundaries, actual multistep model journeys and semantic focus. The source map does not supply a live provider or remote-MCP acceptance result. |
| UI-07 1220542416158970 | Original 51 QA families and the three-backend/five-ingress requirements; exact state, security, cancellation, stale data, accessibility, RTL/English, keyboard, resizing, multiwindow, perf and physical iPad/iPhone results. |
| Batch B 1219848733895424 | Debug and Release, final integrated Native116 and Release114+2, production v40 assets/indexes and combined feature acceptance. miniTest10 does not satisfy production data acceptance. |
| Upstream audit 1220769157395027 | Current source-bound ownership/provenance/license review, including any changed protected hunk; authentic prior 55 owner signatures remain immutable evidence. |

The original Q-UI07-049 iOS 26 family is retained. The current app's iOS 27
deployment target does not satisfy that older requirement. No requirement
or case was silently removed.

Genuine VoiceOver speech tests remain required. An infrastructure failure
is not a speech PASS, and physical iPad/iPhone checks must be performed and
reported by the owner after beta availability. No device result is
claimed in this snapshot.

## Source-library provenance

The existing 32-row source-port provenance ledger is retained as its
historical reference. Twenty-four recorded port rows still have the
recorded destination bytes; eight have evolved. Current hashes and each
original adaptation reason are in the crosswalk. The evolved paths are:

- CommandPalette/Views/CommandPaletteView.swift
- StudyWorkspace/UI/DuckDuckGoTabsPort/TabsBarView.swift
- StudyWorkspace/UI/DuckDuckGoTabsPort/TabsBarCell.swift
- ToolbarSearch/SafariToolbarSourcePort.swift
- ToolbarSearch/LibraryCommandPaletteAdapter.swift
- ReaderHost/ChavrusaReaderHost.swift
- ToolbarSearch/ReaderToolbarActionAdapter.swift
- ReaderHost/ReaderOverviewPresentation.swift

These are current-versus-historical port observations. They do not
invalidate or replace later authentic source/hunk review, and they must
not be represented as 32 newly revalidated unmodified upstream files.
The original task's newer continuous-morph prototype is retained in the
task snapshot and remains part of the final provenance requirement.

## Narrow localization product change

Commit 4a04aeb208fd0e5408a2521f2757e97982bc258c wraps the ten existing
NativeIntentOutcome error descriptions in NSLocalizedString and adds ten
Hebrew catalog entries. All 671 pre-existing entries are preserved.
Status codes, eligibility, native acknowledgement, queued/background
semantics, and success handling are unchanged.

The original
NativeIntentServiceTests.testNoncompletionStatusesRemainDistinctSystemIntentErrors
passed on Oracle Swift 6.4.3: **1 test, 0 failures**. Full unabridged
log and exact command/source receipt are in validation/. This is a
portable regression of the original error/status behavior, not an
Apple AppIntentsTesting, Hebrew runtime, Simulator, VoiceOver, or device
result.

Source/Localizable.xcstrings is present in the actual upstream tree.
The new protected delta must be included in the real source-bound owner
gate. This change contains no generated owner signature or gate bypass.

## Reproduce on the final candidate

Run reconcile.py as the Git repository owner, with the exact final
source SHA, observed upstream SHA, the existing pinned Inspector Git
object repository, the retained Sefaria proof, and the exact task
snapshot. Use a new output path: the script refuses to overwrite
evidence. It fails if the original 294 IDs, exact dependency pins,
expected source anchors, actual registry shape, source relationships,
or declared test methods no longer match.

The snapshot's input source is intentionally explicit. A later merged
SHA requires a new crosswalk output; the old source evidence must not
be relabeled as final-candidate acceptance. New native UI05 tests and
their driver support are a separate subsequent change, outside this
snapshot.
