# Pinned official v40 corpus recovery and scoped storage cleanup

## Verified result

The single owned recovery completed on **2026-11-27 at 04:23:55 UTC**. It reconstructed the exact official v40 corpus into a new isolated Oracle artifact path:

```
/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127/seforim.db
```

Use its actual read-only immutable URI only after the integration owner releases the resource:

```
file:///mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127/seforim.db?mode=ro&immutable=1
```

| Identity | Verified value |
| --- | --- |
| Official repository/release | `Otzaria/SeforimLibrary`, `455390662`, `v40-20261123094345` |
| Manifest asset | `782942035`, `seforim-schema7.db.zst.manifest.json`, 589 bytes |
| Manifest SHA-256 | `ab51577bad2f457e24ab5f28082ba830597951ab5738a39652dec821e1dff2e3` |
| Ordered compressed bytes | 2,129,902,636 |
| Ordered compressed SHA-256 | `39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587` |
| Actual stored database bytes | 4,355,063,808 |
| Actual stored database SHA-256 | `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01` |
| Read-only SQL counts | `book=8259`, `line=7925185`, `link=7001824` |
| SQLite `quick_check` | `ok` |
| New file identity | device `2064`, inode `5946339`, one link, mode `0444` |
| Final mtime / ctime ns | `1795753058125287433` / `1795753435326503158` |

The final source receipt is `RESTORE_RESULT.json` (SHA-256 `768d333cceb7e9d5e05bcb299f1ee579c8acd5174c5aec54c3afe76e0c074afb`). Its independent full on-disk digest and SQL receipt is `RESTORE_DATABASE_SQL.json` (SHA-256 `369499a583771ee5f5316444b476705f100b56935b2c402146bf58b16b54e28d`). This preserves the previously verified 7,925,185-row source identity with a new, independently verified file. It **does not claim continuity of the earlier deleted inode**, an in-app installation, original native UI acceptance, an offline test, or a rebuild/republication of either search package.

## Why the cleanup was eligible

The earlier v40 database was absent at its historical path. The integration owner assigned one exclusive recovery job and prohibited duplicate downloads. The two inactive Zayit build roots contained 72 binary segment files with **two hardlink names each**:

```
/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/zayit-v40-source/full-index-v40
/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/zayit-v40-source/qualified-index-v40
```

`INVENTORY.json` records every exact path, current-at-audit device/inode/link count, logical/allocated bytes, timestamps, one SHA-256 per unique inode and the corresponding original public package part. The payloads total 4,108,851,123 logical bytes and 4,109,066,240 unique allocated bytes. Removing only the qualified names would have reclaimed zero payload blocks.

The public release is `davidpovarsky/Maktabah` release `458964380`, tag `zayit-search-data-v40-20261123094345-17cabb80e86a`. Its manifest SHA-256 is `577176375f735af240d8a1e84f0a1ad23bf18018ae4c0f716e8acb142d8d8691`, artifact identity `17cabb80e86ac8c2d1a3ce16a4e1457d4351709798f2b91a84120d4dd0c6c480`.

The old 74/74 packaging receipt was retained, but lacked individual uncompressed hashes. It was **not** substituted for a fresh reconstruction proof. From 03:41:19 to 03:51:09 UTC, one sequential public stream downloaded all 74 original parts, checked every compressed size/SHA, decoded with bounded memory, and matched every decoded size/SHA to the exact audited source inode. This verified 3,159,917,458 compressed bytes and 4,108,856,448 decoded bytes, including both public metadata files. No index payload copy was written to disk.

`PUBLIC_STREAM_RESULT.json` has SHA-256 `a4562c412c5fe823a2dcf5becc67d51de2b9652256ad94051d55dddd7afc2efc`; its status records **no cleanup performed by that verifier**. The later cleanup is a separate, explicitly approved operation.

## Exact cleanup boundary

After the integration owner independently reviewed the inventory, public reconstruction and preserved metadata, the cleanup script repeated the exact stat, Git-tracked/runtime-source dependency, `/proc` FD, mapped-inode, command/cwd and permission-gap checks. Both sibling agents had confirmed no current or planned use. The script then removed **only the 144 approved binary pathnames**, checking each original first-link identity and the owned nlink/ctime change before the second unlink. Every pair is retained in `CLEANUP_JOURNAL.jsonl`.

