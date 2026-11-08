# Scoped protected integration changes

The current user's explicit full execution/release authorization covers concrete source integration and build verification in this isolated branch. The original package's pre-approval-only constraints do not cancel that later instruction.

The protected changes attributable to this integration, relative to synchronized UI commit 661d53e0541779ae6c9ed7526cae5b1f273c708d, are:

| File | Exact purpose | Alternatives and rollback |
|---|---|---|
| Maktabah.xcodeproj/project.pbxproj | Add source memberships for downstream repositories/helpers to all existing app targets | An unregistered Swift file cannot implement a runtime provider; do not create another app target. Revert these entries with their downstream files. |
| Source/Features/Search/iOS/SearchResultsListView.swift | Source/translation/both preview visibility, correct selected language/edition, clear/retry/cancel state and protected-text export | Keep production row rendering; do not duplicate search UI or rewrite original search engine. Revert preview hooks with adapter changes. |
| Source/Features/Reader/ViewModel/ReaderViewModel.swift | Own one downstream edition-selection store and export permission fact per reader | Shared global selection would leak across tabs; embedding edition in TextLocator would change persistence identity. Remove the two stored properties with the hook below. |
| Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift | Request the explicitly selected edition, invalidate cached merged text appropriately, apply original note presentation and publish the matching generation/export policy | Do not rewrite reading-unit service or mutate SQLite. Revert the optional provider dispatch and matching state publications. |
| Source/Features/Reader/iOS/ViewOptionsView.swift | Insert OtzariaVersionPicker into the existing native View Options surface | No replacement reader/settings screen; metadata-only inspector does not select reader text. Remove this one control insertion. |
| Source/UI/iOS/Wrappers/iOSIbarotTextView.swift | Pass/export permission into the existing text view and suppress protected copy/share/export actions, including native text dragging | Text content remains in the existing renderer. Hiding only a custom menu would leave UIKit and drag actions active. Revert the permission input and action gating together. |
| Source/Features/Reader/ViewModel/BookTOCViewModel.swift | Use the selected alternative structure's authoritative line coverage for current-location selection | Nearest-heading inference is not the line_alt_toc contract; changing canonical locators to entry IDs would corrupt navigation. Revert the one matching branch with the optional coverage field. |

The existing native reader/navigation surfaces are retained. Original vendor source, protection guards, ownership policy and approval attestations are not edited by this task's commits. The synchronized UI branch already contains a Markdown authorization entry in docs/architecture/UPSTREAM_EXCEPTION_REGISTER.md; it is preserved as imported work, not converted to a cryptographic attestation. This document records the user's current authorization and reviewable scope; it does not fabricate an Ed25519 owner signature or a named-agent review. The complete classified inventory, including the separate UI branch's imported work, is file-provenance.csv. Original source-port licenses/provenance remain with that UI integration.

The unmodified strict boundary checker was run against base 59b01fa2 and checkpoint b55fc1fc. It reports FAIL with 18 findings: 7 pending proposals, 10 unsigned protected modifications, and the Markdown exception entry arriving alongside protected changes. Its signed-register requirements cannot authenticate an approval made in chat. The report is retained at build/integration-verification/upstream-boundary-report.json; no checker, trust key or register was changed to obtain green. This is an open provenance-check finding, separate from the user's explicit current authorization to implement, synchronize and upload a TestFlight build. No merge to main/dev is performed.

Runtime validation remains separate from authorization. Until actual Apple UI/processing evidence exists, these hunks are implemented but release acceptance remains open.

## Explicitly expanded native UI repair scope

The user's reply, “לתקן כאן גם את כשלי הממשק הקיימים”, adds the thirteen prior iPad failures and the phone regression to this session. UI implementation remains in downstream `Source/ChavrusaText` components. The exact additional connections relative to 661d53e0 are:

| File | Purpose and alternative | Regression/rollback scope |
|---|---|---|
| Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift | Keep the existing native searchable drawer visible inside its independently hosted navigation stack. Duplicating TOC search would lose the existing canonical query/navigation behavior. | Original TOC search, Hebrew/daf tracking, sidebar viewport; revert only the placement argument. |
| Source/UI/iOS/Views/iPadLayout.swift | Restore the original Library query's native searchable drawer in the enabled sidebar stack. Inactive TOC preferences must not supply the Library's search field. | Original Library filtering and persistent sidebar page; remove the searchable modifier with its downstream hosting change. |
| Source/UI/iOS/Views/Common/iOSTabBarVisibilityPolicy.swift | Fork-only co-located helper: use automatic visibility when downstream chrome is visible and retain the original policy if no downstream state is present. | Flags-on/off global-search geometry and collapse; revert helper and host visibility together. |
| Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift | Fork-only co-located workspace: one modifier connects a downstream regular-width phone title action to the existing manager's showingTabsList binding. The original iOSReaderView is not edited for this repair. | Same iPhone Duo overview Grid/List and return-to-reader; remove the single modifier and its downstream definition together. |

The current unchanged cryptographic checker reports **19 findings** at application checkpoint 302b62b4 (WORKTREE with documentation updates): eight pending proposals, ten unsigned upstream modifications and the inherited Markdown-register coupling finding. This supersedes the earlier count of eighteen; it does not authenticate chat authorization or establish runtime acceptance. Evidence: `build/integration-verification/upstream-boundary-ui-repair.json`. Original policy, checker, trust keys and signed exception data remain unchanged by this session.

## Native annotation identity regression

mini v9 native run 42484697648 passed real HTTP install, reopen and both engine searches, then reproduced three existing annotation roundtrip failures: the active cache lost generated CloudKit record IDs after adding a note. The unchanged cross-backend checks still recovered the IDs from SQLite after relaunch. The task's preservation of annotations and the user's full execution/fix authorization cover this concrete regression.

The only new upstream hunk is `Source/Features/Annotations/Database/AnnotationRepository.swift`, in `updateAnnotationRow`: preserve the existing row's CloudKit identity in the returned update value. `addAnnotation` generates that identity, while creation callers can retain their pre-insert copy. SQL already preserves the identity; the cache/pending-sync value must agree with the persisted row. A diagnostic-only reload would conceal the product defect, and changing every UI caller would duplicate identity rules. No schema, migration, CloudKit account or user preference changes are needed. Rollback removes this one preservation block; the diagnostic continues requiring nonempty stable IDs and now independently compares cached values with the actual SQLite rows. Runtime validation is pending a new native run; no annotation acceptance is claimed yet.

The unchanged checker now reports 20 findings for WORKTREE after b0ec7a86, including this additionally disclosed upstream file. Evidence is `build/integration-verification/upstream-boundary-annotation-repair.json`. The checker and trust data remain unchanged.
