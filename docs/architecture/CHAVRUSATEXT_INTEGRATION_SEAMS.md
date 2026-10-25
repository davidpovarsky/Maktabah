# ChavrusaText / Maktabah — Integration Seams & Target Membership Plan

**Document:** `docs/architecture/CHAVRUSATEXT_INTEGRATION_SEAMS.md`  
**Baseline SHA:** `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`  
**Pinned Upstream SHA:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`  
**Status:** `READY_FOR_OWNER_APPROVAL` (Validated in disposable scratch worktree; ZERO protected files modified in live branch)  
**Date:** 2026-10-25  

---

## 1. Executive Summary & Architecture Decisions

In accordance with `UPSTREAM_INTEGRITY_POLICY.md` and `AGENT_BATCH_B_FINAL_PACKAGE_COMPLETENESS_AND_TRUST.md`:
1. **Zero protected upstream files have been modified on the live integration branch.** All 9 new Swift components reside strictly in `Source/ChavrusaText/` and `MaktabahTests/`.
2. **Current Integration State:** All new Swift components compile cleanly with Windows Swift 6.3.3 and have **109 passed unit test assertions** across 9 test suites. They are cataloged in `BATCH_B_PAYLOAD_MANIFEST.json` and are **ready for integration upon explicit owner approval**.
3. **Hardened Architectural Contracts Added & Repaired:**
   - **Boundary Checker Integrity & Ed25519 Cryptographic Attestation:** `Scripts/CI/verify-upstream-boundary.py` implements detached Ed25519 signature checks over canonical payloads bound to `(repo, path, base_sha, head_blob_sha, canonical_patch_sha256, approval_id, expires_at)`. Verified across 28 adversarial test fixtures in `tools/test_verify_upstream_boundary.py`.
   - **Single-Authority Two-Phase Backend Switching Boundary:** `BackendCoordinator` orchestrates a strict two-phase switch:
     - Phase 1: All-throwing `prepareTransition(from:to:)` captures immutable session, validates target backend/locator/book, and pre-stages incoming tabs in memory without mutating coordinator state or destroying open tabs.
     - Phase 2: Atomic coordinator commit (`defaults`, `generation`, `activeBackendID`, cancellation cleanup).
     - Phase 3: Non-throwing `publishTransition(to:context:)` installs pre-staged tabs and updates UI controls.
     - Phase 4: `NotificationCenter.default.post(name: .activeLibraryBackendDidChange, object: targetBackend)` posted exactly once.
     - Phase 5: `completeTransition(to:)` finalization.
     - On failure: `abortTransition(from:to:error:)` discards staged state. Existing open tabs, active tab ID, scroll position, and search remain **100% untouched**.
   - **Locked Disk I/O & Last-Good Preservation:** `BackendNavigationAdapter` locks all disk I/O under `lock.lock() / defer { lock.unlock() }`. In `prepareTransition`, if `outgoingSession()` is empty or nil, the existing last-good session on disk is preserved rather than destructively removed.
   - **Atomic Session File Clearing:** `SerializedSessionWriter` exposes `clear(at:)` running on serial `ioQueue`, eliminating previous unsafe empty data writes and catch-block file deletions.
   - **Typed ContentID Resolution:** Uses typed fallback expression `vm.currentID ?? tab.initialContentId ?? state.currentID ?? (vm.currentContentId > 0 ? vm.currentContentId : nil)` eliminating non-optional `Int` compile errors.
   - **Strict Selection & Annotation Mapping:** `ReaderSelectionRangeMapper` requires explicit `ReaderRangeMappingProvider` whenever display text differs from source text, rejecting unmapped transforms with `mappingRequiredAcrossDifferentRenders`. Validates Unicode scalar and UTF-16 surrogate pair boundaries.

---

## 2. Component Target Membership & Call Site Matrix

| Component File | Role | Xcode Target | Proposed Call Site | Protected File? | Approval Required? |
|---|---|---|---|---|---|
| `Source/ChavrusaText/ReaderHost/iOSTabBarVisibilityHost.swift` | iPad/iPhone Tab Bar policy | `Maktabah` (iOS) | `iOSReaderWorkspaceView.swift:650` | No (Fork-owned) | No |
| `Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift` | Deterministic pull navigation | `Maktabah` (iOS) | `iOSIbarotTextView.swift:1088, 1171` | **Yes (Upstream)** | **YES (Patch 04)** |
| `Source/ChavrusaText/ReaderRendering/ReaderSelectionRangeMapper.swift` | Safe UTF-16 selection range mapping | `Maktabah` (iOS) | `iOSIbarotTextView.swift:1225` | **Yes (Upstream)** | **YES (Patch 05)** |
| `Source/ChavrusaText/Annotations/ReaderAnnotationRefreshCoordinator.swift` | Equatable view revision invalidation | `Maktabah` (iOS) | `iOSReaderView.swift:33, 175` | **Yes (Upstream)** | **YES (Patch 06)** |
| `Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift` | TextLocator target validation & bridge | `Maktabah` (iOS) | `Reader+Annotation.swift:100` | **Yes (Upstream)** | **YES (Patch 06)** |
| `Source/ChavrusaText/Navigation/ReaderSessionRestoreCoordinator.swift` | Stale activeTabId defensive normalization | `Maktabah` (iOS) | `iOSNavigationManager.swift:707` | **Yes (Upstream)** | **YES (Patch 08)** |
| `Source/ChavrusaText/Navigation/SerializedSessionWriter.swift` | Monotonic atomic session writer | `Maktabah` (iOS) | `iOSReaderSessionManager.swift:142, 155, 205` | No (Fork-owned) | **YES (Patch 07)** |
| `Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift` | Durable per-backend tab sessions | `Maktabah` (iOS) | `iOSNavigationManager.swift:665, 680` | **Yes (Upstream)** | **YES (Patch 08)** |
| `Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift` | Exact Hebrew tab title resolver | `Maktabah` (iOS) | `iOSMainView.swift:33` | **Yes (Upstream)** | **YES (Patch 03)** |
| `MaktabahTests/ChavrusaTextComponentTests.swift` | Hardened unit tests | `MaktabahTests` | Synchronized Root Group | No (Fork-owned) | No |

---

## 3. Batch B Patch Bundle Reference

Complete unified `.patch` files have been generated, mechanically checked, and cataloged in:
[`docs/architecture/batch-b-patches/`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/batch-b-patches/) and [`docs/architecture/BATCH_B_APPROVAL_PACKAGE.md`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/BATCH_B_APPROVAL_PACKAGE.md):

1. `00-fork-owned-components.patch` — Creates all 15 untracked fork-owned components.
2. `00-backendcoordinator-two-phase-switch.patch` — Adds `BackendSwitchParticipant` protocol and two-phase switch orchestration.
3. `01-project-pbxproj-chavrusatext.patch` — Registers 9 ChavrusaText files in `Maktabah.xcodeproj/project.pbxproj`.
4. `02-iosreaderview-tabbar-visibility.patch` — Removes line 119 `.toolbar(.hidden, for: .tabBar)` in `iOSReaderView.swift`.
5. `03-iosmainview-history-localization.patch` — Replaces `Library.history` with `"History".localized` in `iOSMainView.swift`.
6. `04-iosibarottextview-pull-statemachine.patch` — Wires `ReaderPullNavigationStateMachine` in `iOSIbarotTextView.swift`.
7. `05-iosibarottextview-selection-mapper.patch` — Wires `ReaderSelectionRangeMapper` in `iOSIbarotTextView.swift`.
8. `06-reader-annotation-refresh-wiring.patch` — Wires `ReaderAnnotationRefreshCoordinator` and `BackendAnnotationBridge` in `Reader+Annotation.swift` and `iOSReaderView.swift`.
9. `07-iosreadersessionmanager-writer.patch` — Delegates session saves to `SerializedSessionWriter` in `iOSReaderSessionManager.swift`.
10. `08-iosnavigationmanager-session-restore.patch` — Wires `BackendSwitchParticipant` with non-throwing `publishTransition`, `ReaderSessionRestoreCoordinator`, and `BackendNavigationAdapter` in `iOSNavigationManager.swift`.
11. `09-ci-boundary-guard-workflow.patch` — Adds event-aware GitHub Actions boundary verification workflow.
