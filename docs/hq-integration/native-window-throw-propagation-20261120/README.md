# Propagate the original throwing test helper

The compact Study Tools helper can throw after its original XCTest unwrap/uniqueness guards. Its caller exerciseNativeWindowResize lacked throws, and its two existing XCTest callers lacked try/throws. This would prevent the complete native test target from compiling. Windows frontend syntax parses do not typecheck this requirement, and earlier records correctly did not claim Apple compilation.

This change adds only throws propagation in the helper and both existing XCTest methods, plus try at both call sites. Exact inverse restores every original byte. All source/locator/toolbar/window/Inspector/viewport/persistence assertions and deadlines remain unchanged. The XCTest runner receives the original error. No forced try, catch-and-success, skipped method or generated result is introduced. Actual Apple compilation and Native execution remain required.
