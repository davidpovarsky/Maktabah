# Approved compressed-part cleanup after sealed recovery

The root reviewed and published the original recovery receipts before separately authorizing this cleanup. Only the two exact seforim-schema7.db.zst.part-000.verified and part-001.verified files were removed at 2026-11-27T04:46:31Z. Their fresh full stat identities matched the original SHA-qualified RESTORE_PART_0/1 receipts byte-for-byte; all current process FD/maps/cwd/command checks and tracked runtime-source exact-path dependencies were clear, without permission gaps. Both sibling owners confirmed no current or planned compressed-part use.

The verified seforim.db was not opened, rehashed, rewritten or removed. Its device2064/inode5946339/full stat identity and0444 mode remained unchanged. Every original receipt is retained unchanged. There was no new public transfer. The original RESTORE_RESULT deliberately continues to describe its completion-time state; this later receipt records the subsequent authorized cleanup.

Logical payload removed:2,129,902,636B. Allocated blocks:2,129,911,808B. Observed free bytes increased834,142,208→2,964,029,440 (delta2,129,887,232); filesystem bookkeeping/concurrent unrelated usage need not equal the exact allocation sum. Source, pre-admission, per-file journal and final receipt are retained adjacent. No native UI or installation acceptance follows from this storage action.
