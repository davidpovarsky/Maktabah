# Native13 cancellation — exact source, no Native execution claim

Run [44692780853](https://github.com/davidpovarsky/Maktabah/actions/runs/44692780853) completed **CANCELLED** on 2026-11-20 at 07:42:06 UTC. Its immutable checkout was d8cc18f80e905c66d73963951efac53b43a12080; app/tests were c61213d9fcc8b80a8606ba00a1562215312ca2ed. The requested diagnostic selected 13 cases (8 iPad and 5 phone). This is **zero verified Native executions**, not 13 passes or 13 failing assertions.

The sole finite observer ended naturally at 07:43:07 UTC with WATCH_COMPLETED and workflow conclusion cancelled. It was not renewed. This collection did not request the cancellation.

## Actual stage reached

The runtime job 136142340398 started at 07:26:47. Its broad execution step ran from 07:27:40 to cancellation at 07:41:58. Original build output ends during React-CoreModules Objective-C++ compilation. It contains no compiler-error or XCTest test-start line. No native-matrix log, test-simulator log, finalized test tree/summary, runtime result or completed build result exists in the uploaded evidence.

The separately confirmed Swift throws-propagation defect in FaithfulReaderUIAcceptanceTests was a source finding. This cancelled run did not produce an Apple diagnostic for it. No Notes, History or other Native oracle was reached/proven by the retained artifact. The declaration list is preserved only as the requested selection.

## Integrity

The only artifact, 14611520762 runtime27-evidence, was downloaded once: 935,941 bytes, SHA-256 3428e073d56ccf2c1be2004c0e9cb0b0181fbf2e0bf7c8f7ff3bbcfb379b18dd. Its checksum matches the GitHub artifact digest. Checkout.txt and the original test-tree hash match the exact frozen Git source.

Raw source inputs, declaration list, toolchain selection and complete partial build/driver logs are retained, with deterministic lossless gzip for logs. ORIGINAL_ENTRY_HASHES.json binds them to the ZIP entries. GitHub final run/jobs/artifact metadata and the prior source-defect observation snapshots are included. Where Windows collector CRLF is normalized for readability, COLLECTION_COPY_RECEIPTS.json points to an exact original gzip.

This documentation commit changes no app, test, workflow, selection, frozen branch or acceptance rule. The cancelled selection requires a separate successful current-source build and actual Native execution.
