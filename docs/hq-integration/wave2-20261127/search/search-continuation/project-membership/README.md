# Reviewable Xcode membership proposal

**Status: prepared locally; not applied to an integration checkout.** Wave3 remains the project-file owner. This artifact makes the required three-file membership change concrete without writing to Oracle Data, changing a shared worktree/ref, or modifying Swift source.

## Exact base and patch

| Item | Identity |
| --- | --- |
| Baseline commit | `15d283aa0ccbbfe6966f26a2c182810cb39fdafa` |
| Project path | `Maktabah.xcodeproj/project.pbxproj` |
| Original Git blob | `24ab48b84d61fe4bae88eb41c53506664db44701` |
| Original bytes / SHA256 | 630,804 / `db527467c59ac351b1db13b7208fe4f7f89da089916978302c2d55e68b42b2ee` |
| Proposed bytes / SHA256 | 633,004 / `60dc6ba2751d84604cc352e670472f7e5cc76763592355b6ebbbd5eb40d1afdf` |
| `membership.patch` bytes / SHA256 | 5,239 / `55ddca42c82e34881a0ef5e5277b12425e1704c50fe6428d49193e55363ae7ce` |

The original blob was read through the existing Oracle Git mirror and transferred as an in-memory compressed stream. Its full uncompressed hash was verified locally. No temporary file, checkout, source, pack, ref or evidence was written on Data.

## Required target mapping

| New app file | `Maktabah` | `Maktabah-Direct` | `Maktabah-iOS` | Reason |
| --- | --- | --- | --- | --- |
| `Source/ChavrusaText/SearchContinuation/OriginalSearchPageLedger.swift` | Add | Add | Add | Its existing callers `SearchViewModel.swift` and `Search+Execution.swift` are already compiled by all three app targets. The ledger itself uses Foundation. |
| `Source/ChavrusaText/SearchContinuation/OriginalSearchContinuationClaim.swift` | — | — | Add | Its actual app consumer is the iOS continuation binding. No desktop caller is added. |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchContinuation.swift` | — | — | Add | The whole integration source is guarded by `#if os(iOS)` and its original List/Unified/native-entry callers are iOS members. |

The exact original membership was resolved through file-reference and build-phase IDs, including parent group paths:

| Existing caller | Actual baseline app memberships |
| --- | --- |
| `SearchViewModel.swift`, `Search+Execution.swift` | `Maktabah`, `Maktabah-Direct`, `Maktabah-iOS` |
| `OtzariaTextSearchViewModel.swift`, `ZayitSearchViewModel.swift` | `Maktabah-iOS` |
| `UnifiedSearchSessionController.swift` | `Maktabah-iOS` |
| `SearchResultsListView.swift`, `SearchModeView.swift` | `Maktabah-iOS` |
| `MaktabahNativeSearchEntry.swift`, `MaktabahNativeSceneBindings.swift` | `Maktabah-iOS` |

`MEMBERSHIP_MANIFEST.json` contains the complete canonical paths, original reference/build IDs and new per-target IDs. The observed delivered-source hashes identify the local source snapshots inspected for this proposal; the final feature commits remain the authority for delivered Swift bytes.

The two package sources remain SwiftPM-owned and receive no app file/build references:

- `Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionSearchContinuation.swift`
- `Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSearchContinuationService.swift`

The original package manifests declare the corresponding targets without explicit source lists. Their existing Sources directories therefore own those additions; this proposal does not alter package references or linkage.

## Minimal graph changes

The patch adds **8 objects**: three `PBXFileReference` objects and five `PBXBuildFile` objects. It appends three children to the existing ChavrusaText group `CFEE00000000000000000001`, using paths relative to `Source/ChavrusaText`.

Only these source lists change:

| Target | Sources phase ID | Original → proposed entries |
| --- | --- | --- |
| `Maktabah` | `4B3202242EDAFE85003B95D1` | 358 → 359 |
| `Maktabah-Direct` | `4B7C90A52F83494200454BE1` | 358 → 359 |
| `Maktabah-iOS` | `F30576E22FA46222005732C6` | 580 → 583 |

All test and widget targets remain identical. Build configurations, SDK/platform settings, frameworks, resources, package references, shell phases, existing object definitions and the ordering of all existing list entries remain unchanged. The five inherited duplicate dictionary keys are preserved, not repaired here.

New object IDs are deterministic: the first 24 uppercase hexadecimal characters of SHA256 over the recorded namespace, object kind, canonical path and target. They were checked for collisions with every original object and the original project text. `INSERTIONS.json` records the six exact insertion positions and blocks; removing those blocks recovers the original bytes exactly.

## Verification actually performed

The repository's unchanged `docs/hq-integration/verify_source_registration.py` parser and `target_sources` function were reused from the exact baseline. Parser SHA256: `eff5cf3c0935562f9e9b1bbcd296f192c4daf2922cc9185d8fa5ad0ab3246a18`.

The local preparation verified that the proposed OpenStep graph equals exactly the original graph plus the eight declared objects and four permitted list changes. It also verified each new reference resolves to exactly its requested canonical path and appears once in each intended target, and nowhere else.

`PATCH_CHECKS.json` retains four actual local Git operations, each exit 0:

1. `git apply --check` against an isolated copy of the original blob.
2. `git apply`, producing the exact proposed hash above.
3. `git apply --reverse --check` against that local postimage.
4. `git apply --reverse`, restoring all 630,804 original bytes exactly.

This is **project structure and patch applicability evidence only**. No Xcode parsing, Swift/SDK compilation, linkage, app launch, Simulator or UI acceptance was performed. The original full project-validation CLI was not misrepresented as an app check against a partial local source tree.

## Application by the project owner

The owner should compare the current project blob with the recorded base before applying the proposal. For an exact match, `membership.patch` is ready for the owner's usual `git apply --check` and application. If Wave3 has changed the project meanwhile, preserve those changes and reconcile only the declared additions against the current graph; do not replace the project with the full proposal file or reset it to this older base.

After ownership-safe application, qualify the combined feature's original targets and native behavior using the final source/build. This artifact does not request a new user approval and does not claim that owner application has occurred.
