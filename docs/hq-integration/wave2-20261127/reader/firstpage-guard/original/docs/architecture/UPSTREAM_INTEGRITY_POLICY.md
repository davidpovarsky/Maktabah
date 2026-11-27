# Maktabah Fork — Upstream Integrity & Regression Prevention Policy

**Owner directive, updated 2026-11-26.** This is the upstream integrity policy for development, review, upstream sync and release preparation. Read it with AGENTS.md and PROJECT_AGENT_GUIDANCE.md.

## 1. Hard upstream ownership boundary

- **Original maintained upstream:** https://github.com/bismillah-100/Maktabah. Obtain and pin its actual current branch/SHA; never assume stale local refs are authoritative.
- **Downstream fork:** https://github.com/davidpovarsky/Maktabah. ChavrusaText includes Otzaria, Zayit, Sefaria, TorahInspectorKit, native iPad integration, wrappers and first-party search/data layers.
- Prefer downstream-owned extension points. The user's authorization for a development task covers necessary changes to upstream-owned files within that task. No separate owner approval is required for individual files or hunks.
- Put EVERY custom behavior into downstream-owned packages, protocols, adapters, extension files, separate coordinators, dependency-injection layers, wrappers or application composition roots. A new directory does not count as separation if core behavior is still injected into upstream methods.
- Keep registration, imports, routing, lifecycle and dependency injection changes as local as possible. Document why they are needed, the downstream alternative considered, affected behavior, verification and rollback.
- Existing mixed upstream files are **LEGACY_UNREVIEWED** where provenance is unresolved. Trace newly affected paths and avoid extending unrelated divergence. See UPSTREAM_LEGACY_DEBT.md.
- Original Maktabah's libraries, SDK versions, compiler requirements, lockfiles, generated assets and build settings are upstream-owned. No independent upgrades; accept upstream decisions through a deliberate sync. Escalate security findings rather than silently overriding them.
- Imported third-party engine source (including Otzaria and the Zayit/SeforimLibrary reference) also has its own upstream owner. Our Swift/Rust bridge is downstream; the imported upstream source is not.

## 2. Provenance and permitted placement

Ownership follows the **origin and code lineage**, not the current filename. A file renamed or moved by upstream remains upstream-owned. Protected surfaces include upstream-tracked Source/Core, Source/Features, Source/UI, Source/Extensions, original CLAUDE.md, shared catalogs, manifests and Xcode project files.

Known *candidate* downstream namespaces: Source/Otzaria, Source/Zayit, Source/LibraryBackend, Source/Sefaria, original fork-only Reading/adapters and fork-only packages. Verify their provenance before editing. Fork-owned paths inside upstream namespaces (e.g. custom Source/UI extensions) are legacy co-location debt; move them outward when a tested migration is within task scope.

High-risk shared seams: app/scene entry, navigation and reader state, search coordinators, localization, Info.plist, entitlements, project.pbxproj, SwiftPM/Cargo locks, XCFramework packaging and workflow YAML. Review these paths for provenance, affected behavior, and regressions.

Choose in this order:
1. Existing upstream public protocol/service/extension point.
2. Fork-owned adapter implementing an existing contract.
3. Fork-owned wrapper/coordinator/DI/composition boundary.
4. Fork-owned Swift extension/host without rewriting upstream internals.
5. A **minimal upstream hook** covered by the task, with its exact diff and regression tests.

Forbidden: blanket ours/theirs resolution, wholesale copy of a source file, duplicate implementations, unsupported monkey patches, disabling upstream tests, flattening imported upstream provenance, blind version upgrades.

## 3. Mandatory pre-edit checklist

Before writing any application code:
- Identify working tree, branch, HEAD, actual remote upstream SHA, merge base and whether there are uncommitted user changes.
- Classify EACH affected file: UPSTREAM_OWNED, DOWNSTREAM_OWNED, VENDORED_UPSTREAM, SHARED_INTEGRATION_SEAM or UNKNOWN. UNKNOWN is BLOCKED until traced with Git history/rename mapping.
- Prepare an ownership matrix: file | upstream origin+SHA | planned edit | downstream alternative | task scope | tests.
- Consult the upstream divergence records for relevant provenance and historical verification.
- For protected paths, record the necessary delta and why it fits the authorized task.
- Run read-only Git diff and file provenance checks before and after edits. Review affected behavior in the real app when available.

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
- For any final file deviating from current upstream, identify downstream-only hunks, their task scope, and related legacy debt. Preserve upstream bug fixes.

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

## 6. Development provenance and release verification

Before editing upstream-owned files, review the Git diff and provenance against the pinned upstream SHA. The development task supplies authorization. Separate release verification applies when preparing an authorized release.

- Detect changes in upstream-tracked files and new fork code introduced into protected upstream Source/ namespaces; compare with upstream tree to distinguish an exact upstream import from a fork customization.
- Record protected source changes with their paths, reasons, alternatives, scope, and test evidence. Historical attestations remain in UPSTREAM_EXCEPTION_REGISTER.md.
- An upstream boundary audit verifies the source and signed records in its configured scope. Runtime parity requires behavioral tests.
- Review policy, verifier and source changes as separate changes so each can be tested against its intended requirements.
- Pin any new upstream ref used by a sync and review the semantics of each conflict resolution.

## 7. Owner and named-agent gates

| Role | Required action |
|---|---|
| Eitan / Architecture | Design downstream seams, classify legacy debt, and document any necessary upstream hook and its scope. |
| Noam / Engineering | Prefer downstream layers, make necessary task-scoped upstream edits, and write targeted behavioral tests. |
| Maya / Native UX | Protect Maktabah native visual design and iPad interaction/RTL parity with actual UI evidence. |
| Tomer / Integration | Verify ancestry, provenance, all conflicts and renames, rollback, pinned upstream; no silent patch selection. |
| Roni / QA | Independently verify all affected workflows and device gates; no DONE on a successful archive alone. |
| Yael / Research | Verify original code and release notes, external constraints and accurate source references. |
| Dana / Security | Validate DB/CloudKit migrations, entitlements, Rust ABI, data isolation and secret safety. |

NORMAL mode never invokes subagents without explicit user request. GitHub Actions, releases, TestFlight, expensive builds and branch merges require explicit user request under project policy. **Asana may be read proactively; NEVER write/change Asana unless the user explicitly asks to update/sync.**

## 8. Closure report required

Report repository/branch/HEAD, upstream commit, full file ownership matrix, every downstream hunk in upstream-owned code, task scope and any remaining evidence gaps, all conflict resolutions, tests actually run vs NOT_RUN, device evidence, remaining risks, recovery plan and rollback.

**Critical invariant: keep Maktabah upstream original code clean and fully mergeable; implement ChavrusaText-specific behavior in separate layers. A successful compilation is not an architectural or functional PASS.**
