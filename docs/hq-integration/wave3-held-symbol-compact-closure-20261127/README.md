# Held symbol outputs and the compact workspace: read-only closure evidence

## Outcome

No process, simulator, source, cache, artifact or directory was changed on the Mac. The three protected symbol uploaders hold approximately 221 MB of zero-link executable allocation. That is insufficient for the SDK capacity deficit. The complete compact workspace is also not an independently closed retirement scope: two existing external Git worktrees use its common repository.

This report records original state and dependencies. It does not authorize preservation or retirement, claim a completed archive, qualify old SDK artifacts for a new source, or claim a build/native/physical/distribution pass.

## Protected uploaders: exact kernel evidence

All six PID/start/parent identities were checked before and after the metadata read. Mac `ps` start times use CET (UTC+01:00). The uploaders and their original shells were sleeping, with observed 0.0% CPU; each shell's parent was PID 1. These are observed process states, not proof that a network operation can be discarded.

| Uploader / shell | Start UTC, 2026-11-26 | Device / unique held inode | Logical bytes | Allocated512-byte blocks | Allocated bytes | FD3 offset / links |
| --- | --- | --- | ---: | ---: | ---: | --- |
| 18665 /18664 | 20:12:58 | 16777232 /65257836 | 73,643,232 | 143,840 | 73,646,080 | 0 /0 |
| 35620 /35619 | 16:01:38 | 16777232 /60649716 | 73,571,512 | 143,696 | 73,572,352 | 0 /0 |
| 41372 /41371 | 16:09:32 | 16777232 /60745183 | 73,571,512 | 143,696 | 73,572,352 | 0 /0 |
| Unique total | | Three distinct inodes | 220,786,256 | 431,232 | 220,790,784 | |

Both `txt` and fd3 references to the same inode were deduplicated. The installed Mac27 headers were hash-bound before calling `proc_pidfdinfo(PROC_PIDFDVNODEPATHINFO)`. All calls returned the exact 1200-byte structure and matched the independent lsof device/inode/size/zero-link tuple. The installed `sys/stat.h` defines `S_BLKSIZE 512`.

This API supplies vnode blocks and offsets; it does not expose exclusive APFS extent ownership. The allocated total is not a guaranteed reclaim estimate. No executable bytes were read, recovered, hashed or copied from a process.

PID18665's cwd is the original `actual-paired-production-release.Hguhbz1S/Maktabah`; the other two use `session.ntx0UjXO/runner/_work/Maktabah/Maktabah`. The currently named paired app is a different, still-linked inode65359362,73,787,360 bytes. Its current path must not be treated as the deleted inode's preserved payload. The ntx ReleaseDerivedData app path is absent from the current directory tree.

The earlier immutable manifest lookup, SHA `1bdec4b428f908b4dae42ee1d89af0d3953c0fc2d309e9e8e898fc68164e46da`, found no exact inode or size match in its four referenced preservation manifests. This read did not repeat that scan or establish any new payload recovery.

## Original build records remain distinct

The job-level ntx Release pass at 15:20 UTC predates both later uploader starts. The initially retained paired `compile.exit 65` at 20:00 UTC likewise predates the held paired inode born 20:12:56. Those older records alone cannot close the later invocations.

The scoped later records are preserved as exact path/hash receipts:

| Original later attempt | Actual record |
| --- | --- |
| actual-app-release-production.l99oRFHb/compile | RESULT `778c3c686eb1a613500407d5b72bbce77d9182c9d8e6854077df6891f8c8a99f`: FAILED; actual log contains TEST BUILD FAILED. |
| actual-app-release-production-retry.3Ay5HhXW/compile | RESULT `7ab2f71b39a83057b0123bbac3a1b4d941287c32317e806f1b8280c3f3c91063`: FAILED, even though its compile log contains TEST BUILD SUCCEEDED. The failed overall result is retained. |
| actual-paired-production-release-expo-root.qliOcHpp | compile.exit 0; RESULT `9924d0f9e6f4641db4a0424d931681818274f2e965c19596f4e974c648bb912a` binds application 334ce9f2, checkout 99f0244e, build 195 and original SDK 75a98ba. Runtime remains NOT_RUN. |
| owner-verified-current-production-release.0Uv90ibO | Separate later compile.exit 0; RESULT `53dc54d528cbeacb3e1c5c7b9defad72a4b7d4de0759640b625e0f889a0ac849` binds application 31b29f8f, checkout a6497250 and the newer preserved linked app. Runtime remains NOT_RUN. |

Their times and original workspace associations establish the historical investigation context. No receipt in this packet cryptographically binds newly read bytes of the zero-link inodes, because those bytes were not read. No uploader termination is proposed.

## Entire compact root: measured state

Exact root:
`/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/compact-reader-preview-worktree.5hRb5SYt`
on device 16777232, inode 61610714.

| Observation | Value |
| --- | ---: |
| Enumerated entries, excluding the root entry itself | 160,377 |
| Regular files / distinct regular inodes | 128,191 /128,191 |
| Directories / symlinks | 24,916 /7,270 |
| Logical file bytes | 11,947,125,221 |
| Unique allocated file bytes | 12,307,562,496 |
| Sum of per-file kernel-private bytes | 3,013,525,504 |
| Private-allocation errors / multiply-linked regular files | 0 /0 |
| Actual bounded inventory duration | 29.035 seconds |

All symlink resolutions in the observed compact tree remained inside that exact root. Its 23 SourcePackages alternates likewise point to repository objects inside the same SourcePackages root. Four submodule Git-pointer files were retained in the metadata receipt. These checks are source/dependency observations; the stat-stream hash is not a complete content/ACL/xattr preservation manifest.

