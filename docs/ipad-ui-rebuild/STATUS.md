# Faithful iPad rebuild — execution status

2026-11-04, `[נועם | DEV] [MAIN_SESSION]`, NORMAL, no subagents, no Asana writes.

This is implementation in progress, not a completion or visual-parity claim.

- Original checkout `C:\Users\DAVID\Code\Maktabah` remains on `59b01fa2d604facbcc3b3b1075a6283e7f1115db` with its existing untracked artifacts retained.
- Candidate worktree `C:\Users\DAVID\Code\Maktabah-ipad-ui-faithful-rebuild`, branch `experiment/ipad-ui-faithful-from-9401`, starts exactly at `f092f3996927251d105dfb9243dfac487b196534`.
- Reference package/scratch/evidence: `C:\Users\DAVID\Code\ChavrusaText-rebuild-package-20261104`; pinned clones: `C:\Users\DAVID\Code\Maktabah-UI-Reference-Sources`.
- Existing baseline workflow passed: `41851528984`, 4 real embedded UI tests, actual iPad build. Its initial `simulator-launch.png` is a loading state and is NOT a visual acceptance oracle. The extended black-box suite must capture fully loaded baseline/native screens.
- Existing portable component tests: 379/379 assertions passed. New portable workspace tests: 26 checks passed (atomic state/backup, read-only archival, idempotent migration, 3×3 membership, scene selection, ordering/move, I/O rollback, corrupt/future schema, semantic location).
- Inspector source worktree: `C:\Users\DAVID\Code\TorahInspectorKit-faithful-ui`, branch `codex/faithful-inspector-chrome-20261104`, pin `19d1b35397af4f10ae70cfb3f444c9de87383b53`. Existing package CI `41859651045` passed 26 Swift Testing tests on macOS and 26 on iOS Simulator. Earlier `41855537940` had no runner assignment and is not a test pass.
- Candidate code includes the original Safari/Gelatin source fragments, original CommandPalette SwiftPM source fork with only optional query binding, original public-safe ScrollableTabBar fallback, and DuckDuckGo source port with original layout/interaction tests plus real UIKit 0→1→30→0 tests. All imported original hashes and exact patches are documented.
- Initial candidate `2a46d52c90ff983cf9112fdc9e799ad4aba1b67e`, run `41862430292`, failed its early source-port SDK compilation: `TabFlareBackgroundController.swift:38`, main-actor-isolated UIKit default value in nonisolated context. Its app build/UI tests did not run. The follow-up adds explicit MainActor ownership/display-link isolation and isolated teardown, fixes an optional-binding guard, preserves original book-title observation, adds Reduce Motion handling, and runs a two-size matrix. These changes require a new SDK run; no test is disabled or weakened.
- Protected hooks are confined to the approved viewer/toolbar/history/semantic-label integration points, package target membership and Inspector pin. Global tabs, original library tree/TOC/text renderer/navigation and session manager sources remain unchanged.

Required remaining work:

1. Commit/push this experimental candidate and run the existing extended manual `sefaria-embedded-validation.yml` with source-port SDK tests and genuine native miniTest10 fixtures. Diagnose all compiler/runtime failures, preserve original-source geometry, and rerun on the corrected SHA. No test suppression or softened assertions.
2. Run the same workflow with `source_ref=f092f3996927251d105dfb9243dfac487b196534` to capture fully loaded original-app screenshots using black-box tests from the workflow commit, without changing original app sources.
3. Compare actual baseline/candidate screenshot attachments side by side. Cover both 11/13-inch iPads, portrait/landscape, narrow window, RTL/LTR/themes/accessibility and iPhone fallback. Current initial tests only cover the selected iPad and Hebrew; additional required configurations remain open.
4. Finish remaining interaction/independent locator/rollback stress coverage and full production-corpus/release-configuration acceptance; fixture tests alone are not sufficient. Check source-faithful compact toolbar and Reduce Motion behavior.
5. Only after required gates pass, dispatch existing `ios-testflight.yml` on the new branch with production profile, upload true, exact expected SHA, unique build >10001. Verify Apple processing and internal tester availability. No main merge.
6. Update this status, provenance/runtime evidence, exact protected hunks, ownership/report, and owner test instructions. Physical iPad acceptance remains the owner's gate.

Scratch scripts are implementation helpers, not app runtime. `register_rebuild_files.py` and `connect_protected_seams.py` were one-time transformations and must NOT be rerun on the integrated tree. `build_source_ports.py` rewrites imported files: incorporate any subsequent compiler adaptations into its transforms before reusing it. `write_rebuild_provenance.py` can regenerate hashes/patches from actual files without altering app code.
