# Original Profile / Group selection: implementation lease proposal

Status: independent source review and design only. No product change, compilation, native invocation, or acceptance run was performed for this proposal. This design is bound to root `eb532ccad28ec78d456fba8c5064abf9c9fdfecc` and peer Reader-tab source `1d6a8e00a8f9f073f69cd5b53a34ccde6c3eca5d`, with its next-contract document at `fe4db3f9c88658af0cd43be256574bd6005aca2d`. Implementation must start from root's subsequent integrated Reader-tab commit, preserving that actual adapter and Session merge.

## Decision

Implement selection within the already committed, currently active backend. A selected profile resolves its actual first group using the original `filter(profileID).sorted(order).first` rule. A target whose original remembered/first document requires another backend returns the existing truthful unavailable/backend-mismatch outcome before catalog preparation, Reader creation, persistence, or selection. It preserves every saved document and the current backend, group, Reader and UI.

This is the original requirement, not a new capability reduction. Fresh task `1220103384037482` still says not to silently switch Sefaria/Otzaria for profile selection and to preserve an unavailable group's saved tabs. Its notes were last modified on 2026-11-26; no replacement of that requirement appeared in the latest returned comments. UI-04 `1220542420331748` requires original registry/executor, stable qualified entities, real foreground UI and honest noncompletion outcomes.

The current original UI has a source-visible gap: `StudyProfileMenu` selects its first ordered group and invokes `switchGroup`; that adapter derives `desiredBackend` from the saved active/first document and can call `commitCheckedAsync` for a different backend. There is no explicit backend-choice dialog at this profile-menu call site. Thus the reachable source path conflicts with the still-current no-silent-switch requirement. This has not been reproduced natively. The same shared guard also protects the group selector. Preserve the separately requested, explicit BackendCoordinator switching workflow and startup restore; do not replace either with an intent-specific backend switch.

## Why the original asynchronous call cannot be wrapped directly

`NativeSceneDriver.apply` is synchronous. The actual orchestrator consumes Core's one prepared authority immediately before that synchronous effect, then waits for independent native evidence. `ActionNavigationPreparation` requires the same backend snapshot at authorization and completion. The orchestrator also compares the final backend to the invocation snapshot.

An `async switchGroup` launched from a synchronous Boolean adapter would execute after that fence, and a cross-backend change would invalidate its original grant. A new context after the switch would be a different operation, not completion of this command. The catalog entry `system.selectBackend` is a declared foreground-gated request; its presence is not a usable profile-selection grant. No Core or public URL schema change is proposed.

## Keep the original stage and commit owners

The existing original sequence is:

1. Capture the outgoing tabs, active tab, group, backend, generation and scene selection; set the original busy state.
2. Resolve the chosen group/document and desired backend. Enter the original `withTargetCatalog` scope. Resolve every document through the original resolver; reuse exact cached/live Reader objects where valid and call original `hydrate` only for cold documents.
3. Use the original coordinator snapshot rollback boundary. Its same-committed-backend terminal path checks cancellation, flushes staged snapshots, performs the Store transaction, publishes the native tabs/Reader selection/cache/live context, and clears pending backend state.
4. Persist the original current session and release the original busy state. Native visibility is then an independent bounded completion check.

The proposed source-owned object is an opaque, one-use prepared group selection. It contains the actual staged ReaderTab objects and source metadata, not another workspace model, resolver or serialized permission. The public payload can only name a discovered original profile/group entity. It cannot supply callbacks or construct this object.

### Proposed exact synchronous commit seam

Names below are proposed API names, not claims about existing declarations.

