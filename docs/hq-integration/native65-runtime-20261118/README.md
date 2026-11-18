# Native65 terminal review and execution repair

Actual run44350271039 built the full app and test bundle, but executed zero named UI cases. All65 remain NOT_RUN. The full108527101-byte artifact passed SHA256 and ZIP CRC verification.

Two xcresult runner failures show that Xcode27.1 AppIntentsTesting cannot load against the selected iOS27.2 private AppIntentsServices ABI. The installed27.1 runtime only supports a special phone, so the prior selector fell back to newer27.2 for iPads and conventional phones. The continuation now inspects existing Xcode installations and selects a matching27.x SDK/runtime supporting the whole11/13-inch iPad and conventional-phone matrix. It sets job-scoped DEVELOPER_DIR and a runtime identifier, never installs software or changes global xcode-select. The actual Apple result remains pending.

Search and Sidebar failed before XCTest because their newly declared group labels were absent from the existing fixture and failure-diagnostic allowlists. Both allowlists now accept these exact groups. Native case names, oracles, zero-skip/release checks and source data remain intact. Phone installation/container verification timed out; no unproven product fix is attributed to that timeout.

The retained real runtime inventory verifies that27.1 has no full-matrix pair,27.0 and generic27.2 do, and26.x cannot satisfy selection. All five current groups are accepted by both external helpers. All17 existing release-gate tests pass. These checks do not grant Native acceptance.
