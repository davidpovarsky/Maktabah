# Optional owned-cloud worker response correction

The existing downstream owned-cloud notification adapter discarded URLResponse and reported success whenever URLSession supplied no error. An HTTP 401, 429 or 500 therefore became worker.completed. The adapter now accepts only an actual HTTP 2xx response, preserves an existing transport/cancellation error unchanged, and reports fixed missing-HTTP/status errors without including a URL, response body, request or account identity.

Only AnnotationLocalEditorCloudKit.swift and AnnotationLocalEditorCloudOwnership.swift changed. These are downstream-owned existing files, absent from observed upstream d46af139. The original Core CloudKit manager, account observations, remote upload, durable pending/ACK, wait, request ownership checks and retry behavior remain unchanged. No schema, queue or product caller was added.

## Verified result

Sentinel job job_8bd1d9275fd1 compiled and executed the exact new classifier with actual FoundationNetworking URLResponse and HTTPURLResponse values on Windows Swift 6.3.3. All16 cases passed: four 2xx responses, seven non-2xx responses, missing and non-HTTP responses, two original transport-error cases and original cancellation. The exact two previous callback statements were also compiled and invoked with HTTP500, reproducing the previous false success. This is a response/classifier test without network requests or CloudKit execution.

The first compile stopped before tests because the standalone Windows wrappers lacked FoundationNetworking. That failed attempt remains under attempt1-foundation-networking/. Adding the actual platform module to the test wrappers left both production files unchanged. Their two successful full-source syntax parses from that attempt were reused by exact SHA256; no repeated parses or old cloud/component suites were executed.

## Actual caller and delivery boundary

The complete Source search in actual-callers.txt finds no application caller of prepareOwnedCloudSave/saveOwnedCloud, only their definitions and the default overload. Existing component acceptance uses explicit transport probes. Stage B itself still calls the normal local save.

AnnotationLocalEditorCloudPublication retains worker.failed in its Task-backed completion. It does not persist a failed worker notification, schedule retry or present status in product UI. A CloudKit upload may already have been acknowledged before the later worker request; notification failure must not rewrite that actual ACK, repeat the upload or invent rollback. The original focused worker-error assertion records that behavior and was not rerun because this change does not alter the publication state machine.

Apple SDK compilation of the adapter, real CloudKit/worker/account behavior, production wiring, rich-envelope transport, cloud import and cross-app acceptance remain open. The correction makes the existing capability report its actual HTTP outcome; it is not a claim of live sync completion.

Raw compiler logs and the exact extracted helper retain their original whitespace. The source-only diff check passes; no evidence bytes were trimmed to hide the retained failed compile.
