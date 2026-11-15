# R27 startup projection race — deterministic source reproduction

[מיה | UX] [MAIN_SESSION], primary UUID `01a1dc8a-c7c4-7080-8a49-d61dd056fa47`.

Preserved UI01 branch `codex/otzaria-ui-inventory-20261115` at `0b19ded4265ae0f0b6d05571b1c23b7bb3d423f8` (clean). Isolated correction branch `codex/otzaria-r27-workspace-race-20261115`, based on actual failed runtime checkout `ceaf655fcdad64fdadfaf969d443237dab71a7d5`. Source at the candidate adapter/coordinator/models/store is identical between that checkout and the inventory base. No application source edited before reproduction.

## Actual runtime evidence, attributed to Q

Run `43681096257`, artifact `14148779493`, Q's `R27_ATTEMPT_02_REVIEW.json`: **5 native UI passed /4 failed** overall; iPad Legacy and Embedded cases show Library/Select a book with no populated reader; same two backend scenarios passed on iPhone. Q owns test/window preconditions separately. This source reproduction does not replace those native counts, prove screenshots, or yet prove the sole cause of either run failure.

## Proven source interleaving

`Exact9401WorkspaceLifecycle` publishes the adapter then awaits attach on iPad only. `StudyWorkspaceNavigationAdapter.attach` imports the current (possibly empty) canonical tabs and calls `switchGroup(restoringBackend:)`. That method captures `previousTabs`, target documents and active ID before `withTargetCatalog` awaits. It checks backend/generation after the await, but not whether the navigation manager acquired a new tab. `beforeCommit` only validates the saved target; `publish` assigns captured `staged` (empty) and falls back to captured `previousTabs` (also empty). A concurrently published tab disappears without any backend/generation change.

The actual Legacy/Embedded resolver suspends on `await BackendCoordinator.shared.catalog(for:)`. The native public `iOSNavigationManager.openBook` starts an asynchronous task; nothing in the offending adapter code is DEBUG-only. A normal open/restore publication can therefore interleave at the same actor suspension. DEBUG smoke setup can expose the timing, but is not a necessary input to this control-flow bug. Real iPhone lifecycle skips this iPad modifier. These are source facts; native run causality still needs affected-case rerun.

## Focused regression first

`run_regression.py` compiles the **complete actual adapter body**, changing only its import from SwiftUI to Foundation/Observation for a portable control-flow test. It compiles actual StudyWorkspaceModels, StudyWorkspaceStore and StudyWorkspacePersistence, plus the actual session DTO and pure book-identity helper. Explicit MainActor catalog/backend/manager/VM **port doubles** supply controlled continuation barriers, tab identities and no-op content-loading callbacks. There is no UIKit/UI tree, generated reader text, DEBUG setup, network, live DB or native/provider PASS claim. Real JSON persistence operates only in a new temporary fixture directory; no canonical user-session file is opened.

Baseline source SHA256: `bb1c8a9980e0751ddf39f6ca341bf2472beaf3c9640f0f1be98252fa9c97e679`. `baseline-results.log` / `baseline-report.json` preserve the expected failing run at ceaf. The cases suspend deterministically at catalog and just-before-commit boundaries, publish a concurrent native-tab event, and require preservation of its UUID, VM instance, valid active ID and real sidecar document. Positive controls require preexisting tabs to survive, and deliberately persisted empty groups to remain empty when no concurrent open occurs. No sleep/polling. Otzaria catalog suspension is a stress injection (its actual local resolver path normally has no await); actual cold Legacy/Embedded catalog waits are the direct production counterpart.

## Exact ownership dependency before source correction

The necessary fix belongs in **Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift** (DOWNSTREAM_OWNED, absent at upstream `d46af139b3a265399c16d87f5923acd8e3444024`). This existing file was outside U's original ReaderHost lease. After the failing reproduction, lead explicitly extended U's exclusive lease to this exact path at base ceaf; its recorded authority is copied in `lease.json`. No application source was edited before that extension. Coordinator-only timing/sleep/DEBUG special cases cannot protect the actual commit boundary or preserve intentional empty-group semantics.

