# Ordinary Settings: real metadata failure, recovery and retry

This is an additive test-only extension to `f868e166e0f01c86049de71ccc7226bf11c47e45`. It changes no installer, release lookup, native observer or production control.

The existing original Settings case now requires this sequence after its real public v41 partial download and pause:

1. Terminate the app. Refuse an existing previous database, previous manifest or pending manifest. Create a unique token file exclusively at `seforim-installation.json.previous` and set its real filesystem immutable attribute.
2. Cold-open the original v40 reader. Require retained download bytes, the original logical user data and the exact immutable token. Resume through the original Settings install control.
3. Require the native error label to identify the exact metadata backup filename. A network failure, low-space error, missing UI success or arbitrary error cannot satisfy this gate. Require no success state and an available original retry control.
4. Independently hash the restored full v40 database and old installation manifest, compare all populated logical user data, and retain the visible error and screenshot as XCTest attachments.
5. Terminate the app. Clear the immutable bit and remove the obstruction only after regular-file type, byte count and exact unique token identity match. Cold-open the restored reader and repeat the old database, manifest, locator and data checks.
6. Retry the same actual latest release through the original Settings control. Preserve the existing official release/asset identity, full SQLite integrity/count, transaction/download cleanup, data preservation and final cold-open/up-to-date gates.

The test's failure cleanup likewise removes only the verified owned token. It refuses a changed or foreign file. It does not alter corpus bytes, source databases, ordinary user stores, shared storage permissions or network responses.

## Source inspection

The inspected installer is the exact transaction repair in `0d0a010c3ee1edda244f9fb37431016d12320234`; file SHA-256 `1bc7ada3b324d76a57ced0f168cd2566d5948009f412e8f1a7027c0b09ce3d34`. `promote` first recovers, replaces the validated database with a retained previous database, then writes the pending manifest. It does not remove the previous manifest before this point. `completePromotion` tries removing the previous manifest before moving the old stable manifest; that is the intended real failure. The adapter closes the new connection and rolls back. With both pending and stable manifests present, rollback preserves the old stable identity even if the previous-manifest path is an obstruction.

On the initial cold-open there is no previous database or pending manifest. Successful old-library restore may attempt best-effort previous-manifest cleanup, whose caught error leaves the immutable token intact. The UI controller exposes `error.localizedDescription` through `otzaria-update-error` and retains the actual install action after failure.

## Evidence boundary

Status at this source commit: **UI NOT_RUN; revised test Apple typecheck NOT_RUN**. The earlier test version's SDK typecheck and the transaction implementation's native nine filesystem controls remain separate receipts. They are not claimed as this UI failure/retry acceptance. Execution belongs to the parent's common simulator lane after the v40 installation, search and reader gates. No extra corpus, simulator or independent build was started for this extension.
