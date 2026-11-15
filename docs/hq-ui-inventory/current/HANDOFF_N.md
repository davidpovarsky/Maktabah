# UI01 current native surface contract for N — 15 November 2026

U, actual Desktop UUID `01a1df8a-3373-79e3-b7fa-f6a06cc8b578`.
Source/runtime checkout `5afdefdf7fae792eeb7a828dc9157e8cecab7f93`;
production Cancel source `40e642349814568ccae4437cb914f01f0c12420b`.
This is a source-qualified navigation inventory handoff, not functional UI01
completion. Source task `1220542479938540` stays OPEN.

`UI01_CURRENT_HANDOFF.json` resolves all 227 retained semantic rows from immutable
U inventory `0b19ded4265ae0f0b6d05571b1c23b7bb3d423f8`, adds one actual visible
palette Cancel control, and verifies 574 current app/integration code files plus
176 exact pinned external files (750 total). Every row has current source
blob/hash/line, state owner, input privacy, three explicit backend cells and
readiness/receipt limits. `RECONCILIATION_REPORT.json` records the complete delta.
Reproduce with `py -3 docs/hq-ui-inventory/current/reconcile.py --source <full-SHA>`.
No Source or another developer's worktree is modified by this helper.

## Exact integration surfaces

| Native surface | Existing owner / connection | N must preserve |
| --- | --- | --- |
| Foreground scene | MaktabahApp WindowGroup; ReaderSceneIdentityReader; scene-lived Exact9401WorkspaceLifecycle | Exact scene identity, backend generation, cancellation and current selection. Never choose first foreground scene as an exact-scene receipt. |
| Library / TOC page | ReaderSidebarPageCoordinator.page / ReaderSidebarPager native TabView | Stable Library/TOC identities; activeContentsReaderID follows actual active-tab UUID; query/tree/TOC state remains page-local; reader is sibling and must not remount. |
| Sidebar visibility | Existing NavigationSplitView / public split configuration | Exactly one native toggle; columnVisibility / preferredCompactColumn are authoritative. Do not add a second button or overwrite UIKit's system icon. |
| Library search | Existing LibraryViewModel.searchQuery and current visible searchable attachment | Canonical catalog filter is separate from global content search/history; query is private and is not a public URL payload. |
| Library command palette | Exact9401ViewerToolbar.isPresented -> LibraryCommandPaletteAdapter -> CommandPaletteView | The instantiated native toolbar is the entry point. ChavrusaReaderHost also has source but is not the current iPad host. Cancel must remove real input and presentation; a missing AX container is insufficient. |
| Reader/tab/group | iOSNavigationManager + existing StudyWorkspaceNavigationAdapter | Current backend, exact persisted tab UUID and locator; narrow initial-empty adoption correction retained. No saveCurrentState call merely to observe a receipt. |
| Inspector | Existing MaktabahTorahInspectorSession / OtzariaReaderSourcesInspectorHost + pinned Kit | Same exact backend/work/selection; shared source host does not prove Embedded source qualification or actual related-text presentation. |
| Notes/drafts | Existing annotation editor and repository callbacks | Draft navigation differs from Save/Delete. No public URL note text or implicit mutation. |
| Settings / history / existing legacy links | Inventory's exact source anchors | Only numeric history/annotation widget URLs are already source-wired. Proposed inventory IDs are not registered routes or AppIntents. |

## Current source differences and limits

The old inventory was based on `2918825b`, which included portable ActionCore.
The actual R27 tree has no `Source/Otzaria/Actions` package: 18 code files are
absent, rather than silently installed implementations. Every linked action is
now explicitly historical/proposed, `catalog_present=false` and
`core_v1_implemented=false` at this runtime pin. N must consume P's corrected,
tested UI02 contract through manager integration; do not restore the old core
or derive authority from action names in this inventory.

Only three app code files differ from the old census: the palette package,
palette adapter and workspace startup-race correction. Native sidebar source
and original UI hooks are unchanged from the retained U implementation.
The new Cancel source uses the real visible esc control and native standard
cancelAction shortcut; its actual native result is tracked separately in
run43723356743. Do not turn a candidate, screenshot filename or NOT_RUN into a
runtime receipt. All new UI03–UI06 routes remain unimplemented here.

Exact external pins remain Embedded `2fd173a5...` and InspectorKit
`19d1b353...`. Existing caveats remain: no app construction of the full Embedded
native surface host, Legacy/Embedded Inspector provider-identity qualification,
runtime ObjectIdentifier move targets, no app Universal Link domain/AASA, and
no accepted in-process Hanlin host at this source. The full caveat evidence is
included in the current JSON.

Sidebar physical acceptance, RTL/LTR gesture arbitration, row/TOC state,
accessibility, and requested TOC-specific toggle icon remain OPEN. The public
classic displayModeButtonItem is not a documented column-style image setter;
retaining the native symbol or changing the interaction requires manager's
product decision. N can implement honest unsupported/queued/stale outcomes
without inventing readiness or silently switching backend.

Validation is main-session source/semantic reconciliation. No separate reviewer
was spawned; no UI01 native route or physical-device acceptance is claimed.
Manager owns coherent integration with P, then N's independent worktree.
