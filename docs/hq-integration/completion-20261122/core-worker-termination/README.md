# Original Core worker termination response correction

## Reviewed product source

Application commit: 5f862ea7d785de813fc28680cfe403a3e082ba22; parent 30c5292275845e619dc236863d0053b8d94b097c. Two product files changed. This commit does not enable the original-editor SDK or cross-app transport.

The original termination flush CloudKitCoreManager.syncWorker() treated a URLSession callback without a transport error as successful even when HTTP rejected the request. Its callback now sends the actual response through the already validated pure classifier and stores a typed failure in the original Mutex before the same single semaphore signal. The original three-second wait, pending notification cancellation, configured request, asynchronous debounce, upload ACK, pending queue and retry behavior are unchanged. The method still records failure through its existing diagnostic path; it does not persist a new retry record or display a new UI result.

The exact classifier declaration, including its name, body and comments, moved from AnnotationLocalEditorCloudOwnership.swift to the existing shared CloudKitCoreManager.swift. Both original consumers continue calling the same declaration. No production declaration is copied and no new target registration is required.

## Executed evidence and exact reuse

- validation/RESULT.json: one Swift 6.3.3 Windows execution, four callback wiring controls passed. The exact original closure reproduced HTTP 503 false success. The exact candidate closure correctly routes HTTP rejection, accepted 204, missing response and original transport error identity into the existing Mutex/DispatchSemaphore mechanism. These controls did not send a request or instantiate CloudKit.
- The previous 16 real Foundation response-classifier cases remain in ../local-cloud-worker-response/validation/RESULT.json. That suite was not rerun.
- RELOCATION_SOURCE_MATCH.json verifies that the original three compiled callback-control files, the exact moved classifier, and both callback literals are byte-identical after relocation. This is source matching, not a second test run. The prior whole-file hashes remain historical; the relocation report records current file hashes separately.
- TARGET_MEMBERSHIP_BEFORE.json maps both existing files into Maktabah, Maktabah-Direct and Maktabah-iOS. Tests and widget do not compile either. None of the five standalone Source SwiftPM package scopes owns the Core file. The original cloud driver compiles both complete files in each of its local/cloud executables; disconnect/combined gates inherit this source closure.
- The declaration remains top-level and unconditional, with Foundation already imported; no actor annotation, compiler flag, package setting or target setting changed. The Xcode project has no default actor isolation override.
- All 14 actual Apple import9 dependency inputs still exactly match successful run44977823319. Its nine original Repository assertions and nine distinct-process reopen assertions can be reused for that unchanged closure. Its Cloud48 execution remains evidence for app5d, not an execution of the newly changed Core file.

## Verification boundary

The callback harness uses the exact source closures, real Mutex, DispatchSemaphore and Foundation response/error objects. It replaces only URLSession transport invocation with direct callback invocation. It does not typecheck the entire CoreManager or run a network, live CloudKit, native app or iPad. The integrated final Native build must compile the changed full original app and its affected UI cases.

The callback receipts are preserved at their original pre-relocation checkpoint. run-callback-controls.py deliberately binds that checkpoint and does not silently rewrite receipts or authorize rerunning passed cases.

## Source binding and protected hook

APPLICATION_SOURCE.json binds product source and trees. The ordinary HQ inputs and original-editor source-context pin follow this product commit; the frozen successful Apple import route stays untouched. Optional SDK admission remains disabled until an actually qualified producer artifact exists.

CloudKitCoreManager is a protected original hook. This minimal callback and declaration relocation must be present in the final full-index source package. These engineering records are not an authentic owner trust signature.

No product parent or cross-app acceptance task is completed by these component controls.

## Ordinary source preflight

On frozen checkout484691ec/app5f862ea7, sole SentinelX job_eb436ef8a476 passed ordinary HQ source preflight and the original-editor source_context over 270 exact execution inputs. The evidence is in preflight-484691ec. No runtime, SDK qualification, classifier16, callback4 or Apple suite was rerun. SDK admission remains disabled.
