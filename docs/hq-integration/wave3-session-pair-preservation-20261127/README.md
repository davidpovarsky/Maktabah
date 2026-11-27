# Exact inactive session pair preservation and authorized retirement

This packet records the complete off-host preservation and subsequent explicitly authorized retirement of two historical root-owned sessions. It does not qualify an SDK cache, a current application build, or native acceptance. The original source histories, tracked generated changes, hooks, dependencies, evidence, symlinks, and filesystem metadata are included in the recovery set.

## Exact source scope

| Original directory under `/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl` | Original Git HEAD | Entries | Regular files | Logical file bytes | Observed private bytes at inventory |
|---|---|---:|---:|---:|---:|
| `session.ftqrs4Ju` | `0d6bb8a9b594bf1efd48d7f23577f8d714c41e5a` | 94,669 | 79,860 | 1,917,676,802 | 2,143,703,040 |
| `session.e9xp5UCf` | `d7eb402a6558040d47edabe6ed2b5da0b5d04f27` | 94,669 | 79,860 | 1,917,040,783 | 2,143,113,216 |

Each preserved source repository includes its pre-existing modified `Maktabah.xcodeproj/project.pbxproj` and `Source/PrivacyInfo.xcprivacy`. Those exact changes and original Git heads were checked again immediately before retirement. No source clean-up, checkout reset, build, or process termination was performed. The later separately authorized retirement removed only the two complete source roots in the table, after all restoration coverage and current-source checks passed.

The inventory covers 189,338 entries, including 29,374 directories and 244 symlinks. Each entry records complete no-follow POSIX/Darwin metadata, ACL and extended-attribute bytes if present, symlink target bytes, and hard-link identity if present. This pair has no observed ACL-bearing, extended-attribute-bearing, or hard-linked regular files. Historic device/inode/ctime values remain evidence; a future restoration cannot promise the same newly allocated inode numbers.

## Content and location

The exact inventory header is `ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b`.

Mac metadata and producer receipts remain under:

```
/Users/m1/builds/otzaria-wave3-session-pair-preservation-20261127.dnwtgpgc
```

The new archive is stored at:

```
/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127/session-pair-differential.tar.gz
```

Its actual compressed size is **1,342,747,334 bytes**, SHA-256 **`d0743bef81222350ed4cae139504585c81f1592ec084e31884933e79c22a5e8d`**. The producer, binary bridge, and receiver independently calculated the same length and hash. The transfer completed at 09:00 UTC on 2026-11-27; both transfer processes exited zero. The Windows bridge staged no large archive.

The differential contains complete metadata plus 58,121 unique new payloads totaling 1,936,002,352 uncompressed bytes. Existing physical archive members cover 2,802 original file occurrences, totaling 515,351,980 logical bytes. Cross-session/content deduplication further reduces the new stored payload; it does not omit either original file path or original metadata record.

Metadata is streamed as gzip JSON Lines to keep memory bounded:

| Metadata | Compressed bytes | Compressed SHA-256 | Uncompressed SHA-256 |
|---|---:|---|---|
| `entries.jsonl.gz` | 15,884,473 | `84eb7dc3280106120c54fe731a23b196b583bff45d85a8db0d79ab861f298bfe` | `56c3080a562870fffcd6e828dc1b45594ff1c1f64da96d2a6de26433caaabc30` |
| `new-payloads.jsonl.gz` | 4,419,157 | `8c57a12eb797bcb6116e71a417dbe2788f774632fba91d6ef90cd0cdd252136a` | `4a6c0687b13459c903fd5109d1ea2088dc703019dd4e3ebb531a8edc37147d16` |

## Verification chain

The actual receipts are authoritative for the completed stages and timings. The scripts provide these distinct checks:

