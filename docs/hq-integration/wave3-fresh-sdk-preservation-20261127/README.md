# Exact interrupted SDK producer preservation and retirement

## Result and scope

At **2026-11-27 06:43:00 UTC**, the explicitly leased interrupted producer directory was retired after complete off-host preservation and a second complete content/metadata verification. The successful retirement job was `job_ef611f97198a`, exit 0.

The only removed path was:

```text
/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterCapacity-20261127-Work/producer-derived
```

Its work parent remains. The original SDK source remains at `1be970356c655bcef3688ddf1d129d5029bbc533`. Top-level protected source/build identities and recorded regular-file hashes were unchanged before and after the operation. The original and fresh SDK failure receipts, ABI/macro evidence, source, signing materials, other workspaces and all paths outside this exact producer directory were excluded from deletion.

This is **artifact preservation and capacity maintenance**. It supplies no successful SDK/framework/consumer build, qualified cache seed, app typecheck, native test, physical test or release acceptance. No fresh SDK attempt was started by this packet. The producer remains explicitly classified `UNQUALIFIED_INTERRUPTED_PRODUCER_DERIVED_NO_BUILD_ACCEPTANCE`.

## Complete preservation accounting

| Observed item | Count or bytes |
| --- | ---: |
| Total filesystem entries | 121,147 |
| Regular file names | 102,063 |
| Directories | 18,845 |
| Symbolic links | 239 |
| Logical regular-file content | 49,890,963,733 B |
| File names backed by the exact previously verified base archive | 78,509 |
| Distinct referenced base members | 77,878 |
| Logical bytes backed by the base archive | 47,086,345,732 B |
| File names backed by the new differential | 23,554 |
| Unique new payloads after content deduplication | 22,521 |
| Unique new payload bytes before compression | 2,659,619,569 B |
| Entries with extended attributes | 88 |
| Entries with extended ACLs | 0 |
| Observed hardlink groups | 0 |
| New differential archive | 944,883,233 B |
| Complete current manifest | 93,784,007 B |

Every file was hashed. A reused payload was admitted only by exact SHA-256 and size against an exact member of the old manifest. Every remaining unique payload was streamed into the new archive. All original file names have an explicit payload reference; deduplication did not discard their distinct metadata or directory relationships.

The complete manifest retains every path/type, permissions, UID/GID, device/inode/link count, size/allocation observation, nanosecond modification/access/change/birth timestamps, flags, device number, complete no-follow xattrs including compression attributes, and complete no-follow ACL representation. Symbolic links retain the target string and its original bytes. Historical inode/device/ctime values are evidence, not a promise that another filesystem can assign the same values on restoration.

## Durable recovery inputs — keep both archives

The two archives jointly preserve the current tree. The differential alone does not contain the 47.09 GB of content already present in the base archive.

| Input | Exact SHA-256 | Bytes |
| --- | --- | ---: |
| Base archive | `2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda` | 5,238,640,114 |
| Base member manifest | `558af6b185c0accd75906fbfdba747c8511c1448447819a2bc2a43028d766e94` | 53,858,783 |
| New differential | `3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee` | 944,883,233 |
| Current complete manifest | `d47acc0b42ed579d076355901595b66c2b4548a391ae906d27b48a3b210686bb` | 93,784,007 |
| Windows differential verification receipt | `485d1842dd531c9f6211a9498bddaa1139089fac92efee2abb436a716fced53f` | 3,929 |
| Mac second full verification receipt | `fc64009b14ce50d38338605af642ec305f10d55e9887fa08d96bc09a7eaf03ca` | 10,468 |
| Mac retirement receipt | `8074c6a9603132247a61cb4ade2afe8edbd8c12a5f49ce7957042a1a621861c4` | 11,070 |

The base archive and manifest remain in:

```text
C:\Users\DAVID\.codex\artifacts\otzaria-wave3-interrupted-sdk-work-20261127\
  interrupted-original-sdk-work.tar.gz
  MEMBER_MANIFEST.json
  VERIFIED_ARCHIVE.json
```

The new archive, standalone manifest, scripts and Windows receipts remain in:

```text
C:\Users\DAVID\.codex\artifacts\otzaria-wave3-fresh-producer-preservation-20261127\
  fresh-producer-differential.tar.gz
  MANIFEST.json
  VERIFIED_DIFFERENTIAL.json
  RECEIVE_RESULT.json
  BASE_ARCHIVE_READBACK.json
```

The current manifest is also the first member, `MANIFEST.json`, inside the verified differential. Each new content object has the member name `objects/sha256/<actual hash>`. Each `base_archive_member` reference names its exact old member and base archive hash. Recovery uses the manifest's original paths and metadata; the content-addressed tar members' synthetic mode/mtime are container metadata only.

The Mac retains its complete manifest, exact producer script, verification and retirement receipts at:

```text
/Users/m1/builds/otzaria-wave3-fresh-producer-preservation-20261127.hhz749_k
```

