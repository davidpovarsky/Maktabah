# Stage B actual pre-build serialization failure

Run 45167025321, attempt 1, source fa816b14d25a4ced0031b1a9c972040b89cb451e reached the original app-target helper with Ruby 3.4.12 and Xcodeproj 1.28.1. The helper rejected its saved project before any app compilation because only OTHER_SWIFT_FLAGS and SWIFT_INCLUDE_PATHS changed from arrays to their exact ordered space-joined strings. The nineteen complete -Xcc/module-map pairs are retained.

The authenticated artifact preserves both the rejected saved project and the byte-identical restored original. Source reconstruction retains all before/expected/after settings, confirms every other setting and all 2,358 unrelated objects unchanged, and records exactly the one intended embed phase. This reconstruction is not a full Ruby helper execution or native PASS.

The one observer is closed and reaped, its owned process group drained, and final source/attempt metadata matched. The full original archive and 224 safe unique CRC member records are retained. An initial Oracle CLI flag refusal is preserved separately from the successful supported binary download. No UI journey ran, no retry was dispatched, and no new SDK was built.

Asana diagnosis comment: 1220788303892173.
