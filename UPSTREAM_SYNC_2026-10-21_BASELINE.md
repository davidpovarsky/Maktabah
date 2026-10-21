# Maktabah Upstream v4.2 Integration — Baseline & Provenance

**Date:** 2026-10-21  
**Execution Worktree:** `C:\Users\DAVID\Code\Maktabah-v42-integration`  
**Integration Branch:** `sync/upstream-v42-full-integration`  

## 1. Pinned SHAs & Provenance

- **Fork Remote:** `origin` (`https://github.com/davidpovarsky/Maktabah.git`)
- **Fork Active Working Branch:** `fix/maktabah-search-detail-unification`
- **Fork Starting SHA:** `65ecf2972821e13047b21c9ce04fe6141ca9387f`
  - (Descendant of inspected baseline `c342bf435f7d1f1d948694509e8716333f98e248` by 10 commits purely in Otzaria/scripts/docs)
- **Upstream Remote:** `upstream` (`https://github.com/bismillah-100/Maktabah.git`)
- **Upstream Target Branch:** `main`
- **Upstream Target SHA:** `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4` (pinned)
- **Common Ancestor (`merge-base`):** `06158e767ee765f2451461a34d18feeeccc79fa5` (2026-09-03)
- **Upstream Commits since Ancestor:** 168 commits
- **Fork Commits since Ancestor:** 503 commits
- **Dry-run Conflict Count:** 72 conflict records
  - Content conflicts: 47
  - Modify/Delete conflicts: 20
  - File Location conflicts: 3
  - Add/Add conflicts: 1 (`CLAUDE.md`)
  - Distinct types conflicts: 1 (`GEMINI.md`)

## 2. Environment & Safety Isolation

- The main repository at `C:\Users\DAVID\Code\Maktabah` remains on `fix/maktabah-search-detail-unification`.
- All integration and conflict resolution work takes place strictly inside the isolated worktree `C:\Users\DAVID\Code\Maktabah-v42-integration`.
- All pre-existing untracked directories (`artifacts_*`, `iPad-acceptance-*`, `ios-build-*`, `otzaria-reports-*`, `reports_*`, `screenshots_*`, `simlogs_*`, `simulator-build-logs/`, `zayit-diag-*`) remain intact and untouched in the main directory.
- No push to origin, no PR creation, no merge to main, no GitHub Actions dispatch, and no Asana modification will occur without explicit user authorization.

## 3. Rollback Procedure

To roll back at any point without impacting the working repository:
```bash
git -C "C:\Users\DAVID\Code\Maktabah" worktree remove --force "C:\Users\DAVID\Code\Maktabah-v42-integration"
git -C "C:\Users\DAVID\Code\Maktabah" branch -D sync/upstream-v42-full-integration
```
