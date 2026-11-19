# Source-backed commentary action — 2026-11-20

## Scope and authorization

This is an isolated downstream change for ACTIONCORE (1219614315863536) and SEARCH-API (1219614472017979), following the owner's explicit authorization to implement, test, commit, push and integrate the outstanding Otzaria work. It does not close either task by itself.

Base: `508d15149b5c1ba0d9949279755ba286fd57a138`.
Branch: `codex/otzaria-actions-completion-20261120`.
Original Maktabah upstream HEAD read during this work: `d46af139b3a265399c16d87f5923acd8e3444024`.

AGENTS.md, PROJECT_AGENT_GUIDANCE.md, UPSTREAM_INTEGRITY_POLICY.md, the relevant exception register and legacy-debt boundaries were read. `git ls-tree -r --name-only` at that upstream pin returns no files under the changed Otzaria Actions / Chavrusa native-routing directories. All implementation changes remain in these downstream owners; no original engine, renderer, note store, database, upstream pin, package producer or signing configuration is changed.

## Implemented behavior

- The existing `reader.openCommentary` descriptor now has a source-backed implementation in the same ActionExecutor and CatalogActionResolver. The frozen 29-action wire catalog is unchanged.
- The optional commentary data port calls the original BackendCoordinator.links provider, uses the original inspector relationship classification, and reuses ReaderDestinationResolver for bounded section and exact focus. It projects identity/title metadata only, excluding provider text and translation.
- The resolver proves the base locator, catalog membership, linked work and selected target/focus against the original data port within the same backend generation / Embedded RPC epoch. A matching catalog title cannot create a missing relationship. Names use the same conservative source normalization and aliases as existing resolution.
- Missing links return not-found. Multiple distinct linked passages remain bounded ambiguity. Duplicate identical links deduplicate; conflicting destinations, foreign or unknown works, substituted proof, missing focus, oversized source payloads and changing generations fail explicitly.
- Catalog-name matching scans the catalog once per resolution. Relationship and candidate caps are explicit; a capped prefix is never promoted to a unique result.
- The action opens the linked commentary through the existing new-tab reader reservation, preserving the base reader. Core still validates the exact destination and produces its original one-use navigation preparation and reader command; completion requires the exact original scene/request/backend/section/focus receipt.
- Native Composition adds a local `openCommentary(..., manager:)` entry. It captures the existing live source observation, resolves in the same Core, then uses the same order as public native reader navigation: retain the original reader owner, issue/admit context, bind through the Registry, mint the Core grant, commit and observe the real reader. Cleanup belongs to the original scene owner after Core returns.
- The preparation seam is opt-in. A Core without both a commentary resolver and a commentary-aware original UI sink cannot advertise or execute this action. Backend support requires both registered navigation and original links providers. Existing initial-five callers and sinks remain source compatible.

## Validation and evidence

The portable Swift package was built and tested on Windows with Swift 6.3.3, using the installed toolchain and `swift test --package-path Source/Otzaria/Actions --jobs 2`. Both the initial execution and the final execution after the catalog-scan improvement passed **86 tests, 0 failures**, including **19 new commentary tests** and the existing resolver, policy, engine, wire, deadline, generation and receipt regressions.

- `portable-swift-test-initial.log`: complete initial run.
- `portable-swift-test.log`: final run after the catalog-scan improvement.
- `portable-result.json`: exact final command, exit code and Native status.
- `git diff --check`: passed before commit.

The new tests use explicitly labelled source-shaped fixtures. They prove portable contracts, not actual production DB contents, Apple framework compilation, native rendering or model behavior.

## Remaining acceptance

**Native / Apple compilation and runtime for this change: NOT_RUN in this isolated worktree.** The manager owns the single integrated Native matrix and will verify the actual app compilation and runtime. This work did not dispatch a Native workflow independently.

The local native entry is implemented; no new Hanlin tool, external transport, content-read grant or UI button is exposed here. Hanlin stays with its separately integrated metadata/navigation contract. Real model-to-Core-to-native commentary journeys still require an authorized transport integration and observed native evidence.

`search.openResults` and `notes.prepareDraft` remain unimplemented and unadvertised. They need faithful bindings to the existing search-session semantics and the original selection/source-bound note editor. There is no new search UI, parallel agent, note store or automatically saved note.

`search.countOccurrences` remains explicitly unsupported with `exact_count_unavailable`. Search hit/document totals were not reinterpreted as occurrence counts.

No Asana completion flag was changed. No production data was duplicated or modified. No release or physical-device acceptance is claimed.

## Review and rollback

This is a sole-developer source review. The main integration owner reviews the concrete diff; independent review is not claimed. Re-review the narrow native preparation seam on the next routing/authority or upstream synchronization change.

Rollback is a revert of this isolated source commit and its evidence. It removes the additive commentary ports/action/binding without touching existing source data or original reader behavior.
