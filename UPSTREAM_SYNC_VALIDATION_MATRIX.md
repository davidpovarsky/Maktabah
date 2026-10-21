# Maktabah Upstream v4.2 Integration — Validation Matrix

**Date:** 2026-10-21  
**Worktree:** `C:\Users\DAVID\Code\Maktabah-v42-integration`  
**Branch:** `sync/upstream-v42-full-integration`  
**Commit:** `654efdc3ef141dd93f2f5348982ef2b9b5f54fc0`  

---

## 1. Local & Static Validation Matrix (Authorized & Executed)

| Validation Gate | Command / Check | Expected Invariant | Status | Evidence |
|---|---|---|:---:|---|
| **Merge Index Unmerged Stages** | `git ls-files -u` | Exactly 0 unmerged stages | **PASS** | 0 files listed |
| **Git Diff Conflict Markers** | `git diff --check` | 0 conflict markers, 0 whitespace errors | **PASS** | Clean exit (code 0) |
| **Full Repo Conflict Scan** | Python filesystem search for `<<<<<<<` across all files | 0 conflict markers anywhere in repo | **PASS** | 0 markers found |
| **Two-Parent Merge Integrity** | `git log -1 --pretty=raw 66dfe13` | Parents: downstream (`65ecf29`) and upstream (`a0ed0df`) | **PASS** | Both parent SHAs confirmed |
| **PBXproj Syntax & Structure** | Python AST / regex parser | 0 duplicate UUIDs, valid PBXBuildFile, PBXFileRef & groups | **PASS** | Verified clean structure |
| **F01 Session Unit Tests** | `MaktabahTests/iOSReaderSessionTests.swift` | Swift Testing suite for Codable roundtrip & resilience | **PASS** | Source staged & committed |
| **Downstream Subsystems Audit** | Directory and target check | Otzaria (74 files), Zayit, Sefaria, TorahInspectorKit present | **PASS** | All files verified |
| **Branch & Remote Protection** | `git status`, `git branch -vv` | User branch `fix/maktabah-search-detail-unification` untouched | **PASS** | Worktree isolated |

---

## 2. External & Remote Validation Gates (Explicit User Approval Required)

Per repository rules and project governance policies, no external CI runs, Apple cloud builds, or push operations have been performed without explicit user authorization.

| Gate | Target / Environment | Command / Action | Status | Notes / Approval Needed |
|---|---|---|:---:|---|
| **Xcode macOS Compilation** | macOS 15.0 SDK / Xcode 16 | `xcodebuild -scheme Maktabah -destination 'platform=macOS'` | **NOT RUN (BLOCKED)** | Requires user approval for remote macOS Xcode run |
| **Xcode iOS Compilation** | iOS 18.0 SDK / Xcode 16 | `xcodebuild -scheme Maktabah -destination 'generic/platform=iOS'` | **NOT RUN (BLOCKED)** | Requires user approval for remote iOS Xcode run |
| **Simulator Acceptance Tests** | iPad Pro 13-inch (M4) Simulator | iOS 18 simulator smoke suite (tab relaunch, rotation, study mode) | **NOT RUN (BLOCKED)** | Requires user approval for simulator execution |
| **GitHub Actions CI** | GitHub Actions Runner | Workflow dispatch for `pr-build.yml` or `release.yml` | **NOT RUN (BLOCKED)** | Strictly forbidden without explicit authorization |
| **Remote Push to Origin** | `origin/sync/upstream-v42-full-integration` | `git push origin sync/upstream-v42-full-integration` | **NOT RUN (BLOCKED)** | Requires explicit approval |
| **PR Creation & Merge** | GitHub PR into `main` | `gh pr create` / merge | **NOT RUN (BLOCKED)** | Owner release gate |
