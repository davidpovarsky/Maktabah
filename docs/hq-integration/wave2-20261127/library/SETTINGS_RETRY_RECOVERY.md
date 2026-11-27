# Ordinary Settings: real metadata failure, recovery and retry

This is an additive test-only extension to `f868e166e0f01c86049de71ccc7226bf11c47e45`, adapted to the retained-marker repair `3f062f6c97c12709ae0757fdeb1f7ece86674332`. It changes no installer, release lookup, native observer or production control.

The existing original Settings case requires this sequence after its real public v41 partial download and pause:

1. Terminate and cold-open the original v40 reader. Require its exact reading position, logical user data and retained download bytes. No update is active.
2. Refuse any existing previous database, previous manifest or pending manifest. Create a unique token file exclusively at `seforim-installation.json.installing` and set its real filesystem immutable attribute. This happens after ordinary launch recovery has finished; launch recovery must never consume the injected pending token.
3. Resume through the original Settings install control. Require the native error label to identify that exact pending metadata filename. A network failure, low-space error, missing UI success or arbitrary error cannot satisfy this gate. Require no success state and an available original retry control.
4. Independently hash the restored full v40 database and old installation manifest, compare all populated logical user data, and retain the visible error and screenshot as XCTest attachments.
5. Terminate the app. Clear the immutable bit and remove the obstruction only after regular-file type, byte count and exact unique token identity match. Cold-open the restored reader and repeat the old database, manifest, locator and data checks.
6. Retry the same actual latest release through the original Settings control. Preserve the existing official release/asset identity, full SQLite integrity/count, transaction/download cleanup, data preservation and final cold-open/up-to-date gates.

The test's failure cleanup likewise terminates the app and removes only the verified owned token. It refuses a changed or foreign file. It does not alter corpus bytes, source databases, ordinary user stores, shared storage permissions or network responses.

## Source inspection

The inspected candidate installer SHA-256 is `57b459d6f43bd143236a2616dd9f8298ed48387e727e3903077caa178c5315f3`. With a final database and no previous database, `recoverInterruptedInstallation` does not consume the pending path. After retiring previous transaction artifacts, `promote` replaces the validated database while retaining its previous database, then attempts the pending manifest write. That real write must fail on the owned immutable file. Its catch path restores the previous database and retains the stable manifest; best-effort removal of the immutable pending token fails and leaves the exact owned token available for verified test cleanup.

The earlier test version in `312d147bbc945c88153f5b922b4bce3c53b21a75` placed the obstruction at the previous-manifest path. The retained-marker repair now correctly rejects that obstruction before replacement, so it cannot prove post-replacement rollback. This followup uses the pending-identity path and does not relabel that earlier unexecuted version as acceptance.

The original Settings UI controller exposes `error.localizedDescription` through `otzaria-update-error` and retains the actual install action after failure. Repeating that original action after the safe cleanup and cold reopen is the retry.

## Evidence boundary

Status: **UI NOT_RUN; revised test Apple SDK typecheck PASSED**. The earlier test version's SDK typecheck and the transaction implementation's native filesystem controls remain separate receipts. They are not claimed as this UI failure/retry acceptance. Execution belongs to the parent's common simulator lane after the v40 installation, search and reader gates. No extra corpus, simulator or independent app build was started for this extension.

## Observed revised-source typecheck

SentinelX `job_102a06588402` typechecked exact source `1bcfddc949f1b004de650505dcdedd0e4cd2ab29`, Swift file SHA-256 `869be2f45cae8323227ca48599aac47029277c44335bc9d917045dc1c418e139`, at 2026-11-27 00:12:14–00:12:15 UTC. Actual compiler exit: **0**; 74 inherited warnings, **0 warnings in the new class**, 0 errors. The existing private module cache was reused. Both admitted source hashes matched after execution. `settings-ui/typecheck-attempt-3/RESULT.json` SHA-256: `e46883cfccffaf37c6a52946b37ec81501e67e7dd1bfabbcf9e64342d951b447`. Raw logs are retained on both hosts and archived losslessly with hashes in Git. Earlier typecheck attempts remain unchanged. No app, simulator UI or corpus ran.