- In `BackendCoordinator.swift`, factor the existing six-statement same-backend terminal body into one private throwing synchronous helper. The existing `performTwoPhaseSwitchAsync` same-backend branch calls that helper.
- Add `commitPreparedSameBackend(expectedBackend:expectedGeneration:beforeCommit:publish:) throws`, guarded by `activeBackendID == committedBackendID == expectedBackend`, unchanged generation, and no transition. It uses that same helper inside the original snapshot rollback implementation. It returns no success Boolean.
- Extend `BackendSnapshotStaging` with a synchronous throwing rollback scope. `BackendNavigationAdapter` supplies it by sharing the exact original begin/success/restore primitives with its existing async wrapper, using the existing lock and original bytes/missing-file representation. Do not duplicate rollback algorithms or provide a no-op default conformance. The checked repository contains one production conformer.
- The existing changed-backend participants, preparation order, cancellation/token checks, flush, final throwing Store boundary, defaults/generation publication, notification and completion path remain in place. The new entry cannot reach them.
- After the original flush, revalidate the retained scene/target/source and canonical command before the Store write. Flush and source callbacks can synchronously reenter. Consume the prepared owner once; reject duplicate or nested use.
- Close the snapshot rollback scope when the synchronous original commit finishes. Do not enclose the later native visibility wait in it. Otherwise a missing UI witness could roll backend session files back after the Store and visible model were already committed.

The original synchronous `commitChecked` is insufficient: it does not contain the async same-backend flush/beforeCommit/publish body or its rollback wrapper. Calling it would omit original effects.

## Adapter factoring and original UI correction

In `StudyWorkspaceNavigationAdapter.swift`, factor the current catalog/reuse/hydrate stage and the existing beforeCommit/publish closures once, with old UI callers continuing through the same original implementation. Preserve the startup adoption of live tabs that arrive while an initially empty restore awaits its catalog. Preserve the original outgoing `capture` at the last committing boundary, including current viewport/selection, rather than saving an older preparation-time viewport.

The intent-facing preparation retains its original source before the first await, rejects a backend mismatch immediately, runs the original target-catalog stage, and validates the same source afterward. It reserves the exact next original native ownership epoch before the initial Core admission. It never admits once before staging and admits again afterward.

The canonical driver's synchronous apply invokes the prepared original owner through the checked same-backend coordinator entry. Original `manager.selectTab`, the empty-target `closeTab` loop, cache updates, `setMappingLiveContext`, and session persistence stay authoritative. No direct replacement of `selectTab`/`closeTab` with hand-written assignments is allowed.

Factor the existing first-group expression into one original owner helper, reused by `StudyProfileMenu` and entity resolution. Retain its chosen group, profile and order/membership before suspension. A reorder/delete/move during preparation revokes that selection; do not silently choose a different group after the await. Existing group orders are not validated as unique, so do not introduce a different tie-break rule without a separate model decision.

For the UI regression, reject a derived backend mismatch through `StudyWorkspaceError.backendMismatch` at the shared original selection owner before staging. The existing menu/overview catch already shows `workspace.errorMessage`; that localized error says to switch to the matching library source. Do not delete foreign documents, select a different same-backend document as a hidden fallback, or convert an unavailable nonempty group into an empty group.

## Retained source and one-use publication policy

The incoming Reader-tab reservation cannot be reused unchanged: it permits one active-tab change inside the same group. Group selection legitimately changes stored scene/profile/group, native tabs and Reader ownership. Introduce a separate mutually exclusive group-selection reservation that uses the same original producer hooks and preserves both existing Reader reservations.

Retain:

- Exact scene lifetime, manager, authoritative workspace owner, adapter and Store objects; actual original native/store mapping sources and their epochs.
- Original selected profile/group; the selected target profile and group; original first-group ordering when selecting a profile; exact ordered target documents, saved active-document rule and backend-qualified identities.
- Actual Store publication history. The current mapping source omits inactive group content and ordering; final equality or the current scene epoch alone misses target A→B→A. Before commit, the original monotonic snapshot revision is sufficient for fail-closed detection, including otherwise harmless checkpoints.
- Original backend/generation and one-way backend publication invalidation; original scene/root selection, Settings, mode and selected-book publication metadata; original modal/editor/overview state and lifecycle. No clearing unrelated Settings, sheets, drafts or selection to manufacture availability.
- Exact cached/live Reader object identities. For an already loaded target, retain its original content-request token and destination. For a cold target with a saved qualified locator, original `loadBackendContent` creates its token synchronously before its Task; bind that exact issuance during the original publication, then require the same token/Reader/work/destination at final TextKit evidence.

