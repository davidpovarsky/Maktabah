# Owned cloud observer registration — strict-concurrency correction

The first real Apple run of the new Cloud48 source failed before its local43 or Cloud48 cases executed. Run **44792622640**, attempt1, used frozen head **452a04c2b05150694d8120ed465afb48da190af3**, product source **57e4a1cb7cd0bee72e3042e2f4567972237e7e35** and the actual Xcode27.2/Swift6.4 toolchain. The complete artifact is **14656519348**, 995,050 bytes, SHA256 **1e3fab2c767e19ef673c951e63dd05c50cf0a78bffd070b8d5be1acca9b2e116**. Its114 ZIP entries passed CRC verification. Root owns the separate complete failure packet; this source correction retains its exact compilation log and identity.

The complete local compilation log contains one production diagnostic: assigning an outer `NSObjectProtocol` observer token into `Mutex.withLock` leaves the `inout sending` value connected to the current isolation region. Both generated executable copies of `AnnotationLocalEditorCloudOwnership.swift` match the canonical source exactly. This is an actual production compilation failure, not a synthetic fixture error. Generic compiler/build-failed messages follow the same diagnostic.

## Narrow change

The token is now created directly inside the existing `observer.withLock` closure and stored in that closure's protected value. No non-Sendable token local remains outside that operation. The same original NotificationCenter, name, nil object, nil queue and callback are used; registration still completes synchronously before any account lookup can begin.

The callback captures only the existing Sendable one-way lifetime and retires that lifetime. It does not read or reacquire the observer-token mutex, so a notification delivered during registration does not introduce a callback into the same lock. The initialized observation cannot be released by an external caller before its initializer returns. The original deinitializer still clears and extracts the token under the mutex, then calls the original `removeObserver` outside the lock.

The change adds no unchecked conformance, preconcurrency import, actor hop, detached task, fallback, or permission grant. Account/source/connection guards, pending acknowledgment, remote-outcome distinctions and all other product bytes remain unchanged. The whole-file inverse in `SOURCE_PROOF.json` returns the exact prior source.

## Verification boundary

The actual failed Apple compilation is the retained baseline. This candidate has **not** been Swift-typechecked or executed locally; no compiler was installed. The same whole-source Apple route must compile it and execute the unchanged48 account/ownership controls, unchanged original43 plus cold reopens and original28 exchange/crash controls. Existing cases already cover synchronous notification retirement, account ABA and owner isolation. No assertion, deadline or case declaration is changed by this correction.

The initial failed run's independent original exchange28 and two crash/reopen controls passed. That result does not qualify the uncompiled owned-cloud source. Its warnings and raw results remain in Root's complete failure packet.

This candidate is authored separately from the frozen failed execution branch. It does not activate a workflow or rewrite the failed ref. Root will bind the corrected source into the next reviewed closure.
