# Owned Mac capacity: exact preservation and two-scope retirement

## Observed result

At **2026-11-27 08:33:51 UTC**, job `job_56bcec951e09` completed with exit 0 and removed only these two explicitly authorized roots:

```text
/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/actual-paired-production-release.Hguhbz1S/Maktabah/build/hq-stage2/inputs
/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/compact-reader-preview-worktree.5hRb5SYt/Maktabah/build/DerivedData/Build/Products
```

All recorded protected paths outside those roots, both original workspaces' Git HEAD/tracked state, and both parent identities were unchanged. No process was stopped. No SDK retry, build, native test, release qualification or physical test was performed.

Mac free space immediately before and after removal was **3,783,106,560 → 5,791,612,928 bytes**, an observed increase of 2,008,506,368 bytes. These are concurrent filesystem observations. The earlier APFS kernel observations reported 2,004,697,088 private bytes in the two scopes; neither figure is a promise about a future concurrent filesystem.

## Complete preservation

| Scope | Entries | Regular files | Directories | Logical file bytes |
| --- | ---: | ---: | ---: | ---: |
| Paired Release staged inputs | 13 | 12 | 1 | 1,110,270,440 |
| Compact Debug products | 2,704 | 1,864 | 840 | 1,650,035,396 |
| Total | 2,717 | 1,876 | 841 | 2,760,305,836 |

The complete manifest preserves POSIX identity, permissions and timestamps, exact Darwin birth time and flags, no-follow ACL/xattrs including compression attributes, directory relationships, symlink target bytes and hardlink groups. There were 390 entries with xattrs, no extended ACLs, no symlinks and no hardlinked regular files in these exact scopes. Historic inode/device/ctime values are retained evidence, not numeric values a different filesystem is guaranteed to restore.

Every regular file was freshly hashed. All file bytes were already present in **1,339 distinct exact members** of the four previously verified archives. The new payload requirement was zero. An independent Windows verifier matched the member names, sizes and SHA-256 values against the exact prior manifests, rehashed all four complete archive files and the pinned complete member-verification receipts, and verified the new metadata-only archive including its gzip integrity and exact manifest bytes. It did not materialize a 2.76 GB restored tree.

| New artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Complete manifest | 1,888,113 | `465e33564a80f23c60bb4bf8f54d64a05f605228353164d85e657f3dbcb7a5f5` |
| Metadata-only archive | 224,999 | `7250221a87d34a6f4e335ce81f310f630b5635649a7423defa14ccc04b4eba87` |
| Independent preservation receipt | 5,980 | `179860b3b16bf672d0e56d5b9e774c2201537a513597eba19e123f48911f009c` |
| Durable pre-delete receipt | See packet index | `0f7ea39af14c2c77c515641748381d91f8b0c00ca424affecaa54edb1ff9115a` |
| Final retirement receipt | 122,220 | `ee98ccee1c7c8d4a2458136405cf9a44ce2dee2750994b7ff02677c736eb72af` |

All new artifacts remain in `C:\Users\DAVID\.codex\artifacts\otzaria-wave3-covered-scopes-preservation-20261127`. The metadata archive is also included in this Git packet. It contains `MANIFEST.json`; it does **not** contain the referenced file payloads. Recovery must retain and use the four archives listed, with their exact paths and hashes, in `VERIFIED_PRESERVATION.json`. Their complete previous recovery chain is documented in the adjacent qualified-snapshot and fresh-producer preservation packets. No archive was removed or replaced.

## Retirement boundary and actual checks

The Mac inventory and retirement program wrote no files to the Mac. It reused the exact previously reviewed Darwin metadata helper, SHA `f07264ccf70a75f9b74566d24f65cfdcd6e832e5f3b09231cb6311afae06749e`, and streamed receipts through the existing pinned SSH bridge. The inventory program's body SHA is `315c28c4195c06e9df99d2e784167542207efeab7192ac7fb93e483c19018164`.

Before removal it revalidated every one of the 2,717 entries, all content hashes, the full path set, all retained metadata except access time, root identities, current protected outside state and empty open-file/process-reference results. Access time is retained in the first manifest and excluded from the second equality comparison because reads may legitimately update it. The Windows archive verification was required to be less than ten minutes old.

The complete pre-delete record was sent to Windows, exclusively created, flushed and `fsync`ed. Only an ACK containing that exact record's SHA and the exact manifest/proof hashes allowed the Mac to continue. The Mac repeated no-use and identity checks and passed only the two fixed constant roots to fd-based symlink-safe `shutil.rmtree`. The result includes both the before and after protected snapshots. This handshake kept the preservation record durable before the removal even when Mac free space was unstable.

