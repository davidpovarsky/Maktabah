# Original compact Reader owner integration

Status: source implemented; actual Apple app/SDK and Native acceptance pending.

The phone already had a scene-lived StudyWorkspaceNavigationAdapter in CompactStudyWorkspaceHostModifier. The original adapter and store are retained. Its existing state is now held by the same fixed MaktabahNativeWorkspaceOwner used by native routing, and passed through the existing lifecycle environment. The iPad keeps its own original owner. No additional adapter, session file, navigation stack, ReaderViewModel, Core or permissions engine is introduced.

The native host waits for the original compact adapter to attach. The actual existing NavigationStack reader destination gets the same passive NativeSurfaceWitness as iPad. The existing title action gains a stable accessibility identifier; its original overview and tab-selection callbacks remain unchanged.

Three phone Native scenarios use the same strict real-source oracles as iPad: two exact current-book lines, a new other-book tab with all old identities preserved and native overview return to the old exact locator, and rejection of cross-book sameTab without acknowledgement. Original53-case manifest groups:42 reader,2 window,9phone. These are source plans, not execution.

The original27 interaction/Sidebar method source is unchanged. Full-Code ownership/grant/TextKit completion fences from the preceding new-tab implementation remain required. There is no fake native result from a workspace model, receipt log alone, tap transport or source compilation.
