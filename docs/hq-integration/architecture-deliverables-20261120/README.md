# ARCH deliverables — exact scope and executed evidence

This dated appendix supports Root's review of **Profiles ARCH 1220103384074402** and **Sidebar ARCH 1220036734132868**. Their original task text is retained in `ORIGINAL_TASK_CRITERIA.json`; it explicitly describes planning/design deliverables. No Asana record or earlier report is edited here. Root alone decides and records task closure.

Audited integration source: **d5a01b53b08c9115dc09a647bd7e147f44da73c7**. All 37 compiled Git blobs are also byte-identical in the subsequent integration **c6542e412fb5b052d182aacbea685c62bdf8440c**, as recorded in `INPUT_BINDING_TO_INTEGRATION.json`; this is a source binding, not a second run. The exact artifact commits, Git blobs, byte lengths and SHA-256 hashes are in `ARTIFACTS.json`; the exact source and driver input mapping is in `SOURCE_BINDING.json` and `INPUTS.json`.

## Current portable verification

`EXECUTION.json` and the unchanged driver's raw logs record the actual result of `Scripts/CI/test-faithful-workspace.py` against **37 whole original Swift source files** at the audited integration commit. The driver, source list and both historical JSON inputs are copied from their exact Git objects without source rewriting. The small owned snapshot contains 42 files / 392,911 bytes; no corpus, package cache, user session or provider store is copied or opened.

The earlier 89-check result at **03287c697df6c64ec10d0fc36db6df7533c2b871** remains preserved. Its model/store/persistence/mapping sources and test fixture are unchanged, but two other compiled inputs changed: `ReaderContentLoadCoordinator.swift` and `BackendCoordinator.swift`. This is why the original driver was run again on the current inputs. The current result is not borrowed from the old source.

**Execution result: 89/89 checks PASS; driver exit 0; 92.453 seconds, 2026-11-20 09:54:08.578–09:55:40.980 UTC, Swift 6.3.3 Windows.** These are portable Foundation/model checks. The aggregate includes chrome/location checks as well as the workspace checks below; it is not 89 distinct migration cases. `StudyWorkspaceNavigationAdapter.swift` imports SwiftUI and is **not** among these 37 compiled inputs. Its source-level contract is identified separately.

## Profiles ARCH — criterion to evidence

| Original design criterion | Concrete deliverable and verification scope |
| --- | --- |
| StudyProfile → StudyTabGroup → ReaderDocumentTab; stable UUID/order and independent same-book documents | `StudyWorkspaceModels.swift` defines the Codable ownership schema and validates membership. `StudyWorkspaceStore.swift` performs the original transactions. Executed checks cover independent copied document IDs, preserved locator/scroll/selection, group ordering and 3 profiles × 3 groups. Both exact current hashes are in the source binding. |
| Separate study profile, production/miniTest10 data profile and backend | The workspace schema stores study-profile UUIDs and backend-qualified document sessions; it does not use a data-profile identifier as a study-profile or backend identifier. The original `StudyWorkspaceProjectionPolicy` chooses the committed/restored backend separately. This is a schema/source contract, not a claim that every real provider was available. |
| Route/owner contract and view-model lifecycle | `StudyWorkspaceNavigationAdapter.switchGroup` resolves every target document through the original target catalog, retains matching original reader objects, validates backend generation, commits the workspace transaction before native publication, and retains separate per-group/backend caches. `StudyWorkspaceMappingOwnership.swift` binds scene, owner, membership and epochs. These are exact source-reviewed contracts; no UIKit hydration or adapter runtime is credited to the portable driver. |
| Rapid switching/cancellation design | The same adapter rejects overlapping switches with `isSwitching`, cancels superseded scheduled checkpoints, checks the original backend generation, and uses the existing checked backend commit/cancellation boundary. This identifies the design and owner; it does not establish a Native 100-switch run, memory bound or timing result. |
| Migration fixtures from historical sessions | `tools/fixtures/study-workspace/legacy-reader-session-v1.json` contains ten constructed test tabs encoded by the exact historical production Codable declarations from **f092f3996927251d105dfb9243dfac487b196534**. The retained generator execution records its inputs and hashes. The current test decodes those bytes with the real production type, applies the original backend-integrity repair/mapping, attaches the real store, and checks every session field and active UUID. This is not a handcrafted replacement `legacyTabs` proof or a claim about a user's private session. |
| Versioned atomic migration, backup/recovery and fail-closed rollback/no loss | Real persistence/store tests preserve canonical session bytes and migration archives, reject repeated migration, recover a valid backup, prevent a corrupt primary poisoning that backup, reject future schemas without rewriting them, and retain in-memory/durable state after invalid transactions and an actual I/O denial. Old optional-field JSON loads without forced color or rewriting. |
| Per-window restoration and backend matrix | Executed fixtures retain independent selections for window-a/window-b, native-session-a/native-session-b, empty groups and cold restoration. Backend cases distinguish Otzaria, Sefaria and Embedded choices and preserve interleaved foreign-backend documents on reorder, checkpoint and cold decode. This is the enumerated portable matrix in the original fixture; it is not a claim of every Cartesian live-provider/window transition. |
| Ownership/provenance and exact protected hooks | `docs/ipad-ui-rebuild/OWNERSHIP_AND_AUTHORIZATION.md`, `9401_before_edit_ownership_matrix.json`, `PROTECTED_HUNKS.diff`, the upstream integrity policy and exception register identify downstream workspace ownership, protected host/project seams, alternatives and scoped historical approvals. The new SEC reconciliation at **01793f320f1047f008e02a5a0aa1a693732ffdb1** supplies exact ancestry and historical CRLF/LF reconciliation without rewriting those records. No new approval or license conclusion is inferred. |

