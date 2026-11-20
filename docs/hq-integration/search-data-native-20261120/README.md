# Original Search Data Native coverage

Status: PREPARED / NOT_RUN. No Apple typecheck or Native success is claimed by this tranche.

Task: https://app.asana.com/0/0/1220539645638524

The existing product already validates index readiness by opening the original engine afresh, checking the canonical identity and compatibility, invalidating the repository cache, and comparing its document count. The missing evidence is the actual Search Data UI across healthy, missing, corrupt and repaired states. This change adds five real UI cases to the existing registered GlobalSearchNativeAcceptanceTests.swift file. Every original byte of that file remains an exact prefix.

## Product change

SearchDataView in Source/ZayitSearch/UnifiedSearchWorkspaceView.swift gains stable accessibility identifiers on its existing status texts, List and original Close, Repair Otzaria and Remove Otzaria buttons. Their labels, actions, ordering, view models, state transitions and engine calls are unchanged. Removing these identifiers and the private statusIdentifier argument reproduces the original file exactly.

No ready/error flag is injected. No engine, corpus, artifact, SDK, package pin, database policy, installer or trust validator is changed.

## New required cases

All methods belong to SearchDataNativeAcceptanceTests and use the original R27NativeUIBase, realUI bootstrap and the original miniature fixture installer.

| Method | Required observed behavior |
| --- | --- |
| testHealthySearchDataAndColdLaunchMatchInstalledDocumentCount | Actual visible ready status with the installed manifest's 18,879 documents, real original search results, and the same state after a cold launch. |
| testMissingSecondaryIdentityRecoversOriginalIndexAndColdLaunch | Only the owned index's secondary identity file is removed while the app is stopped. Original trusted recovery recreates it, payload and books remain unchanged, and its exact recovered bytes survive another cold launch. |
| testCorruptIndexShowsRepairRequiredAndOriginalRepairSurvivesColdLaunch | Deliberately invalid JSON in the backed-up miniature meta.json produces the original repair-required status. The original repair button installs the genuine artifact; real query, original payload and cold status must recover. |
| testMissingIndexUsesOriginalRemoveAndInstallWithoutChangingBooks | The original Remove button deletes the miniature index and visibly reports not-built. The original repair/install button restores the genuine index and cold query readiness without modifying books. |
| testRepairFailureKeepsOriginalIndexAndExposesAWorkingRetry | An actual OS write denial on the exact disposable index parent causes the original installer to fail. Its visible failed status and still-actionable original repair button are required. Restoring the real filesystem permission permits a new original repair; payload, query and cold readiness must then pass. |

These cases are proposed as a separate iPad11 group, 11-index, so their fault fixtures are isolated from the original reader/search groups. The original 92 Native cases and all 96 Release UI cases plus two separate prototype oracles remain required. The independent hundred-group-switch case makes the proposed next complete Native selection 98.

## Ownership and recovery

Before any fault, the test checks the current Simulator UUID, original application/container metadata, its unique UUID sidecar and original App Group owner where present. It follows the product's original App Group or Debug Application Support storage location and rejects shared-root overrides, symbolic links, ambiguous owners and unexpected replacement directories.

The eligible database is only the existing miniTest10 v6 corpus: 15,470,592 bytes and SHA256 d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef. The genuine database and index installation manifests must corroborate the profile and 18,879 documents. Reads and inventories are bounded. No production profile is eligible.

The app stops before on-disk corruption or identity removal. A complete index copy outside the index discovery directory is verified by per-file SHA256 before a fault is introduced. XCTest teardown is registered before the mutation. It stops the app, verifies unchanged storage ownership and canonical paths, restores the exact original parent permissions, verifies the backup, removes only the three exact staging/previous siblings proven absent before the test, and restores the original index bytes. Database and database-manifest checks run after this cleanup, so a book-integrity failure does not itself prevent restoring the index fault. Changed ownership or an unverified backup remains a hard refusal to write.

Empty original Tantivy lock files are excluded explicitly from payload comparison. The secondary identity is excluded only from payload comparison; the backup includes it, and its recovery/cold persistence has a separate exact-byte assertion. The original installed artifact manifest is deterministic and remains part of the payload comparison.

## Executed validation and review

FINAL_VALIDATION.json records the final test source and product source hashes, exact original-prefix/inverse checks, and the actual Windows Swift frontend parse. Both source files parse successfully; the cross-target SDK warnings are retained. This is syntax validation, not Apple framework typechecking.

Independent source review found two cleanup issues in the first five-case draft: database-integrity validation preceded permission restoration, and interrupted installations could leave the exact temporary siblings behind. The final source addresses both. The reviewer re-read the final ownership and restoration functions and found no further concrete blocker. This is source review, not Native execution.

EDIT_RECEIPT.json and VALIDATION.json are historical preparation records. FINAL_VALIDATION.json identifies the final candidate. The original intermediate source, parser output and final diff are retained byte-exact in raw gzip files with hashes in RAW_MANIFEST.json.

## Remaining acceptance

The five cases have not run on Apple or Simulator yet. A successful run will establish only their explicit miniature-fixture UI and recovery scope. Full production-corpus UI, physical devices, real low-disk/OOM behavior and the other original task criteria remain separate. The actual write-denial case exercises a real installer filesystem failure; it is not a claim that low-disk or network failures were exercised.