1. `session_pair.py` hashes every current regular file, preserves every metadata record, and records unchanged complete path/stat inventories, original Git heads/status, and process/open-file checks. Its stream mode hashes every new payload again while writing the differential directly to stdout.
2. `bridge_windows.py` pipes binary bytes from the pinned Mac SSH connection directly to the pinned Oracle SSH connection. The receiver checks free space before every 1 MiB write. Windows stores only small scripts and receipts.
3. `oracle_receiver_verify.py` independently hashes the complete received archive, each actual new payload member, and the compressed and uncompressed metadata. It checks the complete path hierarchy, distinct member set, all file-to-payload bindings, symlink bytes, metadata fields, and hard-link consistency. It produces the exact ledger of required physical members from earlier archives.
4. `verify_prior_windows_v2.py` matches every ledger entry against exact pinned prior physical-member manifests, rehashes all four existing archives and their immutable full-member verification receipts, and binds the new archive's independent verification receipt. All 426 distinct prior members matched; they cover 2,802 original file occurrences. The complete preservation receipt is SHA-256 `313e1e60aa516ae218bf709e8d106e7c5b8c64b8a72a61136a78394913e5909d`.
5. `reverify_pair.py` compares every source path, byte hash, and immutable metadata field against the sealed inventory after off-host preservation. It verifies unchanged original heads/status, no active use, outside directory identities, and fresh kernel private allocation. Only read-induced current access times are excluded from the equality check; their original values remain preserved.

The five preservation stages do not delete source. The separate `retire_pair.py` / `retire_pair_windows.py` scripts implement only the later explicitly authorized two-root retirement described below. Full restored-tree materialization is not claimed. The preservation proof resolves every original file to a byte-verified new member or an exact, currently hashed prior archive member and retains the complete metadata needed for restoration.

The first Windows verification attempt, `job_fef5edc6e409`, stopped before archive/member checks because importing the entire Darwin inventory script attempted to import the Unix-only Python `resource` module. Its source and exact failure remain preserved. Version 2 extracts and executes only the verbatim original `Stream` class from the pinned inventory source, using the real standard-library JSON parser; no platform stub or verification relaxation was introduced. Existing first-attempt inputs are reused only after exact byte equality against the pinned Oracle originals. The corrected actual verification, `job_d9d78d212c1a`, passed in 51.5 seconds.

## Actual authorized retirement

Root independently read and hash-checked the complete preservation receipt `313e1e60aa516ae218bf709e8d106e7c5b8c64b8a72a61136a78394913e5909d` and full source re-verification receipt `5834032a8d367869ccb57a251ce89c8da1daf3c8a32fae944063621b3263c2ae`, then authorized only these two exact absolute paths:

```
/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.ftqrs4Ju
/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.e9xp5UCf
```

The actual retirement job `job_35dd48eae4c9` exited zero at **2026-11-27 09:25:29 UTC**. Current archive and receipt identities matched their independent verification records. Fresh complete source stat/path sets, original Git heads/status, four PBX/privacy byte hashes, exact root/parent identities, and full process/open-file checks passed. A canonical predelete receipt was exclusively written, flushed, re-read and hash-checked on both Windows and Oracle before the Mac received its exact SHA acknowledgement. The Mac then repeated its immediate no-use and identity checks and used symlink-safe fd-based removal of the two fixed child names under the pinned original parent. Both exact roots were absent afterward, and all protected outside identities were unchanged.

| Actual raw receipt | Bytes | SHA-256 |
|---|---:|---|
| `RETIREMENT_PREDELETE.json` | 10,864 | `4990f5818663f85f12e4efc71db26e635f5c2bb93278199a8a1dfb442ce027b0` |
| `RETIREMENT_RESULT.json` | 12,564 | `d9e57b059eddb12238581f007591f44b8054d594d9ef870f56b665c9dba22701` |

Mac free space was **14,197,137,408 → 18,571,935,744 bytes**, an observed concurrent increase of **4,374,798,336 bytes**. The independently observed pair private allocation was 4,286,816,256 bytes. These different quantities are retained as measured; shared-host changes are not attributed exclusively to this retirement. All reference archives and recovery metadata remain intact. The compact and paired release parents, original Maktabah source, current SDK source, held executable processes, all other session roots, and foreign work were outside the removal scope.

