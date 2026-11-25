# Explicit native Backfill conversion — source checkpoint

## Scope and ownership

This change extends the existing preparation screen with an explicit second action
for already saved notes. It uses the public original Anytype local-annotation
factory and capture API, followed by the existing original Maktabah local Save.
It is based on Maktabah `75058d1c1abbfb0fb37fc819dcece47b853eb4da`.
The SDK product API inspected is
`a91d572cb2df2b05c7d93520732eecd7380294fd` (175 exact public/Debug requirements).

Changed product files are restricted to
`Source/ChavrusaText/Annotations/Backfill/`. The original planner, local editor,
exchange ledger, identity mapping, SDK, and native engine are unchanged. Root
integration must register the three new Swift files for the iOS target:

- `AnnotationNativeBackfillCatalog.swift`
- `AnnotationNativeBackfillModel.swift`
- `AnnotationNativeBackfillSection.swift`

## Actual path

1. The user completes the existing local preparation and explicitly confirms
   conversion in the current study workspace. Merely opening/rendering the screen
   performs no new scan, native initialization or conversion.
2. The worker captures the actual repository connection and native workspace
   owner, profile, scene, epoch and projection. An invalidated mapping or original
   connection retires that run permanently.
3. Read-only batches select at most 25 original rows. The selection resolves
   existing registered UUIDs without registering or rewriting them, verifies the
   existing preparation's exact source/text/body digest, and retains existing
   opaque rich bodies, highlights, pending deletions, unsupported documents and
   longer notes.
4. A fresh real LocalEditor session reads the canonical saved row. Its captured
   source/revision/body/identity is compared with the selected candidate.
5. The original `openLocalAnnotation(.plainText(savedText))` factory creates its
   private local-only draft. No replacement block schema is synthesized and no
   editor view controller is fabricated or required by this worker.
6. The source is checked after the factory await. Actual
   `captureNativeSnapshot` returns the original native archive. The worker
   verifies its provenance and exact saved-text preview, then re-reads the
   canonical source again after capture.
7. The unchanged `prepareSave` / `save` path performs the original SQLite CAS,
   immutable rich version commit, original pending upload queue and configured
   CloudKit behavior. It introduces no Anytype share destination or remote ACK.
   A real commit remains counted even if ownership is lost after COMMIT.
8. Each draft is retired. Completion/cancellation also awaits the original
   SDK AccountStop/drain through an independent cleanup task. A failed Stop is
   visible and can only retry the retained SDK Stop; it does not replay a body
   mutation or create another account.

Cancel before native capture/Save never publishes that draft. Cancellation
racing an already admitted canonical COMMIT preserves the actual committed
receipt and saved note. Reopening and explicitly continuing reads current
canonical bodies; it skips completed rich notes instead of trusting a saved
cursor as authority.

## Byte preservation and the current long-note boundary

The current original SDK text preview is UTF-8 bounded at 8192 bytes. The original
LocalEditor `prepare` also bounds the preview at 8192 bytes, and `commit` writes
that preview into the original `annotations.note`. Therefore this worker admits
only a complete saved note at or below that byte limit whose original native
preview is exactly equal in UTF-8 bytes. It rejects whitespace normalization,
Unicode normalization, truncation, embedded NULs or any other difference.

A longer saved note is retained unchanged and counted visibly. It is not treated
as converted. The unchanged planner can still prepare its complete text digest;
a truncated planner preview is never used as conversion text.

The original persistence `read` returns the saved original row and envelope
without requiring `annotation.note == envelope.textPreview`. A future complete
long-note migration needs a deliberate Save contract separating full saved text
from the bounded display preview, including source/CAS, CloudKit and reopen
regressions. Raising a cap or saving the existing truncated preview would not
satisfy data preservation. This change does not claim that remaining contract
has been completed.

## Verification status at this checkpoint

- Python AST and fixed source/case/localization structure checked on Oracle.
- No Apple compilation or runtime result is claimed yet.
- `tools/hq-native-annotation-backfill-acceptance.py` defines 14 focused new
  controls and a separate cold-process canonical rescan. It compiles whole
  original Store/Repository/SQLite/local-save sources plus the unchanged planner
  and new catalog on the real Mac. Explicit existing UI/catalog/CloudKit doubles
  and `test.opaque` fixture bodies are identified in the report.
- The component gate verifies source/profile retirement, current preparation,
  original UUID and legacy CloudKit identity, opaque/future body preservation,
  byte-exact previews, Hebrew/emoji 8192-byte boundaries, an unchanged 8193-byte
  note, pending deletion/highlight exclusion, no read-side schema/data writes,
  bounded cursor/session rejection and canonical resume.
- The future-envelope fixture first commits a supported original version, then
  explicitly injects controlled future-version stored bytes. Current production
  `commitLocal` still refuses unsupported versions. No fabricated native body
  is used as an engine acceptance result.
- Native worker and UI files are recorded as source provenance by that component
  gate; they are not compiled/executed by its macOS Foundation fixture.
- The existing original Backfill planner's 13 checks and 5000-row local
  preparation evidence are unchanged and are not rerun or relabelled here.
- Existing atomic-save 43+2 and native-import 66 evidence remain historical proof
  for their exact unchanged source closures.

Still required on the final integrated app/native SDK: actual iOS compilation,
headless original factory/capture on saved Hebrew/English notes, ordinary UI
progress/pause/resume and cancellation, configured CloudKit Save behavior, and
actual 5000-native-note performance/resource acceptance. The 5000-row local plan
and this component's cold process do not establish those results.

## Reproducible component command

Run only on the existing actual Mac through the pinned Oracle SSH route, with a
fresh evidence directory and a current storage/concurrent-growth estimate:

```text
python3 tools/hq-native-annotation-backfill-acceptance.py \
  --artifacts-dir <owned-fresh-evidence-directory> \
  --expected-growth-bytes 1073741824 \
  --concurrent-growth-bytes <current-measured-reservation> \
  --os-margin-bytes 5368709120
```

The runner preserves actual compile logs, case results, separate process IDs,
source/binary hashes, SQLite readback, before/after source identity, elapsed times
and owned disk usage. `/usr/bin/time -l` captures real compile resource data.
It does not install a compiler, touch another job's DerivedData, alter qualified
SDK products, or run on Linux.
