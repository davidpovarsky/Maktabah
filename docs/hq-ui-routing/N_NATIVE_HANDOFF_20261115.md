# N native host packet — 15 November 2026

This is an implementation and integration packet, not UI03–06 acceptance. UI03–05 remain OPEN and UI06 retains its accepted-SDK/UI dependency blocker.

## Source and composition

N's assigned worktree/branch is unchanged. The manager explicitly authorized consuming P `065148d3662b5322bdd5dea038405079cd3a66c3` and coherent base `fe6f5fe5126a964bd76d3f308489e131a491fe36`; both were merged while preserving N's own uncommitted work. No P/S/I/R/U/D file was corrected by N. The current factory uses **ActionLiveBackendBridge.shared**, I's CatalogActionResolver and exactly one ActionExecutor, with N's separate native context/lifetime authority injected once. No backend snapshot is issued by N's authority.

The downstream orchestrator calls P's one-use `UIAuthorizedSceneCommand.authorizeCommit` immediately before the synchronous existing-native binding mutation, without an intervening await. It reobserves the exact scene and canonical backend after actual destination layout, validates the complete receipt, and rechecks native lifetime/context/revocation. A dispatched action without a validated completion returns effect uncertainty, with no claimed rollback or automatic replay. Content requires the exact Core-delivered reader command/preparation; bare decoded content cannot enter the native sink.

Native request admission is one current trusted context per scene, bounded scene/observer/mount-wait admission, a finite native dispatch association ledger, cancellation-cooperative deadlines and observer cleanup. Intent entity IDs bind backend **and actual scene**, so two windows with the same backend cannot be silently conflated. URL entry before mount waits only for the exact existing navigation-manager instance's UIKit session; it never chooses a foreground/global alternative.

## Actual first installed native surfaces

The concrete app driver mutates only the existing History tab and existing Settings sheet bindings. History's unfiltered root is the initial public URL route; Settings root is available through the foreground intent. No reader/tab/selection/Inspector/TOC/search/Notes/control-focus variant is advertised by this first driver. Their metadata/projection code is not installation or acceptance. The initial mounted host requires the actual iPad workspace attachment; iPhone remains unavailable until its exact workspace owner is exposed. Legacy history/annotation widget URLs retain the original handler. There is no Universal Link configuration.

The native view witnesses are inserted into the actual History list and Settings form background; they check the containing UIKit session, foreground state, native bounds/visibility and modal ancestry. Requested state is never the observation. Only after canonical full receipt validation does the application append a privacy-limited NativeNavigationReceipt line to its existing reader log (request/scene/backend/generation/epoch/revisions/destination/presentation; no query/note/selected text).

## Reviewable registration

Manager remains sole writer of shared target/package membership and protected native source hooks. N has edited none of those files. Reproduce proposals with `py -3 docs/hq-ui-routing/N_make_registration_patch.py`:

* `N_PROPOSED_PACKAGE_REGISTRATION.diff`: one local host package/product/Frameworks link, and seven additive app Integration files. Core/UIRouting products remain the manager's coherent registration. Maktabah-iOSUITests is already a PBXFileSystemSynchronizedRootGroup, so the new five-method XCTest file needs no fabricated explicit source entry.
* `N_PROPOSED_NATIVE_HOOKS.diff`: five narrow hooks in original MaktabahApp.swift, iOSMainView.swift and iPadLayout.swift: process AppIntent dependency registration; scene-lived modifier; existing URL handler dispatch; two real native surface witnesses. Existing Settings/History UI and WidgetDeepLink implementations are preserved.

Both diffs pass `git apply --check` against the coherent base. They are unapplied proposals; rollback is their reviewed reverse diff or isolated downstream revert. Protected source provenance remains the upstream Maktabah UI foundation, pinned remote upstream d46af139b3a265399c16d87f5923acd8e3444024. The wave's explicit minimal downstream connection authorization and manager review govern application. No release, lock, entitlement, signing or automatic trigger change is proposed.

## Validation truth

The native host package has 49 named portable XCTest methods passing with strict concurrency, including eight actual-Core/orchestrator regressions and exact-window intent resolution. These use synthetic native drivers/authorities and cannot prove UIKit visibility. Logs retain a prior test-fixture failure: a wrong destination was changed before the final guard, which correctly returned pre-dispatch stale; the fixture was changed to perform that wrong native presentation after dispatch so it exercises receipt rejection. No assertion was weakened into success.

Five canonical XCUITest methods were added in NativeRoutingAcceptanceTests: actual system URL entry on all three backends, cold URL mount, and invalid-version rejection. They retain screenshots/hierarchies before/after and actual request IDs. **Execution is NOT_RUN.** Multiwindow, full reader/content, Shortcuts/Siri and device acceptance are still pending. Their existence/SDK compilation is not a pass.

Apple runs43726451328 (early membership stop),43726603722 (Xcode26.6/SDK26.5 legacy VoiceOver mismatch and unpinned package compiler target) and43726957317 (Xcode27.1/SDK27.1; legacy SDK tests compiled, host package stopped on resource-bundle CodeSign) are retained separately. The final focused check uses SwiftPM's native build system, an explicit iOS26 Simulator compiler target and the installed Xcode27 SDK; it does not change resource manifests or app signing. Manager's separate app run43727696309 hit the same UI package resource-layout signing blocker; **P owns that correction**. N makes no competing package-manifest repair.

The existing manual SDK script retains the top-level app membership failure while collecting independent package diagnostics. A package compile pass must stay separate from app membership, app compile and runtime acceptance. No prior P/U/S/Reader/native/SDK PASS is inherited by this packet.