Historical receipts that state source was still present describe their actual earlier stage. Their raw bytes are preserved without retrospective edits. The raw Windows receipt integers and original line endings are copied directly, not reconstructed from a JavaScript numeric representation.

## Recovery inputs and procedure

Keep the new Oracle archive, the four Windows reference archives, their original manifests/full-member receipts, the header, and the final pair receipts together as one recovery set. The four reference archive hashes are:

| Archive | SHA-256 |
|---|---|
| `inactive-app-generated-caches.tar.gz` | `36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb` |
| `interrupted-original-sdk-work.tar.gz` | `2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda` |
| `fresh-producer-differential.tar.gz` | `3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee` |
| `qualified-snapshot-differential.tar.gz` | `f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b` |

For a future authorized restoration, first verify all receipt/hash bindings. Restore into a new empty destination with sufficient space. Read `entries.jsonl.gz`; create its directories without following links. For each regular file, resolve its payload's exact archive/member and verify the expected bytes and hash before placing the file at its recorded relative path. Materialize each independent original file independently; only a recorded hard-link group may restore a hard link. Restore symlinks from their exact target bytes. Apply the recorded ownership, mode, ACL/xattrs and Darwin flags/timestamps with the required host privileges, applying directory timestamps after children. Re-inventory the complete result and compare all restorable metadata and file hashes. Preserve the historic identity fields as evidence instead of treating new inode numbers as a mismatch.

Restoring both full logical trees requires 3,834,717,585 bytes of file content before filesystem/block and temporary overhead. No capacity promise relies on APFS clones, compression, purgeable space, or unqualified SDK reuse.

## Capacity and limits

The Oracle receiver reserves **687,865,856 bytes**: 256 MiB floor, 300 MiB for the active UI lane, and 100 MiB for root/source work. It additionally holds 32 MiB for metadata and receipts during reception. The Windows and Mac preservation paths enforce a 2.25 GiB reserve. The receiver observed 2,140,758,016 bytes free after the completed stream. These are concurrent free-space observations, not exclusive attribution of every change on a shared host.

The pair's observed private allocation is distinct from archive size and logical file size. After this retirement, the final complete SDK, Debug/Release application pair, production data, and original native acceptance still require a measured capacity plan. Production data admission retains its original 24,000,000,000-byte working budget plus 2,000,000,000-byte OS margin and explicit concurrent reserve. The separately assessed SDK phase may proceed only under its own unchanged admission and actual write budget; this packet does not authorize a retry. A partial or interrupted SDK tree is not a qualified producer cache.

Original Native116, Release114+2, App SDK, live integrations, TestFlight, and physical-device acceptance are unchanged by this preservation work.

## Packet byte preservation

The actual executed Windows bridge_windows.py is preserved with its original 121 CRLF line endings, SHA-256 c7791d70b5254a6788a53641021b544e11d385d5b081124cab24e98f5cd256e8. Default git diff --check reports those CR characters as trailing whitespace. The raw output is retained in validation/PACKET_DIFF_CHECK.txt; no other file is flagged. The script was not normalized, because that would replace the executed evidence bytes. All eight Python scripts parse; this is syntax inspection only, not a re-execution or product test. All staged files were verified against the packet index. The small attempted Windows staging operation stopped at its reserve guard before creating a staging file; the final proof readback streamed only existing small files through memory and wrote zero staging bytes on Windows.

## Root intake storage of executed Windows evidence

After exact donor intake, root retained the executed bridge script as lossless scripts/bridge_windows.py.gz. Its 121 CRLF line endings and every raw byte are unchanged. The original packet index is retained as PACKET_INDEX.json.gz; the current index identifies this storage change. The historical raw whitespace-check result remains evidence of the original packet, and root checks the final integrated tree without disabling or changing the check. This is storage of executed evidence, not a re-execution or source normalization.