The reservation declares and consumes the exact original publication steps. It must distinguish Store publication, native `openTabs`, active selection, selected-book publication, and live group/backend context; the empty-group original close loop is a finite planned sequence, not a blanket “applying” exception. Repeated/equal/reentrant or foreign publications revoke it. Overflow is permanent refusal. No one-shot observer is reset after an owned effect.

A minimal passive Store publication hook may be needed in `publishSnapshot` for target-specific post-commit history: callbacks receive actual before/after snapshots at the original publication boundary, including changes with no current-scene mapping reason. The original save order and mutation semantics stay unchanged. The policy can consume its one known selection transaction and reject target order/membership/selection ABA through completion. Do not blindly exempt all later checkpoints. If legitimate original checkpoint publications must remain admissible during the UI wait, identify them by their real original owner and exact compatible source projection; never replace that check with final snapshot equality. Keep this hook narrow and independently reviewed.

Any failure after a durable Store/native effect is potentially uncertain. The original orchestrator already records dispatched effects as uncertain; do not claim no effect or attempt an unowned compensating Store/Reader rewrite. A rollback of backend snapshot files does not imply rollback of the workspace Store.

## Native completion and explicitly remaining work

Use a finite private route, proposed `native.workspace.selection`, with a trusted typed record and exact target profile/group state. Generic publicV2 remains unchanged. Separate thin `OpenStudyProfileIntent` and `OpenStudyGroupIntent` share the original service/registry/orchestrator; identities include the actual scene and backend plus original stable UUIDs, with profile/group titles for ambiguity. Re-resolve cached entities from the live source.

Completion must distinguish:

| Original result | Required actual witness |
| --- | --- |
| Reused loaded Reader | Same original Reader object/token, selected tab/group/profile and original native marker plus TextKit/viewport evidence |
| Cold qualified Reader | Same newly hydrated original Reader and the exact original load token, successful original content state, then actual native/TextKit evidence |
| Empty iPad group | Original `iOSReaderTabView` empty branch, same visible window/geometry, no active tabs or selected book, and exact selected profile/group |
| Empty iPhone group | Original Viewer NavigationStack's library after the original close loop removes its selected book, same actual library witness and exact empty-group ownership |

An empty group must not pass a content Reader witness. The current `.reader` projection requires an actual nonempty Reader and returns nil for the empty branch. A passive original-empty-branch hook (or an exact existing empty-root witness with source-bound projection) is therefore necessary. Do not use a model header or an invisible overview as its proxy.

Two boundaries remain explicit rather than being assumed solved by the first source packet:

1. Original `loadInitialContent` for a legacy cold session with no saved qualified locator enters a Task before issuing the actual content-request token, and may await recent history/navigation resolution. It cannot be admitted by merely sampling the first later token. Either a narrow original issuer/lifetime hook is separately coordinated with the Reader owner, or that exact legacy case remains unavailable/open until implemented. Qualified cold sessions and already loaded original Readers do not need a replacement resolver.
2. Starting selection from a different global page requires original Viewer parent selection and mode publication before the original phone `selectTab` assigns `selectedBook`. The first minimal selection packet may truthfully require the actual Viewer root, as the current Reader-tab slice does. Closed/background activation of that exact existing window is still supported. UI-03 “from another page” remains open until a bounded original-parent continuation under the same retained Core request is implemented; no extra synchronous `switchToMode`, fallback root, or renewed grant should be slipped into this selection change.

These limits must be stated in entity availability and the acceptance report, not labeled completion of all profile/group or cold/closed UI requirements.

## Proposed source lease

