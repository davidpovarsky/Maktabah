# Existing Scaleway Mac CI routing

Status: routing and current-toolchain verification passed; final CI jobs have not run.

The18 compilation/simulator jobs in the two search gates, iOS build/TestFlight
and final Native/Release workflows now require every label of the existing
repository runner21 (otzaria-native116-20261124):
self-hosted, macOS, ARM64, otzaria-final-20261124, xcode-27.

A normalized YAML comparison verifies that job IDs, dependencies, triggers,
permissions, tests and assertions are unchanged. Only runner selection, the
Xcode helper reference/display name and the Linux-specific Rust version hash
command changed. The legacy adapter-linux job ID is retained for check/summary
continuity; its new execution scope is macOS, with no claim of Linux coverage.
Owner approval and metadata-only summary jobs retain their existing execution.

The Xcode helper now validates the already selected original Apple arm64 toolchain.
It does not run sudo, alter xcode-select globally, choose an alternate installation
or start a build. Actual SSH execution on Scaleway passed in0.4825s under
Xcode27.0 /27A266a; developer selection was unchanged before/after. See
SELECTED_XCODE_ACTUAL.json and MAC_ROUTING_SOURCE_REVIEW.json.

The existing runner was observed offline and idle, with no queued/in-progress
Maktabah workflows. It will be admitted only with the final source bindings,
qualified dependencies and sufficient remaining disk growth. Its previous
ephemeral configuration must be legitimately reconciled before the dependent
final CI jobs can run. No gate is accepted from these configuration checks.
