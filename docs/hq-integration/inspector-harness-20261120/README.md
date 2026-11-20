# Original Inspector/Sefaria harness hang: retained baseline

The normal iOS run 44672943654 compiled and launched the original standalone mapping harness, but its simulator job was cancelled after 75 minutes without a completed test result. The exact authenticated CI evidence is in ../normal-ios-44672943654-20261120/. A root cause has not yet been attributed.

## Actual exact-source Windows baseline

Sentinel job job_35e84e81f942 ran 2026-11-20T06:48:15Z–06:51:49Z. It loaded all 38 Swift input files and seven fixture files from immutable checkout 127ee9eddc2a9aea05c45ccf41420bb0cdd47705, 433,789 bytes total. Every input remained byte-identical before and after execution.

- Original compile flag OTZARIA_INSPECTOR_MAPPING_TESTS and original entry point retained.
- Invocation delta: Windows Swift6.3.3 replaces xcrun Swift; an explicit isolated module-cache output directory was added. Apple-only conditional branches are not compiled on Windows.
- Actual standalone compilation: exit0, 91.828 seconds, zero compiler warnings.
- Executable: 3,118,592 bytes, SHA256 ba82385d36f3b31f25df992cf8376c8f658920ed01061ba1ff312d0eac521b8a.
- Actual runtime: exceeded120 seconds, terminated only its owned process tree (PID26980), final exit1 after120.406 seconds.
- Stdout and stderr were empty. **No completed test case or suite was verified; the number of internally entered assertions is unknown.**
- The executable and exact source copy remain in the ignored baseline build directory; source hashes and launcher are retained here.

This is a portable reproduction of an incomplete/hung original harness. It is not proof that the Windows and macOS hangs have the same cause, nor a passing app/Apple/Native result. The successful separate SDK Inspector-owner fixture has a different scope and explicit DTO doubles.

## Next diagnostic boundary

The subsequent diagnostic run may add before/after logging around original test entry calls and assertions in an ignored test-only copy. It must reconstruct the original bytes exactly after those logging additions are removed, preserve every test condition, and leave all production source inputs unchanged. No timeout increase, test removal, fabricated completion or successful native claim is authorized by this baseline evidence.

The current isolated branch is based on f064b5517f560e2b52838bf321214baa3fb09e2c. Only BackendCoordinator.swift differs between that base and the historical harness input set; therefore this baseline deliberately uses the historical exact file, not a mixture of revisions.
