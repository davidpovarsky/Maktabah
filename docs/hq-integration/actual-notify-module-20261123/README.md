# Actual notification module correction

The selected Xcode27.2 / Swift6.4.2 / iPhoneSimulator27.2 SDK declares the C notification API in its real notify.modulemap as module notify. Actual workflow45152574279 compiled all four original declarations into an object with the original Swift6 upcoming-feature flags and arm64 iOS27 Simulator target. Darwin and its Mach submodules failed and those raw diagnostics are retained. No notification was executed.

Exactly two earlier import DarwinNotify declarations are replaced with import notify. The earlier documentation-based import assumption was wrong; both actual combined compiler failures remain part of the record. All test bodies, app logic, assertions, timing and original source outside those import lines are byte-preserved.

The next combined original application build and ten native UI cases remain required. This source correction does not claim those cases passed or transfer historical acceptance.
