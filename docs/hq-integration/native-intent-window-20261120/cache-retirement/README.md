# Retirement of the owned Intent test build cache

This records an authorized disk-capacity cleanup after the source and executed test evidence had already been committed at 55adc3ba381728c33cc6c529211037f6efd90bc1.

At 2026-11-20T05:39:26Z, only the private build/intent-metadata-swift directory in Maktabah-intent-background-20261120 was removed. Its 1,283 regular files totaled 450,340,024 bytes. Before removal, the two tested executables and both original resource directories (20,270,548 bytes total) were copied to build/intent-cache-retirement-20261120/preserved and verified byte-for-byte against the complete SHA256 inventory. The retained programs are IntentMetadataAcceptance.exe and ChavrusaUIRoutingHostPackageTests.xctest.

The Windows process inventory found no process using this exact cache path immediately before deletion. The ordinary SwiftPM debug junction pointed inside the same cache; it was recorded, excluded from traversal, and removed as a link before the owned directory was deleted. The first conservative inventory attempt stopped on that junction without deleting any file.

Original Core/Host source, all raw Intent attempt logs and generated inputs under build/intent-background-20261120, and committed source/test evidence were hashed before and after cleanup and remained identical. Git status and source HEAD also remained unchanged. No SDK, index, database, original source artifact, toolchain or other agent's cache was removed.

Observed filesystem free space immediately before and after removal was 210,518,016 and 663,154,688 bytes. Those are disk observations, not an assertion that every concurrent filesystem change belongs to this cleanup. The exact removed and retained file sizes are separately recorded.

The lossless inventory and transaction records below bind all hashes, the retained executable paths and the unchanged source/evidence boundary manifests. This cleanup ran no test and adds no execution or Native acceptance claim.
