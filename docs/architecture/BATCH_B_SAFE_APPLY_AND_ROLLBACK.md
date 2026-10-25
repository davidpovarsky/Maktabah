# Batch B Safe Apply and Mechanical Rollback Protocol

**Baseline Commit:** `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`  
**Target Branch:** `sync/upstream-v42-full-integration`  
**Manifest:** [`docs/architecture/BATCH_B_PAYLOAD_MANIFEST.json`](file:///C:/Users/DAVID/Code/Maktabah-v42-integration/docs/architecture/BATCH_B_PAYLOAD_MANIFEST.json)  
**Verification Date:** 2026-10-25  
**Verification Test Script:** `test_patch_apply_and_rollback.py`  
**Result:** `100% REVERSIBLE VERIFIED`  

---

## 1. Verified Mechanical Apply & Rollback Invariants

All 11 patches in Batch B (`00-fork-owned-components.patch`, `00-backendcoordinator-two-phase-switch.patch`, and `01` through `09`) have been subjected to rigorous mechanical verification within an isolated, disposable scratch worktree at `c8defbf812d34dd22ea1b7b63b1a356c0e96fa8f`:

1. **Individual Preflight (`git apply --check`):**
   Every patch independently checks clean against the baseline with zero warnings and zero rejections.
2. **Cumulative Sequence Apply (`git apply`):**
   All 11 patches apply cumulatively in exact order:
   - `00-backendcoordinator-two-phase-switch.patch`
   - `00-fork-owned-components.patch`
   - `01-project-pbxproj-chavrusatext.patch`
   - `02-iosreaderview-tabbar-visibility.patch`
   - `03-iosmainview-history-localization.patch`
   - `04-iosibarottextview-pull-statemachine.patch`
   - `05-iosibarottextview-selection-mapper.patch`
   - `06-reader-annotation-refresh-wiring.patch`
   - `07-iosreadersessionmanager-writer.patch`
   - `08-iosnavigationmanager-session-restore.patch`
   - `09-ci-boundary-guard-workflow.patch`
3. **Reverse Check (`git apply --reverse --check`):**
   In exact reverse order (09 down to 00), all 11 patches reverse check with exit code 0.
4. **Mechanical Reversal Execution (`git apply --reverse`):**
   Executing reverse apply across all 11 patches restores the repository to 100% clean baseline:
   `git status --porcelain` is completely empty.
   **No `git checkout -- .` or `git reset --hard` is used.**

---

## 2. Step-by-Step Operator Instructions

### Applying Batch B (Upon Owner Authorization)
```bash
# 1. Ensure working on clean baseline at c8defbf
git checkout sync/upstream-v42-full-integration
git status # Must be clean

# 2. Apply ordered patches 00 through 09
git apply docs/architecture/batch-b-patches/00-backendcoordinator-two-phase-switch.patch
git apply docs/architecture/batch-b-patches/00-fork-owned-components.patch
git apply docs/architecture/batch-b-patches/01-project-pbxproj-chavrusatext.patch
git apply docs/architecture/batch-b-patches/02-iosreaderview-tabbar-visibility.patch
git apply docs/architecture/batch-b-patches/03-iosmainview-history-localization.patch
git apply docs/architecture/batch-b-patches/04-iosibarottextview-pull-statemachine.patch
git apply docs/architecture/batch-b-patches/05-iosibarottextview-selection-mapper.patch
git apply docs/architecture/batch-b-patches/06-reader-annotation-refresh-wiring.patch
git apply docs/architecture/batch-b-patches/07-iosreadersessionmanager-writer.patch
git apply docs/architecture/batch-b-patches/08-iosnavigationmanager-session-restore.patch
git apply docs/architecture/batch-b-patches/09-ci-boundary-guard-workflow.patch

# 3. Verify payload integrity
python tools/assemble_batch_b_payload.py
```

### Reversing Batch B (Mechanical Rollback)
```bash
# Execute in exact reverse order (09 down to 00)
git apply --reverse docs/architecture/batch-b-patches/09-ci-boundary-guard-workflow.patch
git apply --reverse docs/architecture/batch-b-patches/08-iosnavigationmanager-session-restore.patch
git apply --reverse docs/architecture/batch-b-patches/07-iosreadersessionmanager-writer.patch
git apply --reverse docs/architecture/batch-b-patches/06-reader-annotation-refresh-wiring.patch
git apply --reverse docs/architecture/batch-b-patches/05-iosibarottextview-selection-mapper.patch
git apply --reverse docs/architecture/batch-b-patches/04-iosibarottextview-pull-statemachine.patch
git apply --reverse docs/architecture/batch-b-patches/03-iosmainview-history-localization.patch
git apply --reverse docs/architecture/batch-b-patches/02-iosreaderview-tabbar-visibility.patch
git apply --reverse docs/architecture/batch-b-patches/01-project-pbxproj-chavrusatext.patch
git apply --reverse docs/architecture/batch-b-patches/00-fork-owned-components.patch
git apply --reverse docs/architecture/batch-b-patches/00-backendcoordinator-two-phase-switch.patch

# Check status — will be 100% clean baseline
git status
```

---

## 3. Rollback Boundaries & Limitations

Mechanical `git apply --reverse` restores the Git tree to its exact prior state. However, operators must note non-Git rollback boundaries:
- **Disk Caches / App Support Sessions:** `ApplicationSupport/ChavrusaText/BackendSessions/` files created during runtime must be cleared manually if desired.
- **SQLite / Database Migrations:** If database migrations run during test runs, database files must be reset.
- **TestFlight / Remote CI:** Builds dispatched to remote CI or TestFlight cannot be rolled back via Git apply reverse.
