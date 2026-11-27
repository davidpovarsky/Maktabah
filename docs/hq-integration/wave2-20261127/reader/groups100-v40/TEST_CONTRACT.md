# Separate original full-v40 Groups100 native case

Status at this source checkpoint: **prepared and Apple source-checked; native UI execution pending**. This does not replace or relabel the existing miniTest10 Groups100 evidence.

## Registered selector and retained original behavior

`Maktabah-iOSUITests/StudyGroupStressNativeAcceptanceTests/testOneHundredOriginalFullV40GroupSwitchesPreserveDocumentsAndColdRestore`

The original `testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore`, its complete helper/model/metric-reader code, and the two original full-v32 selectors remain byte-identical. Only imports and a separate production extension are added to the registered Faithful test file. The existing mini fixture helper is never called by the production case.

The production case opens the actual full-v40 Berakhot first chapter through the original Library palette, Reader unit menu and TOC. It checks the canonical title/locator, original TextKit 2 source length and exact bounded UTF16/UTF8 source sample against the independently generated catalog. It creates three original groups with three distinct document UUIDs, each a copy of this real source document. This is three independent document owners, not a claim of three different works.

Original UI actions prepare the fresh namespace and hydrate each document before the measured cohort. Preparation transitions do not count. The same original 100-transition loop then proves at every step that the group/document actually changed, the original enabled selector and selected original card agree with the persisted state, and all profiles/groups/document membership, canonical locators and actual persisted search-state fields equal the retained baseline. It preserves the existing exact native geometry checks and the original metric reader's identity, revision, sequence and process checks.

## Required independently admitted inputs

The integration controller owns the current qualified app/test build, simulator and original v40 installation. It must preserve complete source/SDK/image qualification and independently verify the original installed full database hash, bytes, SQL counts and installation manifest before and after UI execution.

| Environment | Actual input |
| --- | --- |
| `GROUPS100_V40_CATALOG_FILE` / `_SHA256` | Exact actual full-v40 `catalog.json` produced by `FullV40ObservationCatalog.swift`; ten independent targets, target `103-first` and its original source file |
| `GROUPS100_V40_INSTALLATION_FILE` / `_SHA256` | Exact `actual-full-v40-installation.json` from `RetainedV40Installation.admit_current_installation` |
| `FAITHFUL_VIEWPORT_DIRECTORY` | Actual current owned app Documents path; the original namespace resolver locates the unique exact sidecar within that same Application parent |
| `SIMULATOR_UDID` | The retained, explicitly owned simulator UUID |
| `GROUPS100_V40_OBSERVER_TOKEN` | A fresh 32-character lowercase hexadecimal host-observer token |

The Swift case additionally verifies the actual MCM bundle owner, namespace/container/UDID, complete database file size, driver-pinned full database identity/counts, exact current installation manifest hash/bytes and actual release ID/tag. It queries the current database read-only for the actual Berakhot ID/title/2,875 rows, then verifies exact catalog source bytes/hash. The host's independent whole 4,355,063,808-byte database hash is required; the Swift source check does not substitute for it.

The actual launch uses the production profile and ordinary bootstrap with the same fresh workspace UUID. No external database/shared-root override, smoke bypass, smoke scenario, sidecar replacement or fixed launch-only unit-mode preference is permitted. It enables the original Debug observer using both `-StudyGroupPerformanceEnabled YES` and the separately required `-StudyGroupProductionPerformanceEnabled YES` (source prerequisite `afb968badc19d3085bb26760291b431e699ea0a3`). Ordinary production remains unobserved by default.

The host may resolve the original container relocation that occurs when XCTest installs the qualified build, within the same retained simulator and exact original installation. Once this case begins its actual namespace/cohort, it requires the same actual app container and installation through cold restoration. The simulator remains owned and retained.

## Exact host RSS request and ACK contract

The test writes `Documents/groups100-v40-<token>-<nonce>.request.json` and waits for the corresponding `.ack.json`. Every nonce is a fresh UUID. Requests and ACKs remain on disk for archival. They are observational files and never replace application state.

Every begin/end request contains `token`, `nonce`, `operation` (`begin` or `end`), `namespace`, `step` (1–100), `sceneID`, `profileID`, `fromGroupID`, `toGroupID`, `fromDocumentID`, `toDocumentID`, and `beforeRevision`. An end also contains `afterRevision`. Scene ID is the actual original scene string; profile/group/document identifiers are UUIDs. No schema field is required in this IPC request.

