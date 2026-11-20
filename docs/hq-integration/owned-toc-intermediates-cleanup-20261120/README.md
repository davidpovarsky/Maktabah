# Completed TOC compiler-intermediate cleanup

At 2026-11-20 08:00:31–08:00:32 UTC, removed exactly 1,032 compiler-intermediate files (189,578,890 logical bytes) from the owned completed fixture scratch directory:

C:/Users/DAVID/Code/Maktabah-toc-visibility-20261120/build/native-surface-polling-swift

The immediately observed C: free space changed from 283,148,288 to 474,488,832 bytes. Capacity measurements are observations in a shared environment; the exact removed logical bytes come from the per-file inventory.

## Safety and preservation evidence

- The original fixture completed at 04:52:10 UTC with 28/28 portable cases, exit 0. This is a historical result, not a new test execution.
- Before cleanup, the process inventory showed zero matching compiler processes and zero process using the owned TOC worktree/fixture.
- PLAN.json names every retained and removed file and records its exact size and SHA256. Every deletion was restricted to the exact scratch root and revalidated immediately before unlink.
- Removed files were derived ModuleCache/WinSDK PCM objects, compiler index records, object files, Swift compiled modules, dependency metadata and incremental state. Source files, headers, module maps, build descriptions, executables and resources were excluded.
- The runtime executable remains 7,954,432 bytes, SHA256 f7637805832ca3f2039f551e5d678cfb525b823e5956393b1325e3d7b63af71a, matching the original completed result. All 7 resource files remain.
- All 33 retained cache files and all 28 fixture source/evidence files were hash-verified unchanged after removal.
- The durable original RAW_EXECUTION_EVIDENCE.zip at commit 46c702b90eef81a27ef4cd5ba80b2b1db320db05 was checked byte-for-byte against its Git blob: 78,538 bytes, SHA256 72c486e8682a215d165ebed481a0f8a1f6fbafa978f4dd4447271c4a3baa91c1.
- The TOC worktree remained Git-clean at the same source commit. No source, corpus, installed SDK, BridgeSwift official dependency or executable, original artifact ZIP, selected capture or heading frame was removed.

Only the explicitly authorized completed TOC intermediates were deleted. The compiler cache can be regenerated from the retained exact source and package inputs; existing executable, resources and evidence remain available.
