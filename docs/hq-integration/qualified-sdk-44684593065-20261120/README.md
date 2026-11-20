# Qualified source — actual Apple SDK and macOS component result

GitHub run [44684593065](https://github.com/davidpovarsky/Maktabah/actions/runs/44684593065) completed **SUCCESS**, attempt 1, on checkout **b07f229e85fe894722566ad9444de31d0ba4490f** and application/test source **2e6f08659b347a755aef4e4fe6c00d9592ba700d**. The exact Source, Vendor, project and XCTest trees match between those revisions. The read-compatibility registry contains exactly .original265ToExactOccurrencesD5; this SDK job does not itself provide an engine or full-v32 runtime qualification.

The successful job was 136115815349, **Focused SDK and workspace checks (no app/runtime acceptance)**. Four other workflow jobs were skipped. This run is separate from the earlier registry-OFF SDK and full-app runs on f7c110da/app34c7.

## Authenticated artifact and source

The original faithful-ui-sdk-check ZIP, artifact **14605719458**, is retained verbatim at raw/14605719458.zip. Its **216,346 bytes** match GitHub SHA-256 **b6c1e716baf123d9b71fdb30aa484b4a320ebdb5e2ecd2488437c7a3b2d5eb49**. All 46 ZIP members passed CRC verification, and each member has an independent SHA-256 inventory. The artifact metadata binds its ID, digest, run, branch and head.

All **112** source-hash references collected from the actual artifact match immutable Git source bytes at b07f229e. SOURCE_BINDING_REVIEW records every path, SHA-256, Git blob and byte length, plus the app/checkout tree comparison and exact registry declaration. The original Hanlin SDK remains e00498e33f106cc43be0476ffa2e09329c8ca300: all **424** recorded SDK blobs match the independently fetched, untruncated GitHub tree projection for its original three packages. The existing authenticated API projection was reused; the new run's actual SDK input map was compared in full.

## What executed

| Actual result | Passed | Scope |
| --- | ---: | --- |
| Hanlin API 1.2 host adapter | 48/48 | Named macOS XCTest leaves; original SDK contracts/HostDispatcher/Core/adapter, with explicit authority/backend/native-receipt doubles |
| Hanlin scoped conversation store | 11/11 | Named macOS XCTest leaves; actual Foundation filesystem and original SDK DTOs |
| Legacy Hanlin navigation contract | 8/8 | Named macOS XCTest leaves; original strict HostDispatcher contract |
| Annotation exchange component | 28/28 | Actual SQLite component; live capability remains OFF |
| WAL process exit and reopen controls | 2/2 | Before/after-commit process controls, expected process exit 73 then verification exit 0 |
| Book page cache | 26/26 | Source-bound macOS portable cases |
| Inspector owner | 17/17 | Source-bound owner cases with explicit model/backend doubles |
| Hebrew source ranges | 15/15 | Actual Swift/Foundation and independent literal source-span oracles |
| SQLite | 25/25 | Actual SQLite 3.54.0 source cases |
| Workspace persistence/migration | 89 | Portable assertions; this is not an XCTest case count |

All expected Hanlin leaf names were checked against the actual XCTest logs, with unique passed methods and zero failed/skipped leaves. Repeated XCTest suite summaries were not added together. Named component case inventories are retained. The optional full source-database SQLite case was not selected: the result is **25**, not 26, and does not claim full-v32 database counting or zstd decompression.

Annotation source bytes before/after and original CloudKit queue bytes remained identical. Its component acceptance did not execute the original annotation repository runtime, CloudKit transport, Anytype transport or a live annotation capability.

## Actual SDK compilation and boundaries

Xcode **27.2 (27B52)**, Apple Swift **6.4.2**, and **iPhoneSimulator27.2.sdk** compiled/generated code targeting **arm64-apple-ios27.0-simulator**. The original UI acceptance module, native Sidebar search/split adapters, Reader text visibility, toolbar and routing-host package passed their recorded Apple SDK compilation gates. The original app-membership gate passed.

The complete app-composed Sidebar and GlobalSearch representable/coordinator are explicitly marked **REQUIRES_FULL_APP_BUILD** in the evidence. The standalone SDK job does not compile the entire app composition or run its SwiftUI sheet/environment lifecycle. This matters for the unresolved actual Native88 note-draft witness timeout: this SDK success is not a resolution of that failure.

The original **92** Native selections passed declaration checks. **Zero Native UI cases executed.** No simulator app launch, full app build, physical device acceptance, d5 occurrence engine execution or full-v32 native installer/resume/reopen probe occurred in this job. Later commentary setup correction 83c1198b, DEBUG note diagnostics fa32d4d3, and later device package-deployment metadata receive no validation credit from this earlier immutable run.

## Warnings and evidence preservation

The main SDK report records **2,670** warnings, predominantly XCTest actor-isolation diagnostics. Direct inspection of all archived log files finds **2,688 warning-line occurrences** (2,674 in the combined main log, 10 in annotation compilation and 4 in the separate toolbar log) and zero error lines. Logs can repeat diagnostics across stages; these counts must not be added to the report's total as independent warnings. The three Hanlin component reports separately record zero warnings. The original logs and the complete warning inventory are preserved.

RESULT.json combines the authentic artifact review with completed source binding. The intermediate artifact review intentionally preserves its then-pending source-binding field. Raw records are compressed losslessly with both original and stored digests in SHA256SUMS.json; the GitHub ZIP remains unchanged. The previously assigned sole watcher completed with exit 0. Collection created no compiler/cache work, engine execution, new workflow, cancellation or duplicate watcher.
