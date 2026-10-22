# Maktabah Fork — Upstream Integrity & Regression Prevention Policy

**MANDATORY — owner directive 2026-10-22.** Applies to all coding agents (Codex, Antigravity, Claude, Jules), engineers, QA, review, PR, upstream sync and release preparation. Read with root AGENTS.md and PROJECT_AGENT_GUIDANCE.md. This is the canonical downstream rule; it overrides older weaker language such as "where practical". Agents CANNOT grant themselves exceptions.

## 1. Hard upstream ownership boundary

- **Original maintained upstream:** https://github.com/bismillah-100/Maktabah. Obtain and pin its actual current branch/SHA; never assume stale local refs are authoritative.
- **Downstream fork:** https://github.com/davidpovarsky/Maktabah. ChavrusaText includes Otzaria, Zayit, Sefaria, TorahInspectorKit, native iPad integration, wrappers and first-party search/data layers.
- Upstream-owned source is **READ-ONLY for downstream feature work by default**. Do not modify, copy, relocate, duplicate, reformat, override or delete upstream code to add downstream functionality.
- Put EVERY custom behavior into downstream-owned packages, protocols, adapters, extension files, separate coordinators, dependency-injection layers, wrappers or application composition roots. A new directory does not count as separation if core behavior is still injected into upstream methods.
- An upstream-file registration/import/routing/lifecycle/DI change is an **exception requiring explicit owner permission for its exact file and hunk**, before editing. "Minimal necessary" is NOT automatic authorization. Provide rejected alternatives, reason, security/regression scope and rollback. Record approval in the exception register with a verifiable external reference.
- Existing mixed upstream files are **LEGACY_UNREVIEWED debt**, NOT implicit approvals. Do not expand these custom modifications during unrelated fixes. See UPSTREAM_LEGACY_DEBT.md.
- Original Maktabah's libraries, SDK versions, compiler requirements, lockfiles, generated assets and build settings are upstream-owned. No independent upgrades; accept upstream decisions through a deliberate sync. Escalate security findings rather than silently overriding them.
- Imported third-party engine source (including Otzaria and the Zayit/SeforimLibrary reference) also has its own upstream owner. Our Swift/Rust bridge is downstream; the imported upstream source is not.

## 2. Provenance and permitted placement

Ownership follows the **origin and code lineage**, not the current filename. A file renamed or moved by upstream remains upstream-owned. Protected surfaces include upstream-tracked Source/Core, Source/Features, Source/UI, Source/Extensions, original CLAUDE.md, shared catalogs, manifests and Xcode project files.

Known *candidate* downstream namespaces: Source/Otzaria, Source/Zayit, Source/LibraryBackend, Source/Sefaria, original fork-only Reading/adapters and fork-only packages. Verify their provenance before editing. Fork-owned paths inside upstream namespaces (e.g. custom Source/UI extensions) are legacy co-location debt; move them outward as an approved, tested migration.

High-risk shared seams: app/scene entry, navigation and reader state, search coordinators, localization, Info.plist, entitlements, project.pbxproj, SwiftPM/Cargo locks, XCFramework packaging and workflow YAML. Require specific owner approval for any fork change to upstream-owned originals.

Choose in this order:
1. Existing upstream public protocol/service/extension point.
2. Fork-owned adapter implementing an existing contract.
3. Fork-owned wrapper/coordinator/DI/composition boundary.
4. Fork-owned Swift extension/host without rewriting upstream internals.
5. Owner-approved **minimal upstream hook**, with exact diff and regression tests.

Forbidden: blanket ours/theirs resolution, wholesale copy of a source file, duplicate implementations, unsupported monkey patches, disabling upstream tests, flattening imported upstream provenance, blind version upgrades.

## 3. Mandatory pre-edit checklist

Before writing any application code:
- Identify working tree, branch, HEAD, actual remote upstream SHA, merge base and whether there are uncommitted user changes.
- Classify EACH affected file: UPSTREAM_OWNED, DOWNSTREAM_OWNED, VENDORED_UPSTREAM, SHARED_INTEGRATION_SEAM or UNKNOWN. UNKNOWN is BLOCKED until traced with Git history/rename mapping.
- Prepare an ownership matrix: file | upstream origin+SHA | planned edit | downstream alternative | explicit owner approval | tests.
- Inspect UPSTREAM_EXCEPTION_REGISTER.md and UPSTREAM_LEGACY_DEBT.md; historical violations do not authorize new ones.
- For protected paths, do NOT edit without explicit file-specific owner approval; document the exception before code changes.
- Run read-only git diff and file provenance checks before and after edits; an automated boundary checker is NOT yet installed. Do not claim a guard PASS. Manual ownership review is required.

## 4. Upstream merges are special — never treat them as feature edits

Only perform an upstream sync on explicit user request and in a separately named integration branch/worktree.

**Before:** freeze source/upstream SHAs, snapshot rollback, enumerate commits/renames and divergent files, preserve fork-only packages, DB migrations, localization keys, UI and build targets.

**During:**
- Preserve a true **two-parent merge commit** and ancestry. No resetting to upstream, overwriting tree, squash-copy or selective cherry-pick disguised as a complete sync.
- Adopt upstream's new directory/module structure. Port fork-only features to dedicated external adapters and routing layers, not old duplicate source files.
- Resolve every content/rename/modify-delete/file-location/add-add conflict at *function and behavior level* using base + ours + theirs + final.
- For each conflict maintain a ledger: file | upstream intent | downstream intent | exact chosen integration | retained user behavior | tests | reviewer | OPEN/VERIFIED.
- Never automatically accept --ours or --theirs for reader, search, SQLite, CloudKit, annotations, session state, UI or build project settings.
- Independently check ALL non-conflicting semantic changes and new upstream features; Git conflict count does not measure all regressions.
- For any final file deviating from current upstream, identify downstream-only hunks and corresponding owner approval/legacy debt. Preserve upstream bug fixes.