The historical workspace fixture is also independently encoded from the pre-color schema at **bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1**. Exact input hashes:

- Reader session JSON: `d3d65f962f1bedc25c7e4154316c8789b641590aa2b64a53421ed7b40b86108c`.
- Workspace JSON: `3eaab9c19f18b6ceb59931320f96bfd534d8b6ed5e82a4b9b059b60db51377cc`.

## Sidebar ARCH — criterion to evidence

| Original design criterion | Concrete delivered artifact |
| --- | --- |
| Short RFC and original Library/TOC/detail flow | `docs/hq-integration/profiles-acceptance-20261120/SIDEBAR_ARCH_RFC.md` identifies the original library and selected original reader's TOC supplied to downstream `ReaderSidebarPager`; original `iOSReaderTabView` remains the detail owner. |
| State and source ownership | That RFC and `docs/hq-sidebar/UPSTREAM_HOOKS.md` map page/query state to `ReaderSidebarPageCoordinator`, the library query to the original library view model, TOC query to the original reader UUID, and reader/data ownership to their existing owners. |
| Alternatives that avoid upstream edits | The hook record explains why an extra search field, recreated page branches, replacement reader/navigation stack, whole-toolbar hiding, or unscoped TOC-close suppression would violate original ownership or behavior. |
| Exact protected hunks / project boundary | `docs/hq-sidebar/upstream-hooks.patch` retains the original base-specific iPadLayout and iOSTOCView hooks and original blobs. The hook record states that this particular tranche needed no new project membership. Later hunks remain separately recorded; this historical patch is not presented as the full current diff. |
| Feature flag and rollback decision | The RFC truthfully records the flag-off gap found at its audit source and chooses an original-view fallback without deleting/migrating user data. Subsequent fix **455e5afa4d221c810bb0a4e1fde1a208f3a16b7d** has actual portable RED 11/18 → GREEN 18/18 lifecycle evidence. This dated appendix adds that development without altering the earlier RFC or claiming current Native rollback success. |
| Delivery scope: design, without merge/CI/code requirement | The original task expressly requests RFC/flow/ownership/alternatives/flag/rollback planning. Those artifacts exist and are source-bound. Runtime sidebar correctness is evaluated in the separate UI/QA/parent tasks. This appendix itself changes documents only. |

## Closure boundaries

The documented design/model deliverables above are ready for Root's acceptance review; no missing design artifact was identified in this narrow reconciliation. If a broader live-runtime matrix is required by a separate task, that condition remains in that task and is not satisfied by this appendix.

Keep the parent, UI, QA, SEC/integration and physical-device gates open until their own complete criteria pass. In particular, this evidence does not establish UIKit adapter hydration, real provider availability, Native feature-off behavior, both-size/orientation visual parity, physical iPad acceptance, Native 100-switch completion, performance p95, or the complete per-surface/backend/ingress matrix.

Native38 **44704452479** failed in Apple test compilation before any UI case executed: **38 NOT_RUN, zero verified UI leaves**. The exact raw artifact and subsequent narrow Swift capture fix are retained at **d1b6c74870fea9b9777e918ec6bf58e8925528b1**, `docs/hq-integration/native38-history-isolation-20261120/`. No result is transferred to a newer Native/Release source.

All current checks here operate on owned test values and disposable fixture paths. No user database, annotation, bookmark, canonical session, original task note, or historical evidence file was rewritten.
