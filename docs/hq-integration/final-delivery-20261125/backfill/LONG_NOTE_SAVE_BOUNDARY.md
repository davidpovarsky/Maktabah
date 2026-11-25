# Preserve original note text during native Backfill

Source implementation only; targeted native/component acceptance is pending.

The ordinary LocalEditor prepare/Save path retains its original canonical intent
fields, digest construction and preview replacement behavior. A separate first-body
Backfill intent permits preserving the existing full note. It refuses an existing
rich/unsupported/deleted/stale body, missing or invalid saved text, a preview that
is not its byte prefix, and a short-note preview that is not byte identical.

The iOS Session entry accepts only the original SDK's closed
AnytypeOriginalEditorLocalAnnotationCapture and actual local native session.
validateCapturedSource must prove the current original owner and exact captured
archive/body. The Host independently checks profile/UUID/revision/source/provenance,
the native fullPlainText against the saved note's exact UTF-8 bytes, and the unchanged
original SQLite snapshot. It does not accept an arbitrary replacement full-text
String or manufacture an SDK capture.

The new preservation intent includes an explicit mode and original text SHA in
its canonical digest. Under the same original transaction, source/revision/pending
delete checks run before writes. The preserved text is taken from the actual
current SQLite row and must still equal the captured original bytes. The original
rich body/version, timestamp, pending CloudKit upload and source witness commit
atomically. The envelope preview remains at most 8192 UTF-8 bytes; no Anytype
remote acknowledgement or destination is created.

The native Backfill consumer and supported seed-size admission are coordinated
separately with the final closed batch SDK. Existing >8192 retention is not yet
removed by this source checkpoint. Current 36/14 tests have not run; regenerate
their exact final source closures and retain old blocked/failed attempts.
