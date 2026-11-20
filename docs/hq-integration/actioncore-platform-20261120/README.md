# ActionCore iOS deployment metadata repair

## Actual failed device evidence

Normal iOS run [44672943654](https://github.com/davidpovarsky/Maktabah/actions/runs/44672943654), checkout 127ee9eddc2a9aea05c45ccf41420bb0cdd47705, reached device compilation after the original Hanlin preparation and exact Equatable macro authorization both passed. Device job 136087824609 then failed.

Its actual compiler invocation selected OtzariaActionCore for **arm64-apple-ios12.0**. The first compiler error is in ActionSearchSemantics.swift:84: Task.checkCancellation requires iOS 13 or newer. The retained device log contains 95 error lines, principally original concurrency declarations and calls requiring iOS 13. No iOS 27 API failure is inferred from this earlier failure.

The device artifact 14603794186 is exactly 1,379,837 bytes with SHA256 294fd8fa4e22b6b954587d151ed025698d2161d2a1c9895f512950a14930674e. Its original metadata binds run and checkout; the ZIP digest and every member CRC were verified before inspection. The original ZIP contains the complete device compile log, exact macro authorization receipt and Hanlin source receipt. The device failure is not presented as the final outcome of the still-running simulator/overall workflow.

## Narrow change

The repair branch starts at f064b5517f560e2b52838bf321214baa3fb09e2c. Only Source/Otzaria/Actions/Package.swift changes operationally:

    platforms: [.iOS(.v13)],

The old manifest has no platform declaration. Its Git blob db3c297b2f8bf456067f87dad3c895a31b1970c4 is identical in the actual failed checkout and this repair base.

iOS 13 is the concurrency floor demonstrated by the actual compiler diagnostics. The Core source uses Foundation, Dispatch and Swift concurrency; the inspected source has no UIKit/SwiftUI dependency or higher-clock/observation/mutex platform API requiring an app-wide platform change. This change does not claim a new runtime qualification of Core on an iOS 13 device.

The app's existing iOS 27 minimum and the existing iOS 27 declarations in UIRouting and UIRoutingHost are untouched. No macOS declaration or restriction is added. Original product APIs, Core logic, resources, test cases, dependency declarations, Swift language mode and original Hanlin e004 gitlink remain unchanged. No availability suppression, global deployment override or SDK edit is introduced.

## Actual metadata validation

SentinelX job job_1efc4e1e8710 completed on Windows at 2026-11-20T06:24:10Z. The real Swift 6.3.3 package manager evaluated the original and modified manifests using dump-package with --manifest-cache none.

Both evaluations exited 0 with empty stderr: 3.718 seconds before and 1.672 seconds after. The only JSON descriptor difference is platforms: [] becoming one ios 13.0 entry. Removing precisely that entry produces the original descriptor, including all products, targets, resources, dependencies and language settings. All other 50 package files were hashed before and after and remained byte-identical. The scratch directory contains zero bytes, and manifest caching was explicitly disabled. No package build was requested.

These are manifest evaluations, not Swift source compilation, functional test passes or Native results. **Apple device compilation remains pending the coordinated combined correction run. No standalone retry was dispatched.** The actual failed device evidence remains intact.

## Evidence

The raw failed-device ZIP and API metadata, exact before/after dump output, manifest evaluation commands, source hashes, original manifest and unchanged API scan are retained under evidence/. RAW_SHA256SUMS.json distinguishes exact decompressed bytes from gzip bytes. SHA256SUMS.json binds the committed Git blobs, including canonical LF for text; the original Windows evidence bytes remain inside the archives.

The isolated checkout is sparse and contains only the required package, project instructions and this evidence. No corpus, index, upstream SDK checkout or unrelated worktree was copied or changed.
