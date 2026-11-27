# Next typed Profile / Group selection contract

## Original source, not guessed protocol names

The actual original profile action is in `Source/ChavrusaText/StudyWorkspace/UI/StudyProfileMenu.swift`: choose the first group by its original order within the selected profile, then await `workspace.switchGroup(to:manager:)`. The original overview group/document actions also call that owner.

`StudyWorkspaceNavigationAdapter.switchGroup` captures outgoing tabs, selection, group, backend and generation; awaits the original target catalog; resolves/reuses/hydrates target Reader objects; then awaits `BackendCoordinator.commitCheckedAsync`. Its original beforeCommit performs the real Store transaction. Its original publish installs tabs, loads original content/TOC, calls the original selectTab, updates caches and publishes live mapping context.

`Source/LibraryBackend/BackendCoordinator.swift` preserves the original session snapshot rollback wrapper. For an already committed same backend, the actual implementation synchronously checks cancellation, flushes staged snapshots, calls beforeCommit, publishes, then clears pendingBackendID. For a changed backend, original participants may await preparation; the last throwing step is beforeCommit, followed by generation/defaults/backend publication, original participant publication, the app publish closure and one notification.

The base source pins and exact bodies are retained in `next-contract-source/`. This document is a proposal, not an implementation or executed acceptance.

## Bounded next implementation

1. Typed Profile and Group entities must come from actual original Store rows, owner/scene identity and original current mapping. A Profile entity resolves the original first ordered group at invocation; the exact chosen group and its ordering/membership must remain valid across preparation. Other profiles' target documents are not fully described by the current scene's mapping epoch, so retain an actual Store publication/snapshot revision (or a newly source-owned target publication contract), not final equality alone.
2. An opaque source-owned staged selection should be produced by the ORIGINAL adapter. Reuse/factor its existing catalog resolution, target Book identity checks, hydration/reuse, rollback and cache policy. Preparation must not publish a new visible scene or pretend to complete navigation.
3. Before every await, retain the actual source objects. After every await and at the actual committing boundary, validate the same scene/manager/store/native mapping, target membership/document identities, backend/generation, cancellation and original deadline. A failed/aborted backend transition, user selection ABA, target mutation, stale first-group ordering, scene replacement or reused prepared token must revoke the operation.
4. The canonical Core apply must consume the exact prepared owner and enclose the actual original Store transaction and native publication. It is not sufficient to obtain a grant before calling the whole async switchGroup method or to run a validation callback and publish after that fence has ended. Do not invoke another Core preparation after old authority is lost.
5. The smallest first implementation may be same-backend profile/group selection, with unavailable/capability restrictions stated explicitly. Even there, preserve the original BackendCoordinator snapshot rollback/flush; a direct Store/manager assignment would bypass the original owner.
6. Cross-backend selection needs the original participant staging and rollback plus a legitimate current commit contract for backend/generation changes. The native publicV2/generic root protocol and backend-switch statuses remain unchanged. No automatic backend switch may be inferred from a stale typed tab or navigation-only grant.
7. A typed success must be the same original canonical receipt plus independent original visible group/profile/Reader evidence. Empty-group, restored loaded Reader and deferred content-load cases need separate truthful completion surfaces. A model header or Store update is not visible completion.

## Proposed file lease

- New distinct Host service/AppIntents and Integration owner binding/policy files.
- The original adapter's bounded switchGroup staging/commit factoring, with old UI callers continuing through the same implementation.
- A minimal original BackendCoordinator prepared-commit seam only after root/Wave2 source review. The session snapshot rollback and original participant order are mandatory dependencies.
- Narrow Session and Composition entry/completion hooks, coordinated with their owners; root owns Composition/PBX/catalog merge.
- No Search/Library engine, original SDK/pin, cloned view, owner registry or public URL schema changes.

## Required meaningful controls

Exercise the original Store/persistence and source-owned stage/commit bodies: cancellation before/after catalog preparation, target removal/move/reorder and ABA, scene/manager/Store replacement, aborted backend transition, foreign selection while awaiting, original first-group rule, duplicate-book documents, Store failure preserving outgoing state, one-use prepared token, expected outgoing save and incoming restoration, actual publication order and cleanup without a new grant.

Native selectors must invoke the original system AppIntent path with real original UI-created profiles/groups/tabs, observe real persisted workspace and original UIKit/TextKit completion, and verify same/cross-backend failure statuses honestly. Source controls must retain explicit Apple/runtime boundaries; native tests remain pending a qualified full app.
