# Truthful Sefaria diagnostic stages and original native Reader

This is a source correction and source-bound control packet. It is not new SDK, full-app, native UI, live-network or physical acceptance.

## Corrected behavior

The original stage4 proved only a current-generation echo. It now executes an explicitly stale-generation request and accepts only the original bridge's STALE_GENERATION error. Its detail states exactly that. The separate late **in-flight response** branch has not been exercised by this diagnostic; stale-request rejection must not be reported as evidence for that path.

Stage11 previously converted every live-search error into passed=true and allowed an empty hit. It now preserves the actual failure and stops. A valid hit must belong to the same live Sefaria backend and runtime epoch. Stage12 no longer substitutes Genesis or describes a TextAdapter fetch as native reader navigation.

The stage12 provider uses the exact original manager/window, ReaderDestinationResolver and canonical Core reader.open in an original new tab. It validates the matching request, backend snapshot, scene, native/Core receipts, original loaded Reader and the actual TextKit viewport. The existing validateCompletedJourneySurface performs the final exact tab/surface/witness check. No parallel renderer, replacement reader, fabricated UI acknowledgement, transport bypass, original test weakening or Core contract change was added.

Only three production files change. The original iOSMainView change is a three-line dependency wiring hook. Its other original and prior integration behavior is preserved.

## Actual validation

The complete diagnostic runner, original SefariaRPCModels and original surface contract were compiled and executed on Oracle using explicit synthetic runtime/library/native-provider boundaries. The same22 decision tests ran against both versions:

| Actual source boundary run | Passed | Failed |
| --- | ---: | ---: |
| Exact9c6d baseline | 2 | 20 |
| Corrected runner8d5441cf | 22 | 0 |

The controls cover stale requests, unrelated errors, live-search failures/cancellation/empty or malformed results, backend/epoch changes, provider failure, invalid receipt fields, and exactly one native-provider call for the actual returned hit. These are diagnostic decision tests. The synthetic providers do not establish real RPC/network/native behavior.

Two independently reviewed helper defects were found after those controls: ResolvedReaderDestination must be compared through its original .destination, and equal content in another original tab must not satisfy the returned receipt. Both are corrected. The full first and second helper versions and exact correction receipts remain in the archive. The unchanged runner controls were not rerun or relabelled as coverage of the app Composition helper.

The three initial source files were parsed by the actual Apple Swift6.4 frontend; that result belongs to the initial helper and a macOS target. All three final source files were separately parsed by Linux Swift6.4.3 with an explicit arm64-apple-ios27.0-simulator target, so the iOS conditional source is parsed. These are syntax observations only. Apple SDK typechecking/full original app/native/live acceptance remain NOT_RUN.

Independent final source review is donor19dc53e3412c759cff18f74531e8953085289199 under docs/ui-routing/wave3-sefaria-diagnostic-peer-review-20261127. It retains both initial findings and final source pins.

## Preserved evidence

controls-and-source-evidence.tar.gz retains exact runner inputs, boundary doubles, both compiler and execution logs, compiled control binaries, both raw results, command/source manifests, original and corrected helper versions, syntax results and source diffs. FILES.json binds every member before archive construction; the archive is reopened and every regular member is hash-verified before this packet is committed. Original warnings are retained.

The separate owner-current-9c6d packet preserves the actual failed authentic owner-gate observation on9c6d:56 protected paths,38 valid recorded approvals,17 stale existing signatures and1 uncovered path. No signature or approval record was modified by this work. Final source-bound approval and all original Native116/Release114+2 requirements remain open.
