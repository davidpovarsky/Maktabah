# Batch B Approval Package — Upstream Integration Seams & Regression Patches

**Target Branch:** `sync/upstream-v42-full-integration`  
**Repository:** `davidpovarsky/Maktabah` (Worktree: `Maktabah-v42-integration`)  
**Baseline Commit SHA:** `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`  
**Pinned Upstream SHA:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`  
**Manifest:** [`docs/architecture/BATCH_B_PAYLOAD_MANIFEST.json`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/BATCH_B_PAYLOAD_MANIFEST.json)  
**Status:** `READY_FOR_OWNER_APPROVAL` (Validated in disposable scratch worktree; ZERO protected files modified in live branch)  
**Date:** 2026-10-25  

---

## Executive Summary

This package consolidates the complete, reproducible integration package for **Batch B** upstream integration, comprising **15 downstream fork-owned components** and **11 ordered patch files** (`00-fork-owned-components.patch`, `00-backendcoordinator-two-phase-switch.patch`, and `01` through `09`).

In accordance with strict upstream cleanliness and safety policies:
- **ZERO modifications to protected upstream files have been applied to the live integration branch.**
- All 11 patches apply cleanly (`git apply --check` and cumulative apply) and reverse cleanly (`git apply --reverse`), restoring the worktree to 100% clean baseline without `git checkout -- .` or `git reset --hard`.
- Cryptographic owner attestation identity verification via Ed25519 signature checks has been implemented in `Scripts/CI/verify-upstream-boundary.py`.
- The single-authority two-phase switch orchestration (`prepareTransition` throwing -> coordinator commit -> `publishTransition` non-throwing) eliminates premature tab destruction.

---

## Detailed Patch Inventory & Cryptographic Manifest

All patches reside in [docs/architecture/batch-b-patches/](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/):

| # | Patch File | Target File(s) | Ownership | Status | Size | SHA-256 Hash |
|---|---|---|---|:---:|---|---|
| **00a** | [`00-fork-owned-components.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/00-fork-owned-components.patch) | `Source/ChavrusaText/*`<br>`MaktabahTests/*`<br>`Scripts/CI/*`<br>`tools/*` | FORK_OWNED | AUTOMATIC_PRE_APPROVED | 212,992 B | `24facc1237375eb2835a96b0b8ac1d449f0f1b36edec3773b0a63a94b87d08c0` |
| **00b** | [`00-backendcoordinator-two-phase-switch.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/00-backendcoordinator-two-phase-switch.patch) | `Source/LibraryBackend/BackendCoordinator.swift` | FORK_OWNED | AUTOMATIC_PRE_APPROVED | 19,463 B | `20287bcdd34806b804f0b849ecc4f26e14ead0e573b543e1fbe6db35928daef9` |
| **01** | [`01-project-pbxproj-chavrusatext.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/01-project-pbxproj-chavrusatext.patch) | `Maktabah.xcodeproj/project.pbxproj` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 12,524 B | `afbe716a5ae8854ebd02a9decf183fff23af3f372d40e4548d41f9e09aa9db03` |
| **02** | [`02-iosreaderview-tabbar-visibility.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/02-iosreaderview-tabbar-visibility.patch) | `Source/Features/Reader/iOS/iOSReaderView.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 621 B | `97abbfe5d5489c4cc6c59377a9711ff3b14097b96a564e591b1331d22c5e634c` |
| **03** | [`03-iosmainview-history-localization.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/03-iosmainview-history-localization.patch) | `Source/UI/iOS/Views/iOSMainView.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 564 B | `f9e529a5fcd6a98423b70fd59592d6d73bb42819e57086dce440268b5f99afd6` |
| **04** | [`04-iosibarottextview-pull-statemachine.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/04-iosibarottextview-pull-statemachine.patch) | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 5,951 B | `ce92efaf0554b9d1a57123a88dce11687288bedf941e59dc346e5212526517cc` |
| **05** | [`05-iosibarottextview-selection-mapper.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/05-iosibarottextview-selection-mapper.patch) | `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 1,740 B | `044bc0f570336878630af9bc70956b5475c7d5aa8170ff7e2afebe40882d4515` |
| **06** | [`06-reader-annotation-refresh-wiring.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/06-reader-annotation-refresh-wiring.patch) | `Source/Features/Reader/ViewModel/Extensions/Reader+Annotation.swift`<br>`Source/Features/Reader/iOS/iOSReaderView.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 4,448 B | `055c93a7da5763c73a9e368979acccc9666b0994b7bfc41c4a5aa93d92e1f490` |
| **07** | [`07-iosreadersessionmanager-writer.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/07-iosreadersessionmanager-writer.patch) | `Source/UI/iOS/Managers/iOSReaderSessionManager.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 3,977 B | `146473ab6364d55a11353d277047298dc8f399cdce1431eb74116349f8f35a63` |
| **08** | [`08-iosnavigationmanager-session-restore.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/08-iosnavigationmanager-session-restore.patch) | `Source/UI/iOS/Managers/iOSNavigationManager.swift` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 15,557 B | `03b8a43bb992d33774e0482eedb36bb9754cd687f94ca96a772db80dd7e83b6d` |
| **09** | [`09-ci-boundary-guard-workflow.patch`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/09-ci-boundary-guard-workflow.patch) | `.github/workflows/upstream-boundary-guard.yml` | UPSTREAM_OWNED | OWNER_APPROVAL_REQUIRED | 3,015 B | `256a99685e6b0233d37642df1c22b8a9e4cb8285a33db54a45e4d095b9498545` |

