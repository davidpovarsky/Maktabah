# Native fresh-read continuation — 22 November 2026

The previous run [45014115643](https://github.com/davidpovarsky/Maktabah/actions/runs/45014115643) was cancelled. Its original app/UI-runner build passed, but its collector records one NOT_RUN case and zero completed XCTest cases. No UI pass is inferred.

The retained native log shows the workspace test command resolving and fetching packages again. The builder already used `build/SourcePackages` and `-disableAutomaticPackageResolution`; the default matrix test command did not. This correction supplies those same two options to the existing command. Selection, test assertions, timeouts, simulator setup and the separate transferred Release `-xctestrun` command are unchanged.

The source repair addresses the observed redundant package work. Available GitHub logs and check annotations do not identify who or what caused cancellation. A recorded matrix phase after the cancellation also means this run does not prove owned simulator cleanup. Historical failure evidence remains unchanged.

## Validation and next run

- Python syntax compiled successfully without executing native code.
- All inspected default matrix callers use the same explicit package checkout directory when building.
- Source, Vendor, Xcode project and original UI-test trees are unchanged from a1940076187c0c2e6047115162771f0e48e5cab8.
- Only `HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending` will run. Prior passing cases are excluded.
- No provider key or Send call is used.
- The two original artifacts were downloaded once and verified against GitHub SHA256 and ZIP CRC; details are in CANCELLED_RUN.json.

Windows source-worktree initialization stalled during this continuation. The isolated GitHub commit was prepared from the exact canonical parent through the repository API; no incomplete local worktree was reused, overwritten or claimed clean.