All nine nonpayload metadata/lockfile witnesses were preserved unchanged, including both metadata variants, both `meta.json` names and `.managed.json`. All lexical data, code, scripts, logs, historical receipts and published GitHub assets remain. The inactive build directories retain their metadata; they no longer contain complete local indexes. No active application index was touched.

The cleanup completed at 04:01:03 UTC. `CLEANUP_RESULT.json` has SHA-256 `9bd62627598c13daffd1140d6112c86a92ef23acf2a691daecabbbb662d128e6`. It records actual free space before/after and the allocation-based reclaim expectation separately; concurrent host writes and small evidence writes can affect the observed free-space delta.

`retained-recovery-metadata.tar.gz` preserves bounded original metadata/source files and the public release response; it contains no binary segment payload. Its SHA-256 is `63d739739be68d7baf3878e422e70633d4a04c0c9a3129c237d8ad1377827dc9`.

## Capacity and original recovery pipeline

Before any corpus download, the owner reserved the complete compressed-plus-database peak of **6,484,966,444 bytes** directly in three new isolated files using `posix_fallocate`. The fresh gate also required at least 1 GiB residual free space. `RESERVATION_RESULT.json` binds the three actual inodes and allocated blocks; SHA-256 `8efd950e3b1a792390e754cfdf7f2a7e00ad9c8badfc6b9c1198f3ee8263c48d`. Reserved zero content was explicitly unverified and was never admitted as a database or a completed download.

The recovery wrapper imports the unchanged original `Scripts/resolve-official-library-asset.py`, SHA-256 `7b3f962894f00b31c829e9f607f12127f282878713d2aae2567857a3ce9758e5`. It fetches the exact pinned release and verifies the original multipart manifest and selection policy. The two original assets are:

| Part | Asset ID | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `seforim-schema7.db.zst.part-000` | 782942221 | 1,992,294,400 | `91a9985084e5217b661664c3b53c357aaf354498752bf9f7c55d93581dcc9c33` |
| `seforim-schema7.db.zst.part-001` | 782993890 | 137,608,236 | `a5469c776bae891d49dfcf33986474416b56ee739c4b0fba37ef7eb9ec53af1a` |

The downloads write into the already allocated part files. Actual received bytes determine progress, never the preallocated file length. Verified parts are read back in order, each part and the combined compressed stream are hashed again, and the stream feeds `zstd -d -q -M128MB -c`. Decoded bytes write directly into the preallocated database with a strict output-size bound. No assembled compressed archive or second corpus copy is created. The on-disk database is then hashed independently and opened through SQLite with `mode=ro&immutable=1` and `query_only=ON`; counts, `quick_check`, file identity and absence of SQLite sidecars are verified before final read-only promotion.

The successful owned job was PID `3210857`, started 04:08:22 UTC. The wrapper SHA-256 is `be266232d5faebbd2a02de442943cffd6ba96fcdd16ec345799041d8e41c610e`. It has a 3,600-second deadline, 1 MiB transfer buffers and a 128 MiB decoder limit. Two verified compressed files remain in the owned artifact directory pending the integration owner's separate storage decision. They are not part of this Git commit.

## Retained failed attempts and connection interruption

`public-stream-attempt1/` retains the first streaming verifier's local zstd argument failure (`-M128` was invalid on zstd 1.5.5). A tiny local decoder control established the valid `-M128MB` syntax. That attempt reached HTTP 200 before the local decoder failure; its old receive counter is not used to claim zero network bytes. It wrote no decoded payload cache. The corrected fresh stream completed all 74 parts.

`restore-attempt1/` retains the first corpus wrapper, launch/log and `KeyError('nlink')` admission failure. The reservation writer asserted one link but omitted that key from its saved identity fields. The failed wrapper exited before any metadata or corpus request; all three reserved identities remained unchanged. The correction admits the retained six identity fields plus a fresh mandatory nlink1 check, without rewriting the original reservation receipt.

Oracle's Sentinel connection briefly closed while the detached successful recovery was running. No duplicate job was started. A bounded reconnect and read-only status showed the same PID at the full on-disk hash/SQL stage; the final source receipt and exited PID were then observed. Tool transport failures are not credited as corpus failures or successful UI runs.