---

## Detailed Scope per Patch

### Patch 00a: Fork-Owned Components Baseline (`00-fork-owned-components.patch`)
- **Target Files:** 15 downstream fork-owned components:
  - `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift`
  - `Source/ChavrusaText/Annotations/ReaderAnnotationRefreshCoordinator.swift`
  - `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift`
  - `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift`
  - `Source/ChavrusaText/Navigation/ReaderSessionRestoreCoordinator.swift`
  - `Source/ChavrusaText/Navigation/SerializedSessionWriter.swift`
  - `Source/ChavrusaText/ReaderHost/iOSTabBarVisibilityHost.swift`
  - `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift`
  - `Source/ChavrusaText/ReaderRendering/ReaderSelectionRangeMapper.swift`
  - `MaktabahTests/ChavrusaTextComponentTests.swift`
  - `Scripts/CI/verify-upstream-boundary.py`
  - `tools/build_maktabah_ios.sh`
  - `tools/generate_migration_ledger.py`
  - `tools/test_chavrusa_text_components.swift`
  - `tools/test_verify_upstream_boundary.py`
- **Ownership:** FORK_OWNED (does not modify upstream files).
- **Rollback:** Fully reversible via `git apply --reverse docs/architecture/batch-b-patches/00-fork-owned-components.patch`.

### Patch 00b: BackendCoordinator Two-Phase Switch (`00-backendcoordinator-two-phase-switch.patch`)
- **Target File:** `Source/LibraryBackend/BackendCoordinator.swift`
- **Scope & Changes:**
  - Defines `BackendSwitchParticipant` protocol with `prepareTransition` (all-throwing preflight & stage), `publishTransition` (non-throwing post-commit UI swap), `completeTransition`, and `abortTransition`.
  - Implements two-phase transactional switch lifecycle: Phase 1 Prepare -> Phase 2 Atomic Coordinator Commit -> Phase 3 Participant Non-throwing Publish -> Phase 4 Notification Center post -> Phase 5 Complete.
  - Fail-closed abort leaves defaults, activeBackendID, generation, and user tabs completely intact if any validation or snapshot operation throws.
- **Ownership:** FORK_OWNED (tracked file in fork namespace).
- **Rollback:** `git apply --reverse docs/architecture/batch-b-patches/00-backendcoordinator-two-phase-switch.patch`.

### Patches 01 to 09: Protected Upstream Seams (OWNER_APPROVAL_REQUIRED)
- Detailed in Section 2 above and in `UPSTREAM_EXCEPTION_REGISTER.json`. All 8 protected upstream modifications remain in state `OWNER_APPROVAL_REQUIRED` awaiting cryptographic owner signature verification.