No 49.89 GB restored tree was materialized. The performed verification covers all payload bytes, references, metadata encodings, symlink targets, parent-directory relationships, tar membership and gzip integrity. A future restoration must use both pinned archives, preserve symlink boundaries and apply the recorded metadata on a suitable filesystem.

## Verification chain and observed capacity

| Step | Actual job | Observed result |
| --- | --- | --- |
| Prior complete base member verification | `job_6f9fcedf19df` | All 119,155 regular files / 138,339 entries in the old archive verified; its exact result was read back |
| Fresh whole base archive and manifest rehash | `job_5a22802cb180` | Exact original 5.238 GB archive and manifest hashes; size/mtime stable |
| Current complete inventory | `job_dc0058ad5ce4` | Every current entry hashed/stat-checked; full metadata captured; no live use |
| Direct binary Mac→Windows differential stream | `job_048b937ac7b1` | 944,883,233 B, identical sender/receiver SHA; no large archive written on Mac |
| Independent Windows differential verification | `job_fadb10ba7915` | Every new payload, base reference and entry verified; gzip CRC consumed; no missing/duplicate/unexpected member |
| Second current-tree verification and exact retirement | `job_ef611f97198a` | All 121,147 entries revalidated before the sole directory removal |
| Remaining capacity inventory | `job_834b54d01d4f` | Read-only `du`/stat, no further deletion |

The fresh base rehash is bound to the prior complete member verification and the unchanged Windows archive identity. Its prior observed mtime was checked again before streaming and verification. The new archive was independently rehashed on Windows and required to match the Mac's completed stream receipt.

The Mac script refuses retirement without the exact returned Windows receipt hash. It checks its own script hash and the manifest hash; verifies current Git HEAD; rejects open files/process references; rehashes all current content and metadata; checks the entire path set and recorded inode/stat identities; and rechecks external protected snapshots. Only then does fd-based symlink-safe `shutil.rmtree` receive the one fixed root. Access times are retained in the first manifest and excluded from the second equality check because preservation reads can legitimately change them.

Both hosts used a **2,415,919,104 B (2 GiB + 256 MiB)** live free-space reserve. Windows checked the next write before each binary block; Mac checked capacity during inventory and before each payload. The minimum Windows free observation before a stream write was 4,183,609,344 B. Windows free after full differential verification was 4,086,001,664 B.

Mac free immediately before the second verification/removal was 6,497,869,824 B and immediately after removal was 13,814,247,424 B. The observed increase was 7,316,377,600 B. This is a concurrent filesystem observation, not exclusive APFS reclamation accounting: clones, sharing and other activity make summed logical/allocated sizes different from reclaimed capacity. At the later 06:44:30 read-only inventory, free space was 13,694,443,520 B.

## Remaining capacity inventory and limits

The named root acceptance workspace measured 68,834,533,376 B by `du`. Its compact-reader-preview parent measured 33,391,751,168 B, including original Maktabah 13,191,311,360 B and `wave3-qualified-6935f7fd-20261127` 12,947,243,008 B. The paired production Release tree measured 12,468,592,640 B. These containers include protected products, source/package inputs and original test evidence; their sizes do not make them eligible for deletion.

The SDK source/build parent measured only 25,255,936 B after retirement. It still contains the original/fresh failure evidence, ABI and macro records. Both original and fresh work parents are retained and empty. The complete read-only inventory lists 122 acceptance-root children and 12 SDK-build children with stat data. It does not establish each child's current ownership, recovery or inactivity. A further cleanup requires its own exact scope, live-use checks and verified preservation.

## Preserved failures and evidence files

`PREFLIGHT_RECEIPTS.json` preserves the initial Windows inline-Python quoting failure (`NameError`, before hashing/removal) and the first metadata API probe failure. The quoting was corrected with a literal stdin script. Actual Darwin SDK declarations and a corrected no-ACL/birthtime probe were verified before the successful full inventory. These were preparation failures, not hidden SDK or native results.

`EXECUTION_JOBS.json` retains actual completed job records. `validation/mac/` and `validation/windows/` retain receipt bytes exactly as read from the hosts. `producer_preservation.py` and `windows_differential.py` are the executed scripts, bound respectively by SHA-256 `24372da550343461d9526bc327da1dc24d75495b6e78a95557b31d427edc929d` and `61d2ca24578b6335825e1333e65aa5359ed5afc728df8485c41b9ddec3199c5f`. `PACKET_FILES.json` binds the small committed packet. The large recovery archives/manifests remain at the exact host paths above.

This commit changes documentation and preservation evidence only. It does not modify Source, acceptance drivers, source admission, cache qualification, license/owner gates, locks, SDK routes or release policy.

The full whitespace check reports the original Windows PowerShell receipt's CRLF bytes as trailing whitespace. Those bytes are intentionally retained because the receipt hash is part of the preservation chain. The report and executable scripts pass their scoped whitespace check; no raw receipt is normalized.