| Path | Proposed scope |
| --- | --- |
| `Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift` | Original staging/commit factoring, mismatch guard, new mutually exclusive group reservation and exact original producer hooks; preserve integrated Reader-tab owner |
| `Source/LibraryBackend/BackendCoordinator.swift` | Shared same-committed-backend synchronous body and checked entry; protocol synchronous snapshot scope; changed-backend path preserved |
| `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift` | Share exact rollback begin/success/restore primitives between async and synchronous scopes |
| `Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift` | Only if needed: passive original snapshot publication observer for target order/content ABA; no persistence/mutation rewrite |
| `Source/ChavrusaText/StudyWorkspace/UI/StudyProfileMenu.swift` | Reuse the original first-group helper and source-owned profile selection call, preserving menu/UI |
| New downstream reservation, Integration binding, Host service/Intents/tests | Finite typed selection, original source metadata and canonical route only |
| `MaktabahNativeSceneSession.swift`, `MaktabahNativeSceneProjection.swift` | Narrow private route/actual original completion dispatch, after root's Reader-tab merge |
| `Source/Features/Reader/iOS/iOSReaderTabView.swift` | If needed, one passive marker/identifier on the existing empty branch; no replacement view |

Root retains Composition, PBX and localization integration. No Source files are leased by this document alone. No changes to Core authorization, public URL schema, library/search engines, original SDK/source pins, owner signatures, or existing acceptance assertions are proposed.

## Meaningful validation required after authorization

Use actual original Store/persistence and original stage/commit bodies; preserve baseline failures and label any Apple/UI boundary doubles. Necessary controls include original first-group selection; mismatch before mutation; target reorder/delete/move/ABA; source/window/backend transition during catalog await; late cancellation; cached/live reuse versus cold hydration; duplicate books with distinct tab IDs; one-use stage; exact expected original Store/native setter sequence; reentrant/equal publication; flush failure; Store save failure with exact snapshot restoration; snapshot restoration failure; cancellation after dispatch retaining uncertain-effect evidence; empty-group original close effects; loaded and qualified cold content-token replacement; overflow; and release/deinit cleanup.

Prove callback order from the actual implementation. Revalidate after flush and before persistence. Retain the original same-backend/cross-backend coordinator tests unchanged where possible, and compare extracted/factored original bodies to the pinned baseline. Do not rerun unrelated broad suites solely for this design.

Native selectors later must create/select actual profiles/groups through original controls, invoke the genuine system AppIntent, and require exact persisted scene/group/profile/tab ownership plus a fresh same-request native receipt and actual visible original completion. Test stale cached entities, foreign library refusal preserving data, current/other window, background activation, empty, duplicate-book, warm and qualified cold targets. All native cases are NOT_RUN at this design stage.

## Source pins and review boundary

The initial eleven-file inventory is `SOURCE_INPUTS.json`. Key baseline pins: adapter `2ffe663ce8f64a435aaa88f2acab23a8869c6cadbd4af006b4bda6d74cd2db3c`; coordinator `b67742f249c0f4ad4ed8e0a5fac1b45b7936bd726655ed034ac35664e3d0f955`; Store `b0339b0b636290daa6a9e88bd00d4e694cba9fac48e4273620b0d772dcb1e7ba`; snapshot adapter `f201af68a761d520529f844899720c67603a3cc50b0b4c641259145bcf791bb6`; Core preparation `89af621942e11b74290633f0562f5451ae7dba73530dbc2a0b4b6b7555d182ae`; native orchestrator `e05faf57856de89a9a88017f400ea67ce461e782b2ffd284f069dd93bf1cff0c`; empty Reader view `eee8aa3febd604409589dfc0330a59df0100a5aee9ed77d97eeb86b3022ff66e`.

Navigation peer independently agreed that the proposed same-backend entry is the smallest safe identified seam and emphasized post-flush revalidation, exact first-group retention, one-use Store/native publication allowance, and ending rollback before the UI wait. That is source/design review, not compilation or native acceptance.