The ACK must match `nonce`, `operation` and `step`, carry `status: ORIGINAL_APP_RSS_SAMPLE`, positive actual `processID` and `rssBytes`, and finite actual `hostMonotonic`. An end also carries the unique actual original app `operationID`. It must not echo the token. Both PID values must equal the original app operation's PID. The host must independently bind that PID and executable to the same owned simulator and qualified installed app, then resolve the end ID against the genuine original `[NativeGroupSwitchPerformance]` record and exact revision interval.

`begin` completes before the genuine group UI action. `end` follows the actual original commit and native/persisted observation. Automation duration excludes the begin/end host handshake. Product operation latency remains the original app's measured monotonic interval, which excludes its memory probes and logging and ends after ordinary session persistence. Neither duration is first-pixel latency.

## Required retained attachments

| Attachment name | Content and scope |
| --- | --- |
| `groups100-v40-original-transition-observations` | Original transition evidence structure: exactly 100 completed non-noop transitions plus cold restore verified; XCTest automation timing is explicitly separate |
| `groups100-v40-application-matched-operation-samples` | JSON array of the exact 100 original `GroupStressApplicationMetric` values, including UUIDs/revisions/process/launch/sequence, actual operation elapsed seconds and `phys_footprint_bytes` boundaries |
| `groups100-v40-host-rss-boundary-samples` | `{schema:1, namespace, catalogSHA256, metric, scope, transitions:[{step,begin:ACK,end:ACK}]}` with all 100 pairs; Darwin process RSS snapshots, not continuous peak RSS |
| `groups100-v40-application-operation-memory-summary` | Count 100, full-v40, original timing scope, nearest-rank p50/p95/max for all original operation durations, separate 200 app physical-footprint and 200 host RSS boundary counts; no invented SLA |
| `groups100-v40-cold-process-and-installation-proof` | Exact cold contract below |
| `groups100-v40-original-source-<requestUUID>` | Fresh original native source report, bound target/source/catalog hashes and unchanged TextKit 2 observation |

The original geometry and owned workspace attachments are also retained, before the cohort, after 100 commits and after cold restoration. Actual attachment export names must be read from the genuine XCTest export manifest; do not invent file names from attachment labels.

## Cold process/installation proof

The original source observer supplies a real app process ID and observed system uptime. It has no render-generation or persisted-document identity field; the test independently binds its exact source, current native title/locator, actual visible Reader and read-only workspace owner. Its scope remains a bounded original source sample, not complete rendered-body or first-pixel proof.

The cold attachment is:

```text
{
  schema: 1, namespace, catalogSHA256, databaseSHA256,
  installationManifestSHA256, containerPath, databasePath,
  preCold:  {processID, requestID, observedUptime, sceneID, profileID,
             groupID, documentID, canonicalLocator, workspaceRevision},
  postCold: {processID, requestID, observedUptime, sceneID, profileID,
             groupID, documentID, canonicalLocator, workspaceRevision}
}
```

The test terminates and ordinarily relaunches the actual app with the same namespace and installation. It requires preCold PID to equal the exact 100-operation cohort PID, positive different postCold PID, different valid fresh request UUIDs, and the exact same profile/group/document/canonical unit. Actual system scene IDs may legitimately differ across a cold launch. The same full catalog, installation manifest bytes, MCM owner bytes and absolute installed database/container paths must remain unchanged. Source observation is fresh in both phases.

## Verification boundary

`apple-source-controls/RESULT.json` retains actual whole-file syntax parse and the exact complete original Groups helpers plus new production extension typecheck against the installed Xcode 27 / iPhoneSimulator 27 XCTest/UIKit SDK, with Swift 6 strict concurrency. The complete original `MaktabahUITestBase.swift` is included. Unrelated Faithful/R27 base methods have clearly named compile-only declarations and are never executed. Existing warnings belong only to the unchanged base file. An initial invocation omitted the SDK's Swift XCTest overlay include path; that invocation and its logs are retained and identified as an invocation error, followed by the corrected typecheck exit 0.

Source preservation is checked by reversing only the new imports and uniquely delimited extension and comparing the entire resulting file byte-for-byte to the original source. The original mini driver and its input file are untouched. This source checkpoint executes zero UI cases and opens no full database. The dedicated controller's allowance for this new test is not a performance SLA and does not change Native116's existing timing allowance.
