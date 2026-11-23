# Original full-v32 Reader assembly candidate

This isolated candidate changes only the downstream reading-unit builder. It reserves the two arrays using the actual fetched row count and reuses one exact UTF16 length for both each line's anchor and the next offset. Full text, row order, newlines, IDs, normalization, SQL, cancellation, cache budgets and original application composition remain unchanged.

Base: `1969b2065469b55e38e42cbb838a469ffa6a80f7`. Original accepted diagnostic-size repair: `7b2b6a1a7067496be2a2e2f232cf91f9cd8e2478`. The canonical service and normalizer still exactly match that repair.

## Evidence boundary

The retained November 19 same-process Windows comparison measured 4.317/4.592 seconds cold and 4.493/4.577 seconds warm for the complete 110,196-row chapter. The initial candidate full-suite regression remains in `../full-v32-reader-20261119/candidate-speed/`; it is not replaced by later favorable samples.

No speedup is claimed for this new candidate until the new paired experiment executes. The approved Apple qualification is one original macOS source-service executable, with baseline/candidate AB then BA and eight complete reads of the same actual full-v32 chapter. Full semantic and exact-byte unit equality, all UTF16 anchors, actual SQLite IDs and navigation descriptors are checked outside the timers. This does not execute the application, UIKit, a UI matrix or a physical iPad, and cannot close first-visible time, p95, frame, CPU or application-RSS acceptance.

The original mounted app path uses the existing detached generic adapter and reading-unit service, then the original render model/ArabicTextRenderer/TextKit2 view. The separate OtzariaReaderView List with 180-row pages is an alternate path and is not modified or credited.

## Source-service execution plan

The owned driver and paired harness will compile the same original production dependency files as `tools/hq-full-source-reader.py`, which is explicitly Windows-only. A namespaced baseline is generated from immutable Git bytes using only its service/error type names and verified by exact reversal. The installed Apple compiler, macOS SDK link input, native ZSTD library, executable and all source bytes are recorded.

Only known original CI fixture paths are checked for read-only reuse. Otherwise, one unique CI-owned fixture is prepared from official release 409213893 / asset 629048655 after authenticating its 1,850,679,582 bytes and SHA256 `6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44`. The full database is exactly 3,821,240,320 bytes, SHA256 `2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765`, 7,876 books and 7,080,797 lines. Original fixed-release downloader/authentication helpers are reused. No corpus is downloaded to Oracle, no index is built, and no existing fixture is modified or deleted.

Status: **SOURCE CANDIDATE PREPARED; APPLE COMPARISON NOT RUN**.
