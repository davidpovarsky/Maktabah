# Failed local-ad6e SDK Work: preservation and exact retirement

## Outcome

The failed SDK Work was completely preserved, independently verified, and then retired **only after root independently reviewed the complete preservation and fresh-source receipts and authorized that exact path**. The original SDK source, failure evidence, Native ABI outputs, Middleware, Hanlin, ABI donor and every retained archive remain outside the removal scope.

The sole retired root was:

```text
/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterFiveScopes-20261127-Work
```

Its predelete identity was device `16777232`, inode `73167243`, uid `501`, gid `20`, directory mode `16877`. Full absence after removal was verified. The SDK repository remained clean at `1be970356c655bcef3688ddf1d129d5029bbc533` throughout the operation.

This does not change the original compiler outcome. Execution `local-ad6e0a4b-ca9a-4d64-91ea-8d1c1c843ee7` actually ran the framework compiler and failed with exit 65 at `PasteboardHelper.swift:88`, missing the `options` argument. The complete original failure and continuation-policy packet is commit `b16d3c305be3d54706f032b11cac442d6075d7ad`, under `../wave3-sdk-compiler-failure-20261127`. Its statements about the Work being present describe that earlier packet's seal time. This later packet records the separately authorized retirement.

## Complete preserved snapshot

| Item | Actual verified value |
| --- | ---: |
| Original entries | 136,409 |
| Regular files | 117,206 |
| Directories | 18,964 |
| Symlinks | 239 |
| Entries with xattrs | 175 |
| Entries with ACLs / hardlinked regular files | 0 / 0 |
| Original regular-file logical bytes | 11,451,441,643 |
| Files supplied by existing physical members | 84,673 |
| Logical bytes supplied by existing members | 7,518,295,098 |
| Original files supplied by the new differential | 32,533 |
| Distinct new payload objects | 31,355 |
| Raw bytes of distinct new objects | 3,770,386,133 |
| New archive members, including seven metadata files | 31,362 |
| New compressed archive bytes | 1,166,562,940 |

The new archive is `C:\Users\DAVID\.codex\artifacts\otzaria-wave3-ad6-preservation-20261127\failed-ad6-work-differential.tar.gz`, SHA-256 `75c605727c89cb9ec8651fdec35cb852661f6702150af100ef82461e5a2ade15`. It stayed below the authorized 4 GiB output cap. Windows free space remained above its 2.25 GiB reserve.

Every new member was read and hashed. Every original regular file maps to exactly one size-and-SHA-bound physical payload, either in this archive or in a retained archive. The complete original type/path/mode/uid/gid/timestamp/flag, ACL, xattr, symlink and hardlink records are retained in `entries.jsonl.gz` inside the archive and in the preserved metadata directories. Nothing was sampled or inferred from file names.

The exact inventory header is SHA-256 `0eda5768bd4ef592a41b2ad278b3ebd6ffb18b26e7f7c0b38bb63d220d8ec21f`. Its compressed copy is included in this Git packet. The complete metadata file is 11,343,650 compressed bytes, SHA-256 `64dff07c6c074a448facc55080e56c0530e182eafcbebbb1b166d40cef7722ef`; the new-payload manifest is 2,544,264 compressed bytes, SHA-256 `b86e5c6b545253c80a4c69c634bcc3bec2db1df1d036fd87bcc286271214f42f`.

## Exact retained archive dependencies

All six candidate reference archives were freshly hashed and their original complete member-verification receipts validated. The final ledger uses 45,026 distinct physical prior members in only three archives:

| Retained archive | Physical members required by this Work | SHA-256 |
| --- | ---: | --- |
| `inactive-app-generated-caches.tar.gz` | 4,652 | `36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb` |
| `interrupted-original-sdk-work.tar.gz` | 40,366 | `2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda` |
| `fresh-producer-differential.tar.gz` | 8 | `3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee` |
| `qualified-snapshot-differential.tar.gz` | 0 | `f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b` |
| `session-pair-differential.tar.gz` | 0 | `d0743bef81222350ed4cae139504585c81f1592ec084e31884933e79c22a5e8d` |
| `five-scope-differential.tar.gz` | 0 | `39c5145756f859ca62ca215f3ceecd084384f2303a70b7345b3e08a8b2133e49` |

All six remain intact. The first three, their manifests and their original member proofs are actual reconstruction dependencies of this snapshot. The other three were verified candidates but supply no payload to this particular Work. No reference assumes that a nonphysical historical ledger entry contains bytes.

`PRIOR_REFERENCES.jsonl.gz` remains in the Windows preservation root: 2,654,081 bytes, SHA-256 `f9e6bed682686a39431f72525cc3e809c5ac2f4b2ca3a44cf09bbdbbd865d32b`. Exact archive paths, immutable identities and all receipt/member-manifest bindings are in `COMPLETE_PRESERVATION_VERIFIED.json` and `PRIOR_MEMBERS_VERIFIED.json`.

## Fresh source and dependency proof

After archive verification, the still-present source was fully reread and compared with the preserved inventory. All 136,409 entries and 117,206 file hashes matched; every retained metadata field matched. Current read-induced atime is the sole field permitted to differ by the verifier; this actual run observed **zero** atime differences. The original atimes remain recorded regardless.

