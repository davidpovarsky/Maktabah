# Original Workspace presentation bindings ? Wave 3

This packet connects the existing study profile and tab overview UI to the public native routing pipeline. It depends on the shared bounded render source (49e334a96cdd336e331650ad755e607908256e84) and the shared Workspace parent integration (26ebcfe9f264a7513b46049417bc2dd1bf510848). It does not change that pipeline, the PBX project, SDK inputs, owner approvals, or the Native116/Release114 selections.

## Original ownership

The iPad profile parent uses Exact9401ViewerToolbar's original showsProfiles binding. The iPad overview uses ReaderSidebarPageCoordinator.overview. On iPhone, CompactStudyWorkspaceHostModifier owns the original showsOverview binding; StudyGroupsOverview owns its nested showsProfiles binding. The exact original session is forwarded through ReaderOverviewPresentation's existing hosting boundary. No global scene lookup or replacement sheet is added.

StudyProfileManagementView keeps its original NavigationStack, List, editor and confirmations. Its existing groups destination is represented by a finite path so component reveal can use that original owner. Group rename state is held once by the original management parent and passed to its original child as Bindings; draft/save/cancel behavior is preserved. Revealing New Study Profile scrolls to its existing control without activating the editor.

The overview keeps TabSwitcherPageHost, ScrollableGroupsHost, StudyProfileMenu and its existing toolbar controls. Grid/List routes describe the currently selected original layout and require actual tabs. They never write AppStorage or activate the layout toggle. The native tests switch modes through the real original toggle. The phone profile-menu control remains subject to actual UIKit visibility; its secondaryAction placement needs native validation.

## Retained source and presentation lifetime

The parent captures the actual authoritative workspace source, original store/native mapping epochs and owners, backend identity/generation, and a one-shot Observation/backend invalidation latch before any await. Components reuse that same proof. Parent apply is called once from the canonical commit. A first cold original host can attach only after that exact committed request; replacement or independent mounting invalidates the proof.

Original State setters notify synchronously before changes. Private exceptions cover only the exact original parent/navigation setter invoked under the retained request and original deadline. No observer is rearmed or source recaptured. Sidebar request identity/state changes have synchronous observers; geometry lifecycle updates do not masquerade as user changes. The phone apply invokes the captured original overview setter directly, preventing a later manager.onChange from consuming expired routing authority.

Original UIKit hosts retain binding/kind/workspace/manager/State-owner/controller identity. Their passive witnesses report appearance, window, clipping, visibility and transitions. Geometry notifications are deduplicated. Unexpected disappearance, interactive dismissal, replacement and detachment invalidate proof. Only expected same-command coverage of the original parent is permitted. Weak proof observers also invalidate completed component proofs retained for guide validation after public release.

Profiles groups/list continuation waits for strictly newer actual page appearance/layout under the shared bounded render contract. It does not use delay, polling-generated geometry, extra grants or a synthetic success marker. Existing unsaved drafts/confirmations block navigation.

## Validation status

Seven final Swift inputs passed iOS27 frontend syntax. This is syntax only: it is not SDK type checking, a native test result, source admission, an owner signature or release acceptance. Exact input/receipt hashes are in VALIDATION.json. The original full qualified Debug driver at control6935 / product64c1e74a is currently blocked by a missing original retained Anytype ABI subtree; its FAILED result and raw evidence are preserved separately. No gate was weakened.

Shared integration 26ebcfe9 was cross-reviewed for parent-before-component retention, exact owner forwarding, single canonical apply, destination-specific readiness and independent root/control receipt checks. Its native selectors remain unexecuted on this packet. Full app compilation and original native iPad/iPhone acceptance remain required after integration/source admission. Real owner review is required for changed source, including the two iPadLayout session-forwarding lines.

## Scoped files

Two new downstream adapter/component files, five existing original view/owner hook files, and this evidence directory. iPadLayout changes only read and forward the exact session; its TOC selection code is untouched.
