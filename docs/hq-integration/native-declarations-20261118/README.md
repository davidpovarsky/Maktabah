# Native54 selection failure and compiler declaration fix

Run44320497938 checked out c0599822410b95509cf92d2fe5cf202a0a263e2c with application/test source1a90fc3ef7d6c30dcb1ce6df2aa2c4fd6a502855. The complete app and XCTest build-for-testing passed on Xcode27.1. All54 selected UI cases remained NOT_RUN. This is not a product Native PASS.

The existing verify-faithful-xctest source regex treated text from a class to the next class as that class's methods. It assigned later extensions to the wrong suite and missed inline @MainActor func declarations. Twelve selected declarations were rejected before any simulator/test execution.

The checker now invokes the actual installed Swift frontend in syntax-only dump-parse mode for each actual source file, reads direct class/extension zero-argument test members, and preserves exact suite ownership. Every file is explicitly parsed because the frontend emits only the primary file's parse tree. Unknown syntax/output, missing declarations and duplicate methods fail closed.

The exact Native selection is now checked before the expensive app build and during the existing actual Apple SDK check. Eight regression tests cover extension ownership, attributes, multiple source files, comments/literals/nested helpers, duplicates, unknown classes/methods, syntax failure, and unchanged pass/fail/missing-log behavior. These are compiler fixtures and log checks, not Native UI acceptance.

Runtime xcresult parsing, exact source pins, required case counts, zero skips, failures, deadlines and original UI assertions are unchanged. The original54-case artifact and failed driver log are retained; no historical pass is copied to a new source.
