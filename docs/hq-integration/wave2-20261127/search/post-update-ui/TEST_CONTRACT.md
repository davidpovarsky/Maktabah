# Original Search after Books Updates: R08 cold gate

## Status and scope

This checkpoint adds one registered XCTest case. It changes no application Source file, provider, installation, database, index or trace writer. Native execution remains pending. The complete registered GlobalSearch test file parsed with Apple Swift 6.4; the exact complete production/context/new R08 classes and shared helpers typechecked with the original MaktabahUITestBase against the actual iPhoneSimulator 27.0 XCTest SDK (exit 0, 116 retained base-class warnings). The older FaithfulReaderUIBase-dependent classes are outside this focused typecheck. This is not a linked app build or a UI result.

Product prerequisite: 326806331b0aad54c4ff45806a9a852dde650751. Its source controls separately cover cached reads and same-process invalidation. This XCTest deliberately performs a normal cold launch after Settings has completed the real update; it cannot establish warm same-process invalidation across Settings.

## Selector and placement

`Maktabah-iOSUITests/PublishedProductionSearchAfterBooksUpdateTests/testOriginalBooksUpdateRetainsV40PackagesButRejectsTheirReadinessAndQueries`

Run after the existing ordinary Settings update case, after all v40, full-v32, Groups100 and offline gates. The Settings prerequisite is exactly:

`Maktabah-iOSUITests/ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState`

The existing PublishedProductionSearchDataTests class remains strictly v40. Its admission is not broadened to accept v41. Allow 1,800 seconds for this separate post-update UI case and controller validation; no index is downloaded, repaired, removed or rebuilt by this case.

## Environment

| Variable | Contract |
| --- | --- |
| PRODUCTION_SEARCH_POST_UPDATE_RECEIPT | Absolute path to the shared controller's schemaVersion 1 original Settings success envelope, regular file without symlinks and at most 2,000,000 bytes. |
| PRODUCTION_SEARCH_POST_UPDATE_RECEIPT_SHA256 | SHA-256 of those exact envelope bytes. |
| PRODUCTION_SEARCH_CONTAINER_PARENT | This owned Simulator's exact data/Containers/Data/Application directory. |
| SIMULATOR_UDID | The same UUID as the controller envelope and actual directory ancestry. |

OTZARIA_SHARED_ROOT_OVERRIDE and OTZARIA_PRODUCTION_DB_PATH must be absent. The normal production launch uses the original preferredBackend=otzaria and normal bootstrap. The only trace arguments are `-GlobalSearchNativeTraceEnabled YES -GlobalSearchNativeTraceNamespace <receipt.traceBaseline.namespace>`. The namespace identifies an existing, passed v40 page observation only. It never selects or seeds a workspace, history, result, corpus or provider. No studyWorkspaceTestingNamespace or smokeBypassBootstrap is supplied.

## Shared Settings envelope consumed by this case

The library agent owns the single Python seal_success producer. This test consumes the agreed subset below; controller-only fields such as context relocation/cleanup details remain in that same envelope and are independently validated by the producer/controller.

Top-level fields are schemaVersion=1, status=ORIGINAL_SETTINGS_UPDATE_VERIFIED, simulatorUDID, bundleID=com.davidpovarsky.chavrusatext, checkoutSHA, dataContainerBefore, dataContainerAfter, originalInstallationResult, settingsExecution, before, after, officialTarget and traceBaseline.

FileWitness is `{path, bytes, sha256}`. RawManifest is `{sourcePath, rawBase64, bytes, sha256}`. Its digest is checked against its actual decoded bytes. A parsed object alone is insufficient.

settingsExecution contains caseID (full target/class/method selector), caseStatus="Passed", executedTests=1, skippedTests=0, caseResult:FileWitness, zeroSkipResult:FileWitness, xcresultPath, installedAttachment:FileWitness and officialTargetAttachment:FileWitness. The test reads the exact actual Settings attachments: installed_manifest, old_database_sha256 and new_database_sha256 from settings-update-installed; release_id and tag from settings-update-official-target. Those values must equal the sealed before/after state. Actual case PASS/zero-skip extraction remains a controller gate, with its original evidence bytes retained.

before and after each contain database `{path,bytes,sha256}`, installationManifest:RawManifest and indexes. v40 must be release 455390662 / v40-20261123094345, 4,355,063,808 bytes, SHA-256 8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01. The after manifest must be the actual Settings target from Otzaria/SeforimLibrary, release 459809828 / v41-20261126162443, and a distinct database SHA from the actual Settings hash attachment. The native case does not rehash another 4 GB; the sealed Settings/controller evidence owns that full-file hash. It checks the current managed manifest bytes, path and physical database size again.

Exactly two indexes are required. Each index is `{engine, storageRoot, artifactID, manifest:RawManifest, files:[IndexFile]}`. IndexFile is `{relativePath,bytes,inode,mtimeNs,ctimeNs}` using JSON Int64 integers. The native case uses Darwin.lstat nanoseconds directly, without Date/Double rounding. It enumerates every actual regular file, rejects symlinks/duplicates/unbounded inventories, and compares the entire before/after/current list. These are retained-file identity observations; the multi-gigabyte index payload is not rehashed here.

| Engine | Storage root relative to actual original shared storage | Manifest | Required artifact |
| --- | --- | --- | --- |
| otzaria | Otzaria/TantivySearchIndex/managed-library | otzaria_prebuilt_installation.json | f8fea8efcac5fc06b272a061b44f0e0ee66d16ae12f1e864f9510e437e929139 |
| zayit | Otzaria/Zayit | zayit-installation.json | 17cabb80e86ac8c2d1a3ce16a4e1457d4351709798f2b91a84120d4dd0c6c480 |

