# Verification status

The package contains the complete source path needed for:

1. Building a prebuilt index from `seforim.db`.
2. Opening that index read-only in the Rust runtime.
3. Calling the runtime from Swift through a C ABI.
4. Selecting the external data folder on iPad through a security-scoped bookmark.

Checks performed while packaging:

- Package tree and required files checked.
- Shell scripts parsed with `bash -n`.
- Python sync script compiled with `py_compile`.
- ZIP integrity checked with `unzip -t`.

A Rust toolchain and Xcode are not installed in the packaging environment, so `cargo test`, the full index build and the iOS XCFramework build must run in Codex/GitHub Actions. The included integration instructions require those checks to pass before app integration is accepted. Do not suppress compiler errors or replace the engine with a stub.
