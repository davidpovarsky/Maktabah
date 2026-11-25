# Original Anytype lifecycle Host integration

Status: SOURCE ONLY. Apple typecheck, integrated runtime/UI and device delivery are pending.

This normal saved-note entry requests an actual read in the original selected
Anytype account and Space, shows the content/status/action, then asks for one
explicit confirmation. The declared current type is only a selector for the
SDK's separate original Annotation or manifest-bound Document verifier; it
cannot grant permission, manufacture an SDK observation or change the schema.

| Action | Native route | Local saved note |
| --- | --- | --- |
| Archive / restore | Original Archive collection membership with root and Archive CAS | Unchanged |
| Annotation to chiddush / article / research | Original type mutation and manifest/type witness | Unchanged |
| Return promoted document to Annotation | Original registered Annotation type and current Document witness | Unchanged |
| Update promoted document | Separate original promoted replacement, using the actual saved local Annotation snapshot | Unchanged |

The UI refuses content/type changes to an archived copy until it is explicitly
restored. It performs one choice per presentation. A promoted document is never
materialized as an Annotation by the Host; receiving it requires a verified
return to Annotation first. Private drafts stay in the existing local-only
original editor and are never used by these operations.

The Host reuses the existing tested local native revision preparation and exact
saved-row ownership fence. The original SQLite possible-dispatch transaction
stores the complete SDK request and SHA before the one-use native invocation.
It does not weaken or reuse the permanent fresh-import identity fence.

The new separate history preserves the complete local payload, actual native
body/read response, root and Archive witnesses, type, exact request, cancellation
facts and actual drained response. Files are paired by exact UUID/path/SHA and
written atomically with iOS protection. The callback retains its durable write
independently of UI ownership. A conflict label requires both native apply and
native write effects to be explicitly false. Partial effects and unknown/cancelled
results remain unverified; no automatic retry, fabricated rollback or remote ACK.

Only an actual verified promoted replacement adds a newer saved-body mapping.
Archive and type changes must not claim that a different local body was sent.
Decoded files are historical data only: SDK authority always comes from a fresh
closed current-account read.

Implementation:
- AnnotationOriginalEditorLifecycle.swift: source fence, one-use native bridge,
  immutable read/request/result evidence, late history and mapping discovery.
- AnnotationOriginalEditorLifecycleUI.swift: ordinary account/Space selection,
  typed review and confirmation with accessibility IDs.
- Production entry, mapping discovery and iOS PBX registration are connected.
- 35 added strings have English and Hebrew translations. Prior translations are
  byte-preserved.

Required SDK surface remains under active qualification with the SDK owner:
closed LifecycleObservation previews, revertPromotion, and the separate
preparePromotedDocumentReplacement returning the existing typed lifecycle history.
No runtime result is asserted by this source checkpoint.
