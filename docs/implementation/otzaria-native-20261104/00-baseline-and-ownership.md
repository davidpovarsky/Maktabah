# Isolated integration baseline — 2026-11-08

Role: [נועם | DEV] [MAIN_SESSION]. No subagents.

- Repository: davidpovarsky/Maktabah.
- Base: 59b01fa2d604facbcc3b3b1075a6283e7f1115db.
- Branch: integration/sefaria-otzaria-20261108.
- Separate managed Git worktree; primary and UI-agent working trees remain untouched.
- Parallel UI branch observed: experiment/ipad-ui-faithful-from-9401 at 661d53e0 (runtime QA in progress).
- The user explicitly expanded authorization on 2026-11-08 to full execution including TestFlight, requested an isolated environment, and required synchronization with the parallel work before upload.
- This current instruction supersedes the attached package's older limitations on branch publication, CI, builds and TestFlight. Asana remains read-only; production/main/dev merging and user-data deletion are outside scope.
- Never upload an earlier tested SHA after synchronization changes it. Freeze the combined SHA, rerun affected verification, then pass expected_sha to delivery.
- Uncommitted work in another worktree must be left intact; synchronize committed work and track any pending changes before release.

## Protected integration seam

Source/Features/Search/iOS/SearchResultsListView.swift changes only language normalization, reading-mode visibility, edition requests, and preview reload/cancellation. The user's task explicitly identifies this component; the expanded execution authorization covers these scoped corrections. Shared business logic lives in LibraryBackend and SefariaEmbedded. No invented cryptographic owner attestation or policy bypass is introduced.

## Verification boundaries

Portable component tests, JavaScript contract tests, real Hermes RPC tests, simulator UI tests, and physical iPad acceptance are separate evidence categories. None substitutes for another.