The path/stat fold is `1a685a6be7cfffd89d98f3c75ceefa901cf812d425c1ab4f268db5fdcd8cd947`; the regular-file content fold is `78ad6fe46073f00da5915861a4a2f8c12c59fe8390c1b680247ed09cd9ebd470`.

All 310 captured link and Git-reference records resolve inside the exact Work: 239 symlinks and 71 Git metadata references. Of these, 309 targets existed. The pre-existing dangling `producer-derived/SourcePackages/checkouts/Highlightr/_Pods.xcodeproj` link retains its original `Example/Pods/Pods.xcodeproj` target. It was preserved as observed and was not repaired or treated as a newly failing build check. The tracked original-controller exact-Work reference probe returned no match, exit 1 with empty stderr. Arbitrary external referrers were not exhaustively excluded.

Reconstruction must materialize the named original bytes and paths, recreate original symlink bytes and any recorded hardlink groups, and restore recorded permissions, ownership, ACLs, xattrs and timestamps in an appropriate order. Original absolute Git alternates and links remain verbatim; restoring the functional original snapshot requires its original absolute root rather than silently rebasing those links. Historical inode/device/ctime values are retained as evidence, not promised numeric values on a newly materialized filesystem. **No full restored filesystem was materialized or claimed.**

## Exact retirement controls and observed capacity

The retirement control first checked current identities of all archives against their actual verified compressed hashes, rehashed manifests/member receipts, rechecked clean SDK source and original execution/Pasteboard bytes, checked all protected outside identities, reread all 136,409 path/stat records, and revalidated the link/Git references. Exact-root `lsof` and process-reference checks found no active use. These checks ran again around the durable off-host acknowledgment.

The exact PREDELETE bytes were fsynced and read back on Windows and Oracle before their SHA acknowledgment was sent. The Mac control pinned the original parent with `O_DIRECTORY | O_NOFOLLOW`, rechecked the exact root inode/owner and used Python's fd-based, symlink-safe removal for only the fixed child name. The original source and all protected siblings were checked again after full absence.

| Receipt or control | Bytes / identity | SHA-256 |
| --- | --- | --- |
| Complete preservation proof | 12,869 bytes | `b93cf1bca06300066702c0d588cd14efe166e753f11f3d4fbca18e79a0d0ac68` |
| Fresh full source proof | 4,535 bytes | `41f3afac682426e9de31cfcb1029672817f1411819d6606d58f2f66af281bdee` |
| Durable PREDELETE receipt | 14,601 bytes | `9ac5aa0191106212f7406546171fb2b54ede51450a1972fb453f98c30f9b0624` |
| Final retirement receipt | 17,244 bytes | `45556d5e873441983cc819beb46f04f5feb300f35363d5f5e1b34d5e79c13d4f` |
| Exact Mac retirement source | 13,314 bytes | `3ddb2ec671175c46226fa09fcfd2dea2808e4b4ef20f43710b4c079779f0b3b4` |
| Exact Windows retirement source | 12,064 bytes | `8aa58490d8def72e450157b175f25fd5729c7d4e4bfa71c1db85d36442f4a7f4` |

Actual verification job `job_5c6ab4b085bd` completed successfully at 11:51:58 UTC. Retirement job `job_acfd70b451d2` completed at 12:01:31 UTC, exit 0. Its owned Mac process was PID/PGID `22731`, parent `22730`, start `Fri Nov 27 13:00:59 2026` in the Mac's reported local clock.

Fresh kernel-private allocation before retirement was 8,257,695,744 bytes. The actual free-space observations were 14,842,732,544 bytes before and 23,253,811,200 afterward, a concurrent delta of 8,411,078,656 bytes. These are shared-filesystem observations, not exclusive attribution to this operation, a promise of private-byte reclaim, or a production-capacity pass.

## Retained locations and limits

- Windows archive, complete metadata and all verification/retirement receipts: `C:\Users\DAVID\.codex\artifacts\otzaria-wave3-ad6-preservation-20261127`.
- Mac preservation metadata and complete/fresh-source proofs: `/Users/m1/builds/otzaria-wave3-ad6-preservation-20261127.n155e60d`.
- Byte-exact off-host PREDELETE and retirement copies: `/mnt/development/projects/diagnostics/otzaria-wave3-ad6-retirement-20261127`.
- Original SDK failure evidence: `/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterFiveScopes-20261127-Evidence`.

This Git packet stores small receipts, exact compressed controller sources, raw control outputs and the compressed header. The large differential, metadata ledgers and original archives stay at the verified paths above. `PACKET_INDEX.json` binds every packet file and, for compressed originals, both the compressed and original byte hashes. No original output was trimmed to satisfy whitespace formatting.

The framework failure remains open. There was no SDK retry, app/native execution, physical QA, cache qualification, ABI relabeling or source/policy change in this preservation operation. The original driver still requires a new genuine execution and fresh work/evidence after an approved source correction, with all original gates. Root retains next-run coordination.

Asana SDK task `1220941959967667` was updated in comment `1220952286626559` with this actual outcome. The existing SDK AGENTS and upstream integrity policy were read; their standing authorization and technical provenance requirements were reported to root without altering either file.