| Step | Actual job | Result |
| --- | --- | --- |
| Full content/private-allocation plan | `job_bdb6395c4ade` | 575,765 files; no changed source or scan errors |
| Complete two-scope inventory | `job_5db115002aaa` | All current bytes/metadata captured; no live use |
| Independent archive/member/reference verification | `job_b8e25350e8e4` | All four archives unchanged; all references verified |
| Full revalidation and exact retirement | `job_56bcec951e09` | Exit 0; outside paths unchanged |

The Windows receiver preserved its 2,415,919,104-byte reserve. Free space after verification was 2,584,801,280 bytes. No large archive or staging copy was written on the Mac.

## Capacity investigation and limits

The bounded read-only plan covered the original compact Maktabah tree, paired Release tree and existing root-owned `session.*` trees. It observed 38,233,416,446 logical bytes and 17,319,718,912 kernel-private bytes. Of these, 12,485,806,877 logical bytes and 4,552,593,408 private bytes were already covered by the four archives. Across all scopes, 72,608 distinct uncovered payloads totalled 9,612,440,408 raw bytes. The plan is not a complete preservation manifest or a deletion lease.

The implementation used the installed Darwin SDK's extended `getattrlist` private-size/clone fields. It distinguished allocated bytes including shared APFS extents from bytes reported private by the kernel, excluded multiply-linked files from the conservative private total and retained the actual source pin. It streamed the large prior manifests instead of loading them as large JSON objects. The completed plan used 161,808,384 bytes peak RSS and took 181.47 seconds. The full raw result is retained as compressed JSON in this packet; its uncompressed SHA is `597f831d8cc62764c290f0e55eae50007945d1c2a760cb6c91b147ab7ee79a20`.

The first direct Sentinel launch of this plan, `job_022bb4d6eaaf`, failed before execution because its staging filesystem was full. The successful attempt used SSH stdin and wrote its result only to Windows. A broad `/Users/m1/builds` depth-one `du` hit its 70-second bound and was recorded as a timeout; it was not repeated. Protected system-directory `du` permission errors remain in the raw bounded attribution receipt.

Disk attribution does not explain the whole earlier multi-GB decline. The first interval measured approximately 161 MB growth in the foreign Lorvex iPhone simulator, not the entire decline. Later observations found a different booted Lorvex iPad on iOS 27.2 and a recovery in APFS Data allocation while the 3.22 GB VM allocation remained unchanged. These are observations, not an exclusive attribution to another project. No foreign device, global simulator service, Hanlin/SQLite backfill process or other project was stopped or erased.

Three old root-owned `upload-symbols` processes, PIDs 18665, 35620 and 41372, held deleted original app binaries. Their parent/start/inactivity evidence was read, but the deleted inodes and even their exact sizes had no match in the four complete manifests. They were therefore **not terminated**. Their deleted product bytes must not be conflated with a newer file now occupying the same path.

Windows G: was verified as the Google Drive virtual filesystem, not additional local physical storage. It reported only approximately 2.84 GB free. No new storage service, volume, public endpoint or paid resource was created.

## Next incremental preservation and build deficit

Parsing the existing plan, without rescanning the Mac, produced this next pair:

| Exact owned scope suffix | Kernel-private bytes | Uncovered logical bytes before deduplication |
| --- | ---: | ---: |
| `session.ftqrs4Ju` | 2,143,703,040 | 1,660,000,812 |
| `session.e9xp5UCf` | 2,143,113,216 | 1,659,364,793 |
| Total | 4,286,816,256 | 3,319,365,605 |

The latter is a conservative raw-payload upper bound, not a final archive size. Oracle `/mnt/development` had 4,694,814,720 bytes free at 08:20 UTC; its separately specified 256 MiB floor left 4,426,379,264 bytes for preservation, subject to live checks and metadata/tar overhead. Root approved preservation of this exact pair, **not deletion**, after this milestone. Any later retirement needs complete verified recovery evidence, fresh no-use/source/private-allocation observations and the separate root decision.

Even the measured 5.79 GB free after this retirement is insufficient evidence of headroom for a fresh full SDK, two app builds and production acceptance. The interrupted producer had nearly 49.9 GB of logical content; shared allocation makes that unsuitable as a standalone free-space requirement. This packet does not assert a completed build-capacity budget or authorize a heavy retry. The remaining deficit must be resolved from actual staged outputs and live capacity before the original driver resumes.

Asana milestone: `1220947415285737`. A truthful Development Heartbeat was published at 08:34 UTC. Source, tests, source admission, cache qualification, signing/owner gates, dependency locks and release policy are unchanged by this documentation packet.