Both manifests must remain byte-identical before and after Settings, name the original v40 source, and retain those exact artifact identities. The native inventory also includes Zayit's zayit-search-index directory. A newly compatible v41 package cannot pass this gate as an unchanged v40 package.

Actual MCM metadata must identify the sole original app container and at most one original group.com.davidpovarsky.itorah group in this Simulator. The observed container must equal dataContainerAfter. If XCTest relocates it, the controller must bind the actual relocation and regenerate the envelope from original receipts; silently searching another app/container is forbidden.

## Positive trace prefix and exact source attachment

The original diagnostic writes only successful provider pages and nonempty published results. Therefore a new, absent or empty trace cannot establish a negative result. The controller must first select one of these exact passed v40 cases by its xcresult case and exported attachment mapping:

| Prior full selector suffix after Maktabah-iOSUITests/ | Exact attachment stem |
| --- | --- |
| PublishedProductionSearchDataTests/testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata | published-v40-otzaria-original-pages-and-independent-sql |
| PublishedProductionSearchDataTests/testPublishedV40ZayitPages50_100_150RetainSQLIdentity | published-v40-zayit-original-pages-and-independent-sql |

The attachment is JSON with exactly the relevant `events` array in original order and an `independentSQL` map keyed by stable result identity. Do not choose a file by mtime or a broad filename glob. xcresult export manifests map the actual testIdentifier/testIdentifierURL's attachments through exportedFileName and suggestedHumanReadableName. The exported human filename appends its original ordinal/UUID; the exact case mapping is still required.

Every event has namespace, sessionID, processID, profileID, schemaVersion, engine, event, submissionRevision, searchGeneration and backendGeneration. Derive the sole namespace and PID from those real events. The only admissible app-relative path is `Documents/OtzariaLogs/search-native-<namespace>.jsonl`. Its full parsed event array must equal the actual attachment's events, not merely contain event names. It must have both provider and published events from the exact engine, production profile and original PID. The before-manifest digest binds this to the original admitted v40 case.

traceBaseline contains namespace, relativePath, bytes, sha256, inode, mtimeNs, ctimeNs, processID (prior v40 process), caseID (full selector), caseStatus="Passed", xcresultPath, caseResult:FileWitness, sourceAttachment:FileWitness and sourceDatabaseManifestSHA256. The latter must equal before.installationManifest.sha256. This case never writes or primes that file. It requires the same inode, timestamps, bytes, digest and end offset before and after each post-update query. Any append, truncation, replacement, missing file or changed prefix fails.

## Original UI assertions

After normal cold launch, the case opens the original root Search tab, More and Search Data controls. Books remains ready. Otzaria must disclose the original incompatible-source repair message. Zayit must disclose either the exact original size/release mismatch or the original absence of a compatible package for the current database. Generic discovery/network failure does not satisfy that assertion.

It closes that original sheet, chooses Otzaria exact mode, enters the full original query בראשית, and presses the native Return. Then it chooses original Zayit mode and its existing flexible-five-word option, enters the same query and presses Return. For each engine it requires the original global-search-error container with the source-derived mismatch text, no loading, no result rows/count/paging error, an actionable original Retry, unchanged query and three seconds of stable rejection. All retained manifests/files and the trace prefix are checked again after both attempts. Screenshots and native hierarchies are attached for both rejection states and Search Data.

## Mandatory host process-log gate

Passing XCTest UI alone is not complete negative trace acceptance. The controller must start an owned active simctl log capture on the same UDID before the cold launch, bind the actual fresh app PID/processImagePath/launch arguments, retain continuous capture through both finished intervals, and reject any capture failure/truncation or diagnostic-write error. The prior sourceProcessID in the attachment is never the current process PID.

The exact original NSLog call in UnifiedSearchSessionController.swift is:

`[GlobalSearch] submit revision=%d generation=%d backend=%@ scope=%@`

Arguments are submissionRevision, searchGeneration, BackendCoordinator.shared.activeBackendID.rawValue and scope.rawValue. Current source writes it at line 366 after accepting the original request. Expect revision 1, backend otzaria, scope exact for the first original attempt, then revision 2, backend otzaria, scope zayit for the second. These expectations are not observations until actual logs match. The capture must reject `[GlobalSearchNativeObservation] page observation failed: ...` (source lines 208/223) or `[GlobalSearchNativeObservation] UI observation failed: ...` (line 241). Any additional submit, missing submit, wrong process/scope/backend/revision or positive appended page fails the combined gate.

The exact final native attachment stem is `production-search-after-books-update-original-ui-and-trace-boundary`. Fields include schemaVersion, scope, settingsReceiptSHA256, simulatorUDID, dataContainer, storageRoot, namespace, sourceProcessID, sourceCaseID, sourceXcresult, sourceAttachmentSHA256, tracePath, traceIdentity `{device,inode,bytes,mtimeNs,ctimeNs}`, traceSHA256, beforeManifestSHA256, afterManifestSHA256, launchStartedAtUnix, finishedAtUnix, launchArguments, launchEnvironment, searchDataLabels and attempts.

attempts has exactly two elements in Otzaria/Zayit order, each with engine, querySHA256, expectedLogScope, expectedSubmissionRevision, startedAtUnix (immediately before Return), submittedAtUnix (Return action completed), rejectedAtUnix (actual exact error visible and loading absent), finishedAtUnix (after stable rejection), visibleError, traceOffsetBefore/After and traceSHA256Before/After. All times are Date Unix seconds. The test does not invent a current PID, namespace event or observed revision.

The attachment explicitly states warmSameProcessUpdateVerified=false and hostProcessLogGateRequired=true. Only the controller's actual case/log/file checks may promote this to completed cold post-update UI acceptance. Physical offline, warm cache invalidation and full-package installation remain separate gates.
