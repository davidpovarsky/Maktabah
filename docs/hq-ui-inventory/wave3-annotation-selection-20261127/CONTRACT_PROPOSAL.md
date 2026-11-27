# Original Annotations selection and control navigation

Status: approved bounded first implementation; source investigation only so far.

Immutable input: `37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be`, Source tree `7afa76212dec72644917e6aaff3257ca56a14ccf`. Sixteen original files (188,647 bytes) were read from exact Git blobs and independently hash checked; `SOURCE_INPUTS.json` is the input ledger. Root owns the final shared-file application. No Apple SDK, application or native execution is claimed.

## Original requirement

UI-03 (Asana `1220542361203468`) explicitly requires Notes/Bookmark/History selection, draft without save, exact component focus/selection/scroll and acknowledgement from the actual view. It also requires cancellation/deadline, exact scene/backend generation, retained display state and no silent backend change. UI-04 (`1220542420331748`) requires thin system wrappers through the original registry and executor, backend-qualified entities and actual stale/foreground/multiple-window tests.

Inventory rows are distinct obligations: `inventory.v1.annotations.list`, `.filter`, `.book`, and `inventory.v1.notes.editor.body`, `.tags`, `.style`. The original `.filter` row includes **tag, grouping and sorting controls**; revealing the tag button alone cannot close that row. The `.book` row belongs to `iOSBookAnnotationsView`, not a global list group with the same title. Save/delete/import/export remain their original independently confirmed actions.

## Observed original ownership

| Surface or state | Actual original owner | Consequence |
| --- | --- | --- |
| Loaded global annotations and filters | `AnnotationViewModel`, backed by `AnnotationTreeBuilder` and `AnnotationStore` | Retain the actual published list and input state, rather than load a second list. |
| Original cells, section expansion, selection and scroll | `iOSAnnotationViewController` and its actual diffable data source | A completion must join the selected index path, configured `Annotation`, cell identity and window geometry. |
| Original normal row tap | `AnnotationViewControllerWrapper.Coordinator.handleSelection` | This opens the Reader and can call `BackendCoordinator.commit`; a reveal-only action must never call it. |
| Existing saved-note editor presentation | `AnnotationListView.editingAnnotation` | Future edit presentation must use this captured original setter, not create another sheet. |
| Editor body/style/tags and Save/Cancel | `iOSAnnotationEditorSheet` | Future focus must preserve its State and `allowsPlainEditing`, including the formatted Anytype gate. |
| Book-specific list | `iOSBookAnnotationsView` | A separate original Reader-owned surface; not covered by global-row completion. |

## First finite slice: exact published original global row

The first action is a typed `RevealAnnotationIntent` over a real queried entity. It operates only on an already mounted original Annotations list in the chosen scene. Metadata may resolve while that same scene is backgrounded, but effects still require the original bounded foreground admission. Cold or another-root entry is explicitly unavailable in this slice.

The public entity identifier is an opaque, host-minted reference to a private source capsule. The capsule retains the exact scene/window observation, manager/model/controller identities, original mapping/backend authority, list publication generation, section and item identities, complete original `Annotation` value and original filter/group/sort inputs. No private note body, tag names, raw SQLite row ID, source authority or scene identifier is accepted as a client effect payload. A record from another backend is not advertised or executed; the action never switches backend.

The actual effect is one synchronous Core-authorized operation on the original collection: expand only the retained original section if needed, scroll to and select the retained original item using the existing collection/data source, and then await actual view evidence within the unchanged five-second deadline. The operation never calls the row-selection delegate, an editor save/delete callback, a backend setter or a Reader opener. Any ordinary expansion factoring must preserve the original `toggleGroup` call's body, arguments, callback order and animation behavior; native navigation may use a finite non-animated expansion argument on that same original owner.

Before any actual effect, the source capsule must still be a member of the same active request/catalog. The one-use selection claim is consumed before UIKit or other callbacks. Reentrant release/replacement, reload, filter/query/group/sort changes, controller replacement/detach, scene/window replacement, backend/mapping changes or cancellation permanently retire the retained source. Source-read validation never grants another effect. An input A→B→A or equal setter publication cannot revive an old reference.

