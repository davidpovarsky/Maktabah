# Qualified6935 snapshot preservation and exact retirement

This packet records artifact preservation and capacity work only. It adds no product, signing, SDK, cache, UI, live-service, or physical-device acceptance result. The original failed build attempts and their source, products, package repositories, SDK inputs, and receipts are retained in a fully enumerated off-host recovery set.

## Exact scope

The sole authorized retirement target is:

```
/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/compact-reader-preview-worktree.5hRb5SYt/wave3-qualified-6935f7fd-20261127
```

Root first authorized full preservation without removal, reviewed the completed archive/member and current-source verification, and then explicitly authorized retirement of only that path. The compact parent, its original `Maktabah` checkout, other builds, all off-host archives, and this operation's recovery metadata remain outside the deletion scope.

Retirement **completed successfully at 07:32:09 UTC on 2026-11-27**, `job_bf904cb30c8d`, exit 0. A fresh complete comparison immediately before removal again verified all 65,204 entries and empty open-use checks. The actual [retirement receipt](receipts/mac/RETIREMENT_RESULT.json) is **71,196 bytes**, SHA-256 **`e6695058a14d86a2968a4c0ad059588aae9b34a77d5dd7de4bd20311df2f9a43`**. It records `outside_paths_unchanged`, `parent_identity_retained`, and `original_maktabah_retained` as true. The full [pre-removal source/outside proof](receipts/mac/RETIREMENT_CURRENT_REVERIFICATION.json) is 36,713 bytes, SHA-256 `386ae2dd4b40096958b7e1794c1aae68bafea75201d72730b57d0ee84422ac0e`.

Observed Mac free bytes rose from **2,679,382,016** before the operation to **6,969,020,416** after it: **+4,289,638,400 bytes**. This is a concurrent `df` observation, not an assertion of exclusive APFS allocation reclaimed. It is smaller than the snapshot's 12.95 GB allocated-size inventory, which included shared extents. No other directory was removed and no SDK retry followed.

Mac evidence directory:

```
/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6
```

Windows evidence directory:

```
C:\Users\DAVID\.codex\artifacts\otzaria-wave3-qualified-snapshot-preservation-20261127
```

## Complete preservation

The exact earlier read-only reference plan is SHA-256 `ff591293df6c4c8965f4c085c5f3cd35d5b38751a8dd21a0122ec75cf6644f33`. A new full inventory rehashed all source files and captured Darwin metadata; the earlier coverage plan did not substitute for that inventory.

| Observed inventory | Count or bytes |
| --- | ---: |
| All entries | 65,204 |
| Regular file names | 52,006 |
| Directories | 13,120 |
| Symlinks | 78 |
| Logical file bytes | 12,813,835,966 |
| File names backed by exact previous archive members | 40,984 |
| Their logical bytes | 4,685,067,763 |
| File names backed by the new differential | 11,022 |
| Unique new payloads | 3,973 |
| Unique new payload bytes | 3,222,367,496 |
| Entries with extended attributes | 390 |
| Extended ACL entries / hardlink groups observed | 0 / 0 |

The full `MANIFEST.json` is **49,280,191 bytes**, SHA-256 **`70a15c1afa2456d9dea9f11191df0561f08d766211360c60a5039feca632d660`**. It is retained on both hosts and embedded byte-for-byte in the new archive. It records every path, type, content hash, payload reference, mode, UID/GID, timestamps including exact Darwin birth time, flags, no-follow xattrs/ACLs, and exact symlink target bytes. Historical inode/device/ctime values are recorded evidence; restoring those numbers is not promised.

The new differential is:

```
C:\Users\DAVID\.codex\artifacts\otzaria-wave3-qualified-snapshot-preservation-20261127\qualified-snapshot-differential.tar.gz
```

It is **1,291,853,917 bytes**, SHA-256 **`f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b`**. The Mac streamed it directly to the exclusive Windows output; no large Mac archive was created. Both ends measured the same size and hash. Windows independently verified the embedded manifest, every new payload, gzip CRC/trailer, all original parent-directory relationships, metadata, symlink targets, and each reference to an existing archive member. See [the actual member verification](receipts/windows/VERIFIED_DIFFERENTIAL.json).

## Required existing archives

