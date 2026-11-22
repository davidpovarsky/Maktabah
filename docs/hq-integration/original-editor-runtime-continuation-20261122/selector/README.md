# Schema 2 toolchain selector integration

The frozen four-file schema 2 proposal at `b09c95f3eee6aa3b8fe363cfac76a89025c15abe` was blocked by the earlier toolchain selector requiring schema 1. This child changes only `Scripts/CI/select-runtime27-toolchain.py`: its new schema 2 branch calls the existing exact dual-provenance validator, then requires the top-level `toolchain` to equal the authenticated original framework producer tuple. The existing common tuple shape validation and framework-role source/run aliases remain intact.

The one-branch inverse exactly reproduces original Git blob `670b5462928640a20e60373d8cbf5bbfca448d9a`. All other selector functions and schema 1/default behavior are unchanged. The prior six selector controls, one version-stream control and twenty schema 2 boundaries remain preserved and were not replayed.

Three new integration boundaries passed exactly once: a committed valid schema 2 fixture now reaches the authentic framework tuple while the preimage rejects it; missing/drifted top-level tuples are rejected; an exact tuple cannot bypass separate runtime identity validation. The runtime IDs in these controls are explicitly synthetic. No artifact, Apple toolchain, framework or native app was executed.

Actual runtime metadata/hashes and StageB source activation remain unfinalized. The separate Clang module-map/header-root consumer integration and genuine SDK runtime qualification are still dependencies.