The per-file private total is conservative: APFS shared extents are not counted as private even if more than one holder lies inside a proposed larger scope. Do not claim that 12.307 GB would be freed, or that 3.014 GB is a guaranteed whole-root result. Exact future recovery and reclamation decisions require the complete clone/dependency context and a fresh observation.

| Compact group | Kernel-private bytes |
| --- | ---: |
| Maktabah/Vendor | 974,905,344 |
| Maktabah/build/SourcePackages | 880,197,632 |
| actual-direct-note-and-journey-native.MPhjQT6z | 317,960,192 |
| actual-single-native-annotation-and-side-sheet.HBYcazsK | 134,529,024 |
| current-unresolved-native-routing.tIHTyv7r | 128,921,600 |
| actual-original-annotation-and-toc.EPPPlMXb | 128,716,800 |
| Maktabah/build/wave3-native-0db0ab78-sdk2 | 116,690,944 |
| Maktabah/Pods | 113,569,792 |
| wave3-notes-ack-bbc7a04b-20261127 | 108,584,960 |

The main repository is detached at 6935f7fdd0f5e982a8deb44fc438bcfecb2cb8a6. Its known generated PBX and PrivacyInfo changes remain present and must be preserved exactly. No source admission or owner verifier was run against this worktree. No scoped open files were observed, with the unrelated lsof rows discarded rather than retained.

The current d609 SDK source's Git alternates point to the separate original W1 ABI store, not this compact root. The exact SDK controller paths read contained no compact-root literal. Known current paired PBX/workspace metadata similarly contained no compact-root locator. These bounded checks do not constitute an exhaustive proof that every possible consumer is absent.

## Two existing external Git consumers

Both worktrees exist, are clean with respect to tracked files in the scoped status read, and resolve to the compact main `.git` as their common store. No open paths were observed in either at 16:18 UTC.

| Exact worktree under the same original actions parent | Worktree inode | HEAD | Original closure evidence |
| --- | ---: | --- | --- |
| exact-three-sdk-transport-verification.5DfXvIjL/Host | 64577884 | c7e1c8d1924166a2de9069e8ce4319204152b3bb | original-three-route-stage.json records EXACT_ORIGINAL_SDK_VARIANTS_STAGED. This is staging, not a native build. |
| reviewed-new-original-simulator-sdk-host-admission.nw59FCm9/Maktabah | 64400346 | c7e1c8d1924166a2de9069e8ce4319204152b3bb | Original admission.exit1 and subsequent ci-path-admission.exit0 both remain. |

Their 145-byte and 149-byte `.git` pointer files are hash-bound. These are real incoming references, not stale registrations inferred from names. Removing only the compact root would break them. A future whole-graph archive must preserve both worktrees' exact source/delta/metadata, the common objects, refs and per-worktree administrative files, and all original receipts before any separately authorized graph retirement. This packet creates no such archive and changes no pointers.

## Capacity conclusion

The full compact read observed free bytes changing 8,087,474,176→7,206,416,384 concurrently. The unchanged SDK launch admission remains 15,032,385,536, with unchanged live reserve 2,415,919,104. These are observations of shared capacity; this read made no Mac files and does not attribute the decline to any particular workload.

The held binaries and the small isolated SourcePackages/SDK2 candidates do not establish sufficient capacity. The whole compact graph requires preservation and dependency closure first, and its allocated size cannot be substituted for known reclaim. The root owner requested examination of the next exact historical root-owned candidates; nothing in this report permits touching paired production, current Hanlin/Anytype, source gates, protected simulators or foreign work.

## Two additional exact original input roots

The next root-assigned input scopes were inspected at 16:22 UTC. Neither had observed open references, and no contents were archived or removed.

| Exact child of the original actions parent | Root inode | Allocated bytes | Per-file kernel-private bytes |
| --- | ---: | ---: | ---: |
| exact-go-archive-recovery.JvVNJyCs | 63006231 | 1,025,282,048 | 216,309,760 |
| immutable-stage2-artifact-inputs.HZMBWCuD | 58997527 | 555,917,312 | 555,917,312 |
| Total | | 1,581,199,360 | 772,227,072 |

The Go scope contains three original admitted archives and their recovery/compiler receipts. Each large .a file reports two clone references and zero private bytes; the 216 MB compressed recovery archive is private. The immutable stage2 scope contains four original GitHub artifact ZIPs plus source/job/manifest evidence. These are original recovery/build inputs, not newly qualified caches or disposable output.

The unchanged current SDK controller search and the read future supervisor metadata contained no exact literal path to these two roots. The encoded execution recipe was not reinterpreted in this narrow check, so this does not establish full future-consumer absence. Their original input meanings and all remaining recovery dependencies must be preserved before any subsequent proposal.

The final sample here was 6,562,983,936 available bytes. Even their combined 772,227,072 private bytes do not establish the more than 8 GB requested headroom. There was no process action or Mac write, and no attribution of the shared capacity decline.

## Evidence and field clarification

Every original observation, transport receipt and script is preserved under `evidence` and `scripts`, with lossless gzip for raw snapshots. `RESULT.json` binds exact Oracle source paths and raw hashes; `ARTIFACTS.json` verifies the packet. The original SDK header pins and vnode layout interpretation are retained.

The first raw receipt's `file_payload_read:false` and the second's `payload_bytes_read:0` are narrowly scoped to the held application executable payload. Installed declarations and explicitly named historical logs/JSON metadata were read, as shown by their receipt fields. The canonical result makes this scope explicit; no raw receipt was rewritten. All `writes:0` fields refer to Mac-side inspection; the small reports themselves were saved on Oracle and committed to Git.