Implemented in source commit **48d6d7b634e82b8cf4212018d3f089de60958bb5**: at the final throwing pre-publication boundary, adopt a newly published live tab projection **only** for initial startup restore when both captured manager and saved target were empty, same backend/generation and scene target still apply; checkpoint the adopted live UUIDs/active ID into that empty group and reuse their VM objects. Preexisting canonical tabs are not re-imported into an intentionally empty saved group; nonempty saved groups retain authority. Startup checks cancellation, committed backend/generation, and captured scene selection again immediately before the existing validated sidecar transaction. Changed target membership still rejects the transaction. No actor suspension exists between this boundary and native publication.

The only production diff is the leased downstream adapter, 25 insertions/2 deletions. No Vendor/project/CI/test-window/renderer changes. UI01 inventory branch `0b19ded4265ae0f0b6d05571b1c23b7bb3d423f8` remains preserved. Apple SDK compilation and real affected iPad cases remain pending T/Q; R27 native status remains **FAIL: 5 passed /4 failed** until new evidence.

## Executed verification and limits

- Swift 6.3.3 Windows, Swift 6 mode and complete strict concurrency: actual corrected adapter body plus real models/store/persistence, **222/222** deterministic assertions PASS (`results.log`). Native UI tests executed: **0**. `report.json` pins the tested source bytes and Git HEAD. The Foundation/Observation import substitution is the only adapter transform.
- The identical expanded fixture against immutable ceaf adapter: **108/222 PASS, 114 expected failures**, exit 1 (`baseline-expanded-results.log`, `baseline-expanded-report.json`). Original initial reproduction separately preserved: 21/45 PASS, 24 expected failures. Baseline raw CRLF and Git LF hashes differ; the expanded report records LF SHA256 explicitly.
- Both suspension phases cover ordered two-tab UUID/VM preservation, selected second tab, locator/reader state, fresh JSON reload, subsequent checkpoint; rejection controls cover cancellation, changed generation/backend/scene/target, and foreign-backend live metadata. Positive controls cover existing canonical tabs, intentionally saved empty groups, authoritative nonempty saved groups, and explicit post-attach empty-group selection.
- Port doubles control suspension and publication. They do not reproduce the full backend coordinator, resolver, native navigation manager or reader implementation; baseline negative-case counts are scoped adapter assertions, not claims that real coordinator protections fail. No native rendering/provider correctness or Apple SDK typecheck claim follows.
- `py -3 scripts/CI/test-faithful-workspace.py`: **61/61** existing workspace persistence/migration/rollback/scene/semantic-location checks PASS. Copies of actual compile/test logs are in this directory.
- `git diff --check` and `git apply --reverse --check --unidiff-zero source.patch`: PASS. The exact patch uses zero context so its blank context rows do not introduce whitespace-only lines into the evidence file. No app build, remote CI, signing, upload, user database access or index operation by U.

Compile logs retain command output with trailing blank lines normalized to one final newline. `evidence.json` hashes text after LF normalization, so Git's Windows line-ending conversion does not invalidate artifact checksums. Native/runtime claims remain excluded from these portable checks.

## T/Q handoff and rollback

Cherry-pick source commit `48d6d7b634e82b8cf4212018d3f089de60958bb5` through T's integration lane only. `source.patch` is its exact diff against ceaf. Reproduction commands:

```powershell
py -3 docs/hq-ui-inventory/r27-startup-race/run_regression.py --adapter-ref ceaf655fcdad64fdadfaf969d443237dab71a7d5 --label baseline-expanded
# Expected exit 1 / 114 assertion failures.
py -3 docs/hq-ui-inventory/r27-startup-race/run_regression.py
# Expected exit 0 / 222 assertions PASS.
py -3 scripts/CI/test-faithful-workspace.py
# Expected exit 0 / 61 existing contracts PASS.
```

Q/T should rerun the affected Legacy and Embedded iPad reader scenarios at the integrated SHA, keep actual visible reader/title/locator checks unchanged, and verify true tab/active UUID and saved workspace survive startup. Native tests that still end at Library remain failures. Unrelated principal-window and Otzaria-locator failures stay assigned to their existing owners; no duplicate window/test-precondition work here. iPhone provider success in the prior run is a control, not proof this patch passed on device. Physical iPad acceptance remains open.

Rollback, if needed, is a normal reviewed revert of source commit `48d6d7b634e82b8cf4212018d3f089de60958bb5` in T's integration lane. Do not reset branches or remove workspace/session data. This patch makes no schema change or destructive repair.