The final receipt must include the exact selected opaque reference and actual parent Annotations surface. It is emitted only when the original collection's selected index path still resolves to the retained full record, the actual cell's `AnnotationContentConfiguration` contains that same record, the cell is visible in the captured window and the independent original parent witness is current. A model-only selection, parent-only receipt or newly created overlay is not completion. Post-effect failure preserves actual outcome/receipt evidence rather than silently changing a refused operation to success.

### Publication boundaries

The original data source remains authoritative for the displayed list. A passive model input publication must invalidate before original filter/group/sort writes, including equal writes. The original 0.3-second search debounce is preserved; discovery refuses while its actual task is pending. Snapshot update/reload/incremental mutation, original user expansion and view replacement invalidate before mutation. No callback installs a fresh proof for a pending request.

The existing `AnnotationStore.events` subscription supplies synchronous invalidation when the original store publishes a change; it is not described as a pre-transaction SQLite lock. This first slice proves the identity of the actual published original row, not an independent database transaction or an editor write authority. Source controls and documentation must keep that boundary explicit. Existing SQL/cache/CloudKit/Anytype transaction owners remain unchanged.

## Exact ownership request

New downstream files, owned by navigation_fix:

- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeAnnotationSelectionBinding.swift`
- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeAnnotationListPublication.swift`
- `Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeAnnotationSelectionIntentService.swift`
- `Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeAnnotationSelectionIntents.swift`
- Focused source controls and later independent native helper suffix plus dedicated acceptance file.

Four original files, narrow hooks only:

1. `Source/Features/Annotations/ViewModel/AnnotationViewModel.swift`: passive input/reload/debounce publication and exact pending-search readiness, preserving all original loads/filters/callbacks.
2. `Source/Features/Annotations/iOS/iOSAnnotationViewController.swift`: original collection host attachment/lifecycle, passive snapshot publication, minimal shared expansion factoring, finite exact original selection and read-only cell evidence.
3. `Source/Features/Annotations/iOS/AnnotationViewControllerWrapper.swift`: explicit forwarding of the same scene binding and exact controller attach/update/detach; all original delegates remain unchanged.
4. `Source/Features/Annotations/iOS/AnnotationListView.swift`: explicit same-session forwarding and passive original modal-state invalidation; original editor/import/export/save/delete effects remain unchanged.

Root-only patch handoff: Session against `a77dd422…`, Composition against `9eb…`, actual projection/registry/Host membership and localization. No direct shared edits, no new public codec/schema, no PBX edits from this lane. Generic `native.annotations` remains unchanged. The new typed selected-row route must not be advertised as a generic root route that bypasses source retention.

## Required focused controls

Controls bind real source bodies and state their UIKit/domain boundaries. They must cover exact current row success, section duplication, identical numeric IDs with different full source identity, wrong backend/scene/window/model/controller, stale snapshot, pending query debounce, input and controller ABA, source release/replacement during callbacks, double apply, cancellation before and after selection, false parent-only/incorrect-cell completion, original source expiry and selected-item receipt mismatch. Original ordinary expansion must have a byte-exact inverse proof after factoring.

Native selectors, separately delivered and unrun until the qualified app exists, must create the actual fixture through original annotation UI, obtain an actual system entity, invoke the real system Intent, and join actual SQL/row/selection/window/receipt oracles. A cached stale refusal must first demonstrate success with the same entity, then invalidate through an original filter/reload/deletion action. No direct service invocation, source injection or synthetic ACK.

## Following required slices

After sealing this row packet, continue the exact original editor/filter obligations:

- Existing editor body and tags: actual editable field focus in the same original sheet, retaining annotation/presentation identity and field draft State; no implicit save, clear, replacement or text insertion.
- Style: reveal the actual original style control without toggling underline or selecting a color. Respect `allowsPlainEditing`; formatted notes that require the original Anytype editor remain truthfully unavailable to the plain-control path.
- Tag/group/sort: reveal the actual corresponding original control, without changing its value. A toolbar launcher alone does not prove a hidden grouping/sort Picker.
- Existing record → original editor and book-specific list: exact separate original parent/presentation contracts; no generic global-row receipt relabelled as either surface.

Root's current ReaderTools/NoteDraft work remains separate. Existing native Annotations-root failure and all final Native116/Release/production/device requirements stay open until actually executed on final integrated source.