**After:** compare full file inventory with both parents, including moved/deleted fork code and Xcode build phases/resources; verify original+downstream user behavior; run parity matrix. Green build, signed IPA, App Store Connect VALID and two-parent ancestry are NOT functional acceptance. Never declare full merge DONE until required device/QA gates pass.

## 5. Mandatory functional regression matrix (real app, not only static checks)

Record each scenario as EXECUTED_PASS, FAIL, NOT_RUN or BLOCKED with expected vs actual, SHA, simulator/device OS, evidence and owner. Acceptance is per platform/backend.

1. **Reader durability**: open multiple Maktabah/Otzaria/Zayit/Sefaria tabs; restore exact backend, work, selected tab, locator, page/part, scroll position and inspector after background, force-quit and relaunch; rotate iPad and multitask. Prevent stale asynchronous writes and invalid active-tab restores.
2. **Highlight/selection/annotations**: visible selection and highlight immediately; source/display Unicode range mapping; save, edit and delete via long press; persistence across page/tab/relaunch; Arabic popup placement; no cross-book/backend annotations.
3. **Pull-to-navigate**: top/bottom dragging, fast/slow pull, both directions, correct page/TOC/backend transition, cancellation and single navigation per gesture.
4. **Book info**: contextual long press in Library, search filters and History, correct book identity and navigation.
5. **Annotation panel state**: reopen with previous filter, list position, selected note and scroll.
6. **Table of contents**: exact heading anchor, visual feedback, preservation after layout changes.
7. **Bottom toolbar**: iPad/iPhone layout, book-update check, safe areas, keyboard and rotation.
8. **Downloads/archive integration**: live progress, cancellation/resume, offline/error state and no corruption.
9. **Search+storage+CloudKit**: upstream search AND unified Otzaria/Zayit/Sefaria; stable IDs, pagination >50, Hebrew text/index normalization; SQLite migrations/transactions; sync conflicts and data integrity.
10. **Hebrew localization**: History tab title and all tabs, String Catalog/target membership, RTL, placeholders, accessibility.
11. **Downstream native features**: 3-column iPad layout, floating panels, TorahInspectorKit links/notes, offline bundles, data profiles and deep links.
12. **Build/distribution**: platform builds, signatures, signing and App Store actions only with explicit permission. Passing them DOES NOT imply scenarios 1–11 passed.

Any affected behavior without real evidence stays OPEN. Physical iPad requirements cannot be marked DONE from simulator, CI, compilation or screenshots from an unrelated build.

## 6. Manual upstream-change tripwire (automation not yet implemented)

Before editing, run a read-only Git diff and provenance review against the pinned upstream SHA. A dedicated checker is planned but not yet implemented; do not claim automated enforcement exists. Until implemented, manual ownership review and owner approval are mandatory.

- Detect changes in upstream-tracked files and new fork code introduced into protected upstream Source/ namespaces; compare with upstream tree to distinguish an exact upstream import from a fork customization.
- Require an EXPLICIT prior owner approval reference for any touched protected file that remains downstream-divergent, stored in UPSTREAM_EXCEPTION_REGISTER.md with path, reason, alternatives, scope and tests.
- The checker DOES NOT authenticate approval, check every moved symbol or prove runtime parity. Roni/Tomer must verify actual owner instruction, full diff and device tests.
- Never modify the checker/exceptions and protected source code in the same unreviewed change to make the check pass. Policy changes also need focused review.
- Legitimate upstream syncs may require a new upstream ref, but mixed conflict resolutions never become automatically approved because they arrived in a merge commit. A report-only inventory does not grant permission.

## 7. Owner and named-agent gates

| Role | Required action |
|---|---|
| Eitan / Architecture | Design clean downstream seams; classify legacy debt; escalate unavoidable upstream hook for owner approval. |
| Noam / Engineering | Implement only in downstream layers; refuse unapproved protected edits; write targeted behavioral tests. |
| Maya / Native UX | Protect Maktabah native visual design and iPad interaction/RTL parity with actual UI evidence. |
| Tomer / Integration | Verify ancestry, provenance, all conflicts and renames, rollback, pinned upstream; no silent patch selection. |
| Roni / QA | Independently verify all affected workflows and device gates; no DONE on a successful archive alone. |
| Yael / Research | Verify original code and release notes, external constraints and accurate source references. |
| Dana / Security | Validate DB/CloudKit migrations, entitlements, Rust ABI, data isolation and secret safety. |

NORMAL mode never invokes subagents without explicit user request. GitHub Actions, releases, TestFlight, expensive builds and branch merges require explicit user request under project policy. **Asana may be read proactively; NEVER write/change Asana unless the user explicitly asks to update/sync.**

## 8. Closure report required

Report repository/branch/HEAD, upstream commit, full file ownership matrix, every downstream hunk in upstream-owned code, approved exception reference or BLOCKED state, all conflict resolutions, tests actually run vs NOT_RUN, device evidence, remaining risks, recovery plan and rollback.

**Critical invariant: keep Maktabah upstream original code clean and fully mergeable; implement ChavrusaText-specific behavior in separate layers. A successful compilation is not an architectural or functional PASS.**
