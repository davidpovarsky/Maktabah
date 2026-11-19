# Actual Apple SDK evidence — run 44633742619

The focused SDK/workspace job **135946880280 completed SUCCESS**. The original
artifact was downloaded and its bytes and SHA-256 matched GitHub metadata.
This evidence applies only to checkout `7d05dd0bb25a7df307b35174e49e18d0f22eecee`,
application source pin `5d8ef991554b01ba6bf3d39222c5ef6cc00a264b`, and Hanlin SDK
`e00498e33f106cc43be0476ffa2e09329c8ca300`. It does not validate later Phase 2
notes/search source or the later SQLite cancellation repair.

## Original evidence and exact scope

- [Run](https://github.com/davidpovarsky/Maktabah/actions/runs/44633742619)
- [Artifact](https://github.com/davidpovarsky/Maktabah/actions/runs/44633742619/artifacts/14586095947):
  `faithful-ui-sdk-check`, 176,854 bytes, SHA-256
  `9907b4230304cef5655111e8e506282f4b492c22d724292efdb40a87f1e416e1`.
- Xcode 27.2 (27B52), Apple Swift 6.4.2, iPhoneSimulator 27.2 SDK;
  compiler target `arm64-apple-ios27.0-simulator`.
- The unmodified aggregate result, toolbar result, three original XCTest logs,
  workspace log, source pins, and GitHub metadata are retained here.
  `verified-compact.json` includes hashes of **every** original artifact entry.

| Executed suite/check | Actual result | Boundary |
| --- | --- | --- |
| Hanlin API 1.2 host | 28 XCTest passed, 0 failed, 0 skipped | Actual frozen SDK contracts/HostDispatcher, ActionCore and adapter; explicit authority/backend/native-receipt doubles |
| Legacy strict-open contract | 8 XCTest passed, 0 failed, 0 skipped | Original SDK HostDispatcher and contract modules; explicit navigation-effect double |
| Hanlin consumer filesystem store | 11 XCTest passed, 0 failed, 0 skipped | Actual Foundation files and original store; no engine/provider/native navigation/device-protection proof |
| SQLite database wrapper | 20 standalone cases passed | Actual SQLite 3.54.0 and original wrapper, owned temporary database; source dataset reads 0; zstd unexecuted |
| Hebrew source ranges | 15 standalone cases passed | Original Swift/Foundation extension with literal independent UTF16 oracles; no UIKit/TextKit runtime |
| Inspector owner binding | 17 standalone cases passed | Exact app binding, real Swift 6/MainActor, explicit model/backend doubles |
| Workspace | 61 checks passed | Actual portable persistence/migration/rollback/scene/semantic-location checks |

The three XCTest test-name sets match the expected sets exactly in both JSON
and raw logs. These are different suites/check types; no synthetic aggregate
test total is claimed.

## Compilation and remaining runtime work

The actual Apple SDK compiled the NativeRoutingHost package, toolbar code,
sidebar adapter and original TextKit visibility component. All **78 selected
Native test declarations** passed preflight/typecheck. **Native UI tests
executed: 0. Physical-device tests executed: 0.** The full app and Native jobs
were skipped in this SDK-only run. Full composed sidebar and search-field
checks explicitly report `REQUIRES_FULL_APP_BUILD`.

The aggregate SDK report records **2,306 compiler warnings**, chiefly repeated
XCTest/MainActor isolation diagnostics. The three Hanlin fixtures separately
record zero warnings. This is not a warning-free aggregate build.

No complete standalone Core or UIRouting XCTest suite was executed by this job;
the NativeRoutingHost package result is SDK compilation. Later package-run
counts, Native78 results, and Phase 2 results must remain separate evidence.
