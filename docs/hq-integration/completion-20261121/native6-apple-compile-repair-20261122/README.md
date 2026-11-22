# Native six-case Apple compiler repair

Actual run [44962008465](https://github.com/davidpovarsky/Maktabah/actions/runs/44962008465) used checkout fb6a88f4e6ac3b0bfe0adb0a8992e2b0c3af4b5d and application/test source ee27d8170dd94472856b29307a5478a58e7056eb. The real build-for-testing failed in the original FaithfulReaderUIAcceptanceTests.swift before any selected Native case ran. This is a compiler failure, not a Native test outcome. The earlier Sentinel observer's TLS error is independent of this final CI failure.

The complete original 34-member artifact14732320891 was downloaded once, its 1,209,140 bytes and SHA256 4839413ed695b395aa8b3255a4a0ca56f786be76360665a9896e5a56e69ea7bc verified, and its ZIP CRC checked. DOWNLOAD_RECEIPT.json records all original member hashes. COMPILER_ERRORS.json preserves the bounded original diagnostics.

The two test-source changes add @MainActor to the original pointer/HID test and qualify self.add in the escaping Reduce Motion restoration closure. The real HID bridge, assertions, system-setting restoration and six-case selection remain unchanged.

The existing typecheck-faithful-ui-tests.py now accepts --ui-compile-only. It compiles the original self-contained UI test sources with the actual selected Apple SDK, Swift6 and existing upcoming-feature flags, including code generation. It exits before unrelated component/test suites. The no-argument route remains structurally identical after removing only the new option parser and guarded early exit; no old passed component tests were rerun for this repair. The focused workflow invokes this gate immediately after selecting the installed toolchain, before dependency setup and the original full app build. This is compiler evidence only, never Native acceptance.

Local source/patch reviews do not claim Apple typecheck or Native execution. The new actual Apple compile and six affected cases are pending publication/dispatch. The three unaffected Reader cases from the earlier focused-nine run retain their original historical evidence and are not selected again here. No full Native116/Release114 or physical-device qualification is claimed.