The new differential is a recovery set with the following retained archives. All three had already passed complete-member verification; their full compressed files were independently rehashed before this backup and again with the new differential immediately before retirement.

| Archive under `C:\Users\DAVID\.codex\artifacts` | Bytes | SHA-256 |
| --- | ---: | --- |
| `otzaria-wave3-app-generated-caches-20261127\inactive-app-generated-caches.tar.gz` | 1,699,905,882 | `36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb` |
| `otzaria-wave3-interrupted-sdk-work-20261127\interrupted-original-sdk-work.tar.gz` | 5,238,640,114 | `2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda` |
| `otzaria-wave3-fresh-producer-preservation-20261127\fresh-producer-differential.tar.gz` | 944,883,233 | `3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee` |

Their member manifests, exact verification receipt hashes, archive identities, and prior verification job IDs are retained in [BASE_ARCHIVES.json](receipts/windows/BASE_ARCHIVES.json), SHA-256 `5b1f9b85fc969594d6925ffb57e11cfec24da950ffee89c2cd458e83ea5d29cb`. Direct physical members of the older fresh-producer differential were eligible references; inherited payloads were resolved to their actual older archive members.

Recovery follows each full-manifest entry's `payload`: either its exact `archive_id`/member or its `objects/sha256/<hash>` member in the new differential. Verify both archive and entry hashes before materializing. Recreate the recorded directory, symlink, file, ownership, and Darwin metadata structure on a compatible filesystem. A 12.8 GB full filesystem materialization was **not run**. This operation establishes complete content/metadata preservation and verified references, not a restored SDK qualification or an admission to reuse interrupted outputs.

## Verification and capacity controls

The actual full-member verification completed at **07:17:26 UTC** in `job_a09e0938024a`, exit 0. Its receipt is **8,013 bytes**, SHA-256 **`1be15f9c4f63809eaedbadfbabfad49ea3283673e71c31906c50d524f7be5fd9`**. The exact same receipt was returned to the Mac.

At **07:22:55 UTC**, `job_0cc90aebd37c` rehashed and compared all 65,204 current source entries, including metadata and the path set. Both before/after open-file and process-reference checks were empty. [CURRENT_REVERIFICATION.json](receipts/mac/CURRENT_REVERIFICATION.json), SHA-256 `dfaca9048386625c234264ba8f71b563fb93a0d5ce5d12d2d113a83c97d015c3`, records that the source still existed at that point.

The live reserve was **2,415,919,104 bytes** on each host. The receiver also reserved space for the separate full manifest and checked available bytes before each archive write. Observed Windows free space after member verification was 2,997,858,304 bytes. At **07:28:12 UTC**, the final full rehash of all four archives passed with unchanged identities; [FINAL_ARCHIVE_BINDINGS.json](receipts/windows/FINAL_ARCHIVE_BINDINGS.json), SHA-256 `f86f3f4784e20b486bf5e578b3b20fa0de0183655e28e0866c09aab3e1e669af`, binds the original member proof, all four archives, and the exact target manifest.

The retirement executor contains one destructive call with a fixed target. It requires the existing preservation helper's exact SHA, all four pinned archives, the fresh Windows readback, a new complete content/metadata comparison, empty before/after use checks, unchanged outside paths, and the exact target directory identity. It records original `Maktabah` HEAD/tracked status, sibling and checkout-root metadata, selected source/lock hashes, and compact-parent identity before and after. The original preservation/verification scripts remain unchanged.

Read-only disk/process/memory attribution is retained separately. At 07:27, no active Xcode/Swift/Clang/gomobile build appeared in the selected process readback, and the original wave1 SDK `source/build` directory occupied only 24,664 KiB. Existing simulator processes and 3,072 MiB allocated swap were observed. These snapshots do not establish the cause of the earlier free-space decline. No foreign process, simulator, file, or cache was stopped or modified.

## Evidence handling

Files under `receipts/` preserve exact host bytes, including the original CRLF in the Windows base-archive receipt. Files under `jobs/` serialize the actual Sentinel job envelopes and their unmodified output strings. `PACKET_FILES.json` indexes the sealed packet. The full manifests and archive payloads remain in the explicit recovery locations; they are not duplicated into Git.

All original failed SDK attempts retain their original status. Native acceptance added: **0**. New SDK qualification: **false**. New SDK retry by this lane: **false**.
