# Original294 component reconciliation

Audited source: 5d4b110a61882dea413c110b3d4f8026f4aa2b54. No product/runtime PASS is asserted.

| Original ID | Meaning | Current role | Supplied route subset | Original QA |
| --- | --- | --- | --- | --- |
| inventory.v1.app.scene | Foreground app scene | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.tab.library | Library tab | meaningful_original_control_or_state | native.library / native.library.contents | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.tab.search | Global Search tab | meaningful_original_control_or_state | native.search | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.tab.authors | Authors tab | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.tab.annotations | Annotations tab | meaningful_original_control_or_state | native.annotations | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.tab.history | History tab | meaningful_original_control_or_state | native.history | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.shell.ipad-split | iPad Library/Reader split | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.shell.iphone-stack | Compact phone navigation | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.shell.settings-sheet | Settings sheet | meaningful_original_control_or_state | native.settings | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.shell.book-info-sheet | Book metadata sheet | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.shell.alert | Navigation error/notice | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.bootstrap.source | Initial library source selection | meaningful_original_control_or_state | — | Q-UI07-018, Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.bootstrap.sefaria-confirmation | Sefaria source confirmation | meaningful_original_control_or_state | — | Q-UI07-018, Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.bootstrap.otzaria-assets | Otzaria database setup | meaningful_original_control_or_state | — | Q-UI07-018, Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.bootstrap.import | Database file chooser | meaningful_original_control_or_state | — | Q-UI07-018, Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.bootstrap.welcome | Welcome sheet | meaningful_original_control_or_state | — | Q-UI07-018, Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.bootstrap.core-update | Core update prompt/progress | meaningful_original_control_or_state | — | Q-UI07-018, Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.library.catalog | Category/book tree | meaningful_original_control_or_state | native.library / native.library.contents | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.query | Library catalog search | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.category-expansion | Expand category path | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.open-work | Open selected book | meaningful_original_control_or_state | native.reader | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.grouping | Category grouping menu | meaningful_original_control_or_state | native.library / native.library.grouping | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.author-grouping | Author grouping variant | meaningful_original_control_or_state | native.library / native.library.grouping | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.selection | Bulk library selection | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.download-filter | Downloaded library filter | meaningful_original_control_or_state | native.library / native.library.downloadedFilter | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.options | Library actions menu | meaningful_original_control_or_state | native.library / native.library.options | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.book-info-context | Book context metadata | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.import | Offline book import form | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.updates | Books Updates dialog | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.delete | Delete downloaded books confirmation | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.import.book | Import book selector | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.import.author | Import author selector | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.import.file | Import file chooser | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.import.category | Import category selection | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.import.form | Import metadata/form | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.updates-review | Books update selection/review | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.author | Author list and author books | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.narrator-detail | Native narrator sidebar | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.library.narrator-reader | Native narrator biography reader | meaningful_original_control_or_state | — | Q-UI07-001; native NOT_RUN |
| inventory.v1.reader.content | Native Reader work/section | meaningful_original_control_or_state | native.reader | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.viewport | Scroll to exact content anchor | meaningful_original_control_or_state | native.reader | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.text-selection | Selected text/segment | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.selection-actions | Native text selection annotation actions | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.pull-navigation | Adjacent section navigation | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.navigation-popover | Navigation slider popover | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.navigation-unit | Canonical unit slider selection | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.toolbar.search | Book Search sheet | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.toolbar.annotations | Book annotations list | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.toolbar.view-options | Reader display options | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.toolbar.toc | Show contents | meaningful_original_control_or_state | native.reader.toc / native.reader.toc.contents | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.toolbar-actions | Reader action toolbar | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.book-info | Book information details | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.book-info-anchor | Anchored book-info card | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.options.typography | Reader font/size/line spacing | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.options.fonts | Font import/delete chooser | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.options.text-mode | Reader text language/mode | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.options.display | Harakat/annotation/underline preferences | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.options.background | Reader paper/background picker | meaningful_original_control_or_state | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.reader.version-picker | Native content version chooser | declared_version_capability_without_native_chooser | — | Q-UI07-002, Q-UI07-003, Q-UI07-008; native NOT_RUN |
| inventory.v1.toc.contents | TOC sidebar page | meaningful_original_control_or_state | native.reader.toc / native.reader.toc.contents | Q-UI07-004; native NOT_RUN |
| inventory.v1.toc.query | TOC local search | meaningful_original_control_or_state | — | Q-UI07-004; native NOT_RUN |
| inventory.v1.toc.structure | TOC structure picker | meaningful_original_control_or_state | native.reader.toc / native.reader.toc.structure | Q-UI07-004; native NOT_RUN |
| inventory.v1.toc.selected-node | TOC exact heading anchor | meaningful_original_control_or_state | native.reader.toc / native.reader.toc.currentSelection | Q-UI07-004; native NOT_RUN |
| inventory.v1.toc.expansion | TOC node expansion | meaningful_original_control_or_state | — | Q-UI07-004; native NOT_RUN |
| inventory.v1.toc.node | Select semantic TOC node | meaningful_original_control_or_state | — | Q-UI07-004; native NOT_RUN |
| inventory.v1.sidebar.page | Library/TOC sidebar selection | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.sidebar.visibility | Native sidebar visibility | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.inspector.panel | Study Inspector panel | meaningful_original_control_or_state | native.reader.inspector | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.sheet | Compact study sheet | meaningful_original_control_or_state | native.reader.inspector | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.tool | Selected study tool | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.width | Docked/floating Inspector placement | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.related-source | Selected commentary/related source | meaningful_original_control_or_state | native.reader | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.line-links | Otzaria line-linked sources | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.generic-relationships | Backend-qualified related refs | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.commentaries | Commentaries tool | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.links | Links tool | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.notes | Selection-scoped Notes tool | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.commentary-group | Expanded commentary author/group | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.note-item | Open selected note | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.note-delete | User-selected note deletion | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.reader | Nested related-source reader | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.inspector.shared.route | Inspector source/segment navigation path | meaningful_original_control_or_state | — | Q-UI07-005, Q-UI07-013; native NOT_RUN |
| inventory.v1.notes.draft | Open anchored annotation/note editor | meaningful_original_control_or_state | native.reader.noteDraft | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.notes.editor.body | Note text focus | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.notes.editor.tags | Annotation tags | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.notes.editor.style | Highlight/underline style | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.notes.editor.save | Save annotation confirmation | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.notes.editor.delete | Delete annotation confirmation | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.notes.editor.cancel | Dismiss annotation draft | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-027; native NOT_RUN |
| inventory.v1.annotations.list | Global annotations list | meaningful_original_control_or_state | native.annotations | Q-UI07-009, Q-UI07-010; native NOT_RUN |
| inventory.v1.annotations.filter | Tag/group/sort controls | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-010; native NOT_RUN |
| inventory.v1.annotations.import | Annotation JSON import review | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-010; native NOT_RUN |
| inventory.v1.annotations.export | Annotation export | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-010; native NOT_RUN |
| inventory.v1.annotations.book | Book-specific annotations and last list position | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-010; native NOT_RUN |
| inventory.v1.annotations.import-conflict | Annotation import overwrite/merge confirmation | meaningful_original_control_or_state | — | Q-UI07-009, Q-UI07-010; native NOT_RUN |
| inventory.v1.search.global | Global unified content search | meaningful_original_control_or_state | native.search | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.input-focus | Global search field focus | meaningful_original_control_or_state | native.search / native.search.query, native.search.queryEntry | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.history | Canonical global query history | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.filters | Book/category scope filter sheet | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.filter-tree | UIKit search scope tree | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.advanced | Search mode/match/sort options | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.help | Search semantics help popover | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.results | Stable hit result list | meaningful_original_control_or_state | native.search.results | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.clipboard | Explicit copy/copy-with-source context menu | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.paging | Load actual next search page | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.engine-state | Search package/readiness feedback | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.book | Book-local content search | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.command-palette | Library command palette | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.save-results-draft | Save results name/folder draft | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.list | Saved search results | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.folder | Saved-results folder | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.query | Search saved results/folders | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.move | Move saved result/folder | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.delete | Delete saved-results folder | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.rename | Rename saved item draft | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.move-destination | Saved-result move destination | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.bookmarks.folder-selection | Folder selection control | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-027; native NOT_RUN |
| inventory.v1.history.list | Reading history and favorites | meaningful_original_control_or_state | native.history | Q-UI07-010, Q-UI07-040; native NOT_RUN |
| inventory.v1.history.open-entry | Reopen remembered work/location | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-040; native NOT_RUN |
| inventory.v1.history.favorite-picker | Favorites selection sheet | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-040; native NOT_RUN |
| inventory.v1.history.favorite-item | Favorite work item | meaningful_original_control_or_state | — | Q-UI07-010, Q-UI07-040; native NOT_RUN |
| inventory.v1.workspace.reader-tabs | Native reader tabs | meaningful_original_control_or_state | — | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.tabs-popover | Original tabs overview popover | meaningful_original_control_or_state | — | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.groups-overview | Study groups overview | meaningful_original_control_or_state | native.workspace.overview / native.workspace.overview.groups, native.workspace.overview.grid, native.workspace.overview.list | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.document-tabs | Document tab strip/reorder | meaningful_original_control_or_state | — | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.profile-menu | Study profile selection menu | meaningful_original_control_or_state | native.workspace.overview / native.workspace.overview.profileMenu | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.profile.management | Study profile management sheet | meaningful_original_control_or_state | native.workspace.profiles / native.workspace.profiles.list | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.profile.draft | New/edit profile draft | meaningful_original_control_or_state | native.workspace.profiles / native.workspace.profiles.newProfile | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.profile.groups | Group rename/move/reorder | meaningful_original_control_or_state | native.workspace.profiles / native.workspace.profiles.groups | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.profile.delete | Delete profile confirmation | meaningful_original_control_or_state | — | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.workspace.scene-identity | Per-window workspace identity | meaningful_original_control_or_state | — | Q-UI07-012, Q-UI07-017, Q-UI07-048; native NOT_RUN |
| inventory.v1.settings.root | Settings | meaningful_original_control_or_state | native.settings | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.backend | Library source picker | meaningful_original_control_or_state | native.settings / native.settings.backend | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.offline | Offline library destination | meaningful_original_control_or_state | native.settings / native.settings.offline | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.database-mode | Database bundle mode | meaningful_original_control_or_state | native.settings / native.settings.databaseMode | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.history | Record search history preference | meaningful_original_control_or_state | native.settings / native.settings.history | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.storage | Library storage/cleanup | meaningful_original_control_or_state | native.settings / native.settings.storage | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.annotations | Annotation storage and missing-book policy | meaningful_original_control_or_state | native.settings / native.settings.annotations | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.cloud | CloudKit and cross-platform sync | meaningful_original_control_or_state | native.settings / native.settings.cloud | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.appearance | System/app theme | meaningful_original_control_or_state | native.settings / native.settings.appearance | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.search-data | Search Data destination | meaningful_original_control_or_state | native.settings / native.settings.searchData | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.search-credits | Search engine attribution | meaningful_original_control_or_state | native.settings / native.settings.searchCredits | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.search-index | FTS migration/rebuild prompt | meaningful_original_control_or_state | native.settings / native.settings.searchIndex | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.optimization | Database vacuum review | meaningful_original_control_or_state | native.settings / native.settings.optimization | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.updates | Update settings | meaningful_original_control_or_state | native.settings / native.settings.updates | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.downloads | Download configuration | meaningful_original_control_or_state | native.settings / native.settings.downloads | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.data-profile | Production/test data profile Settings control | historical_absent_settings_placeholder_where_existing_scope | — | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.accessibility | Dedicated app accessibility Settings subsection | historical_absent_settings_placeholder_where_existing_scope | — | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.language | Dedicated app-wide language Settings subsection | historical_absent_settings_placeholder_where_existing_scope | — | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.offline-packages | Offline Sefaria package management | meaningful_original_control_or_state | — | Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.packages.review | Package selection review | meaningful_original_control_or_state | — | Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.packages.apply | Install/remove package confirmation | meaningful_original_control_or_state | — | Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.packages.updates | Check offline updates | meaningful_original_control_or_state | — | Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.packages.update | Download offline update | meaningful_original_control_or_state | — | Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.packages.cancel | Cancel package operation | meaningful_original_control_or_state | — | Q-UI07-022, Q-UI07-027; native NOT_RUN |
| inventory.v1.settings.search-data-detail | Installed search engine artifacts/status | meaningful_original_control_or_state | — | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.settings.search-data-install | Search Data missing-component installation | meaningful_original_control_or_state | — | Q-UI07-011, Q-UI07-027, Q-UI07-043, Q-UI07-044; native NOT_RUN |
| inventory.v1.search.diagnostics | Search diagnostic report | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.legacy-link.history | Existing widget history URL | meaningful_original_control_or_state | legacy WidgetDeepLink.history | Q-UI07-040, Q-UI07-041, Q-UI07-042; native NOT_RUN |
| inventory.v1.legacy-link.annotation | Existing widget annotation URL | meaningful_original_control_or_state | legacy WidgetDeepLink.annotation | Q-UI07-040, Q-UI07-041, Q-UI07-042; native NOT_RUN |
| inventory.v1.widget.configuration | Widget configuration intents only | original_widget_configuration_not_navigation_intent | — | Q-UI07-040, Q-UI07-041, Q-UI07-042; native NOT_RUN |
| inventory.v1.future.registry | Versioned native UI route registry | formerly_missing_infrastructure_now_source_supplied | — | Q-UI07-023, Q-UI07-036, Q-UI07-039, Q-UI07-051; native NOT_RUN |
| inventory.v1.future.orchestrator | Exact scene/presentation/focus orchestrator | formerly_missing_infrastructure_now_source_supplied | — | Q-UI07-023, Q-UI07-036, Q-UI07-039, Q-UI07-051; native NOT_RUN |
| inventory.v1.future.app-intents | Reader/Settings App Intents and Shortcuts | formerly_missing_infrastructure_now_source_supplied | — | Q-UI07-023, Q-UI07-036, Q-UI07-039, Q-UI07-051; native NOT_RUN |
| inventory.v1.future.universal-links | App universal-link route allowlist/AASA | formerly_missing_infrastructure_now_source_supplied | — | Q-UI07-023, Q-UI07-036, Q-UI07-039, Q-UI07-051; native NOT_RUN |
| inventory.v1.future.guide-spotlight | Semantic guide/spotlight anchor service | formerly_missing_infrastructure_now_source_supplied | — | Q-UI07-023, Q-UI07-036, Q-UI07-039, Q-UI07-051; native NOT_RUN |
| inventory.v1.future.hanlin-host | Thin in-process existing Hanlin SDK host adapter | formerly_missing_infrastructure_now_source_supplied | — | Q-UI07-023, Q-UI07-036, Q-UI07-039, Q-UI07-051; native NOT_RUN |
| inventory.v1.inactive.safari-host | Historical custom Safari-style reader host | historical_alternative_host | — | Q-UI07-013; native NOT_RUN |
| inventory.v1.inactive.otzaria-root | Historical standalone Otzaria split | historical_alternative_host | — | Q-UI07-013; native NOT_RUN |
| inventory.v1.inactive.otzaria-library | Historical integrated Otzaria library | historical_alternative_host | — | Q-UI07-013; native NOT_RUN |
| inventory.v1.inactive.otzaria-reader | Standalone Otzaria reader UI | historical_alternative_host | — | Q-UI07-013; native NOT_RUN |
| inventory.v1.inactive.otzaria-settings | Standalone Otzaria reader settings | historical_alternative_host | — | Q-UI07-013; native NOT_RUN |
| inventory.v1.inactive.otzaria-search | Standalone Otzaria search view | historical_alternative_host | — | Q-UI07-013; native NOT_RUN |
| inventory.v1.embedded.surface-host | Declared RN native surface host | original_RN_host_source_wired_native_pending | native.sefariaEmbedded | Q-UI07-020, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.runtime | Persistent headless Hermes runtime | backend_infrastructure_not_visible_UI | — | Q-UI07-020, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rpc-data | Allowlisted Sefaria RPC data operations | backend_infrastructure_not_visible_UI | — | Q-UI07-020, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn-root | Original RN ReaderApp conditional full UI | original_RN_host_source_wired_native_pending | native.sefariaEmbedded | Q-UI07-020, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.reader | Original ReaderApp state/navigation | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.library | RN texts/library navigation | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.category | RN category/text list | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.reader-controls | RN Reader controls | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.text-column | RN reading column | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.segment | RN exact text segment selection | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.toc | RN text TOC and versions | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.connections | RN connections/commentary panel | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.connections-filter | RN connections filters/header | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.link-content | RN linked-source content | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.versions | RN version selection | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.translations | RN available translations | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.dictionary | RN dictionary/lexicon | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.display-options | RN text display options | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.search | RN global search page | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.search-results | RN search result page | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.search-filters | RN search filter selection | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.autocomplete | RN search autocomplete | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.history-saved | RN history/saved page | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings | RN Settings page | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.account | RN account menu | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.auth | RN auth screen | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.reset-password | RN password reset screen | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.topics | RN topics/category detail | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.topic-list | RN topic list | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.learning-schedules | RN learning schedules | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.sheet | RN source-sheet metadata | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.about | RN About page | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.footer-tabs | RN footer tab selection | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.deep-links | Upstream RN link parser | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.error | RN error boundary fallback | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.web | RN browser content view | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.interface-language | RN interface language subsection | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.text-language | RN text language subsection | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.network | RN offline network preference | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.offline-library | RN offline access/install/update/delete review | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.debug-destructive | Excluded RN debug destructive control | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.email-frequency | RN email-frequency setting | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.reading-history | RN reading-history setting | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.custom | RN preferred custom setting | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.grogger | RN grogger preference | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.logout | RN logout flow | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.settings.delete-account | RN account deletion flow | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.dedication | RN dedication information page | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.embedded.rn.notice | RN interrupting-message modal | original_RN_source_with_installed_host_runtime_pending | — | Q-UI07-020, Q-UI07-029, Q-UI07-042; native NOT_RUN |
| inventory.v1.decorative.toolbar-icons | TOC/Inspector icon artwork | decorative_not_standalone_action | — | Q-UI07-043, Q-UI07-044, Q-UI07-045; native NOT_RUN |
| inventory.v1.decorative.theme | Native theme/paper materials | decorative_not_standalone_action | — | Q-UI07-043, Q-UI07-044, Q-UI07-045; native NOT_RUN |
| inventory.v1.decorative.row-layout | Library list layout/chevrons | decorative_not_standalone_action | — | Q-UI07-043, Q-UI07-044, Q-UI07-045; native NOT_RUN |
| inventory.v1.decorative.reader-label | Canonical location label rendering | decorative_not_standalone_action | — | Q-UI07-043, Q-UI07-044, Q-UI07-045; native NOT_RUN |
| inventory.v1.shell.donation | Existing donation information sheet | meaningful_original_control_or_state | — | Q-UI07-013, Q-UI07-014, Q-UI07-017; native NOT_RUN |
| inventory.v1.search.command-palette.close | Visible palette Cancel action | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-sefaria-match | global-search-sefaria-match | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-sefaria-distance | global-search-sefaria-distance | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-options-validation | global-search-options-validation | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-options-content | global-search-options-content | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-options-done | global-search-options-done | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-positive-scope | global-search-positive-scope | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-distance | global-search-distance | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-word-match | global-search-word-match | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-word-count | global-search-word-count | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-negative-query | global-search-negative-query | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-negative-scope | global-search-negative-scope | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-negative-distance | global-search-negative-distance | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaEnablesPrefixes | toggle-otzariaEnablesPrefixes | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaEnablesSuffixes | toggle-otzariaEnablesSuffixes | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaEnablesSpellingVariants | toggle-otzariaEnablesSpellingVariants | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaEnablesAramaic | toggle-otzariaEnablesAramaic | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaIgnoresQuotes | toggle-otzariaIgnoresQuotes | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaMatchNikud | toggle-otzariaMatchNikud | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-otzariaMatchTaamim | toggle-otzariaMatchTaamim | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-spacing | global-search-spacing | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-alternatives | global-search-alternatives | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-grouping | global-search-grouping | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-zayit-match | global-search-zayit-match | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-rerun | global-search-rerun | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-dirty | global-search-dirty | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-cancel | global-search-cancel | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-loading | global-search-loading | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-cancelled | global-search-cancelled | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-filter-empty | global-search-filter-empty | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-retry | global-search-retry | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-error | global-search-error | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-index-status | global-search-index-status | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-missing-index | global-search-missing-index | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-empty | global-search-empty | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-page-retry | global-search-page-retry | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-page-error | global-search-page-error | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-options | global-search-options | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-books | global-search-books | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-mode | global-search-mode | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-header | global-search-header | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-history-clear | global-search-history-clear | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-history | global-search-history | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-count | global-search-count | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-result-filter-toggle | global-search-result-filter-toggle | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.toggle-sefariaReverseSort | toggle-sefariaReverseSort | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-sort | global-search-sort | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-result-filter | global-search-result-filter | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-result-filter-done | global-search-result-filter-done | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-results-header | global-search-results-header | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-saved | global-search-saved | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-save | global-search-save | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-data | global-search-data | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-reset | global-search-reset | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.search.native.global-search-more | global-search-more | meaningful_original_control_or_state | — | Q-UI07-006, Q-UI07-007, Q-UI07-008, Q-UI07-038; native NOT_RUN |
| inventory.v1.native.library | Native original Library/current tab | meaningful_original_control_or_state | native.library / native.library.contents | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.reader.toc | Native original TOC/current tab | meaningful_original_control_or_state | native.reader.toc / native.reader.toc.contents | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.history | Native History/current tab | meaningful_original_control_or_state | native.history | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.search | Native Global Search/current tab | meaningful_original_control_or_state | native.search | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.annotations | Native Annotations/current tab | meaningful_original_control_or_state | native.annotations | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.settings | Native Settings/sheet | meaningful_original_control_or_state | native.settings | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.reader.inspector | Original Reader Study Tools panel | meaningful_original_control_or_state | native.reader.inspector | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.reader | Native Reader/current phone or iPad book | meaningful_original_control_or_state | native.reader | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.reader-new-tab | Native Reader/new phone or iPad tab | meaningful_original_control_or_state | native.reader | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.foreground-intent | Foreground App Intent | meaningful_original_control_or_state | — | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.shortcut | Native destination App Shortcut | meaningful_original_control_or_state | — | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
| inventory.v1.native.reader-intent | Open source book at chapter or passage / original Reader | meaningful_original_control_or_state | — | Q-UI07-023, Q-UI07-028, Q-UI07-031; native NOT_RUN |
