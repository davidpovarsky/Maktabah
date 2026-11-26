# Wave 2: managed library transaction recovery

## Verified result

Product and focused control source: `0d0a010c3ee1edda244f9fb37431016d12320234`, based on the exact integration source `29a731e273f9a757c743c49e182fece0e8047d46`.

Scaleway Mac, Xcode 27.0 / Apple Swift 6.4, 2026-11-26 22:44:07–22:44:19 UTC. SentinelX `job_261af3a4e8dc` completed with exit 0. The same nine controls compiled against baseline and candidate: baseline 4 PASS / 5 FAIL; candidate 9 PASS / 0 FAIL / 0 SKIP. These are real filesystem and SQLite component tests. The application/search bridge is an explicit fatal boundary, and unused zstd functions are supplied by the existing boundary. No app, Settings UI, full corpus, device or release acceptance is claimed.

The canonical receipt is `attempt-2/RESULT.json`, SHA-256 `67d91e9b7fff063eb071882cfb8b34c4e8a4f8fd5dc85c89cbf107a52d41cfbc`. It records all 23 exact source inputs, original baseline variants, toolchain and compile commands, binary hashes, the nine individual results, and unchanged source hashes after execution. The Oracle committed source was compared byte-for-byte against those inputs after retrieval.

## Fixed behavior

- Final release metadata is part of the installation commit. Failure now propagates while the prior database and identity remain available for rollback.
- An interrupted database replacement without a pending or committed identity rolls back to the previous snapshot. Full SQLite integrity and equal file size alone cannot identify a release.
- Restoring a missing final database also removes the abandoned pending identity. Malformed pending metadata rolls back before activation.
- A failed cleanup of the previous database retains the previous manifest as the committed-state marker; the next recovery preserves the new version and retries cleanup.
- Rollback while a metadata-path obstruction remains in place preserves an existing old stable manifest. The obstruction cannot replace it.
- The app adapter closes active connections before rollback, includes manifest finalization in its activation error handling, and restores the previous connection after an installer-managed rollback without rolling back twice.

## Controls and boundaries

Fixtures are distinct, same-sized valid SQLite files with `book`, `line`, and `category` tables. Both pass the original validation method. The same-sized fixture makes an old-manifest/new-database pairing observable. Real immutable flags on paths inside unique temporary directories induce metadata-commit and backup-cleanup errors. Every successful case checks an unrelated SQLite file remains byte-identical. This is a component preservation check, not proof of the live annotations, bookmarks, history or group UI.

The nine cases cover metadata commit failure with immediate rollback under the original obstruction, replacement before pending identity, missing final data, malformed pending metadata, valid pending recovery, committed-manifest recovery, cleanup failure, normal update, and the earlier pending-write rollback behavior. The pre-existing policy15/15, Multipart37/37, Library7/7 and full-v40 historical receipts retain their original source and scope; none is reassigned to this commit.

## Ownership and provenance

The live upstream HEAD observed read-only was `4203de5fd77beb119e5826e039be1a61325f7be0` at `bismillah-100/Maktabah`. No files under the affected paths appear in that upstream tree. The installer originates in fork commit `a19f9209c1d0cb7c369c6e9a947008f2332b6190`; the Bootstrap family is downstream Otzaria code. Current owner instructions authorize these repairs while retaining upstream boundaries.

| Path | Ownership | Change |
| --- | --- | --- |
| `Source/Otzaria/Bootstrap/OtzariaDatabaseInstaller.swift` | Downstream | Metadata commit, recovery and rollback safety |
| `Source/Otzaria/Bootstrap/OtzariaDatabaseBootstrapService.swift` | Downstream | Propagate metadata finalization failure before download cleanup |
| `Source/Otzaria/Bootstrap/OtzariaBootstrapAdapter.swift` | Downstream | Close connections and restore the prior activation after failed commit |
| `Tests/HQ/updates/LibraryRecoveryControls.swift` | New downstream test | Actual filesystem/SQLite failure and recovery controls |
| `Tests/HQ/updates/run_library_recovery_apple.py` | New downstream runner | Source-bound Apple compilation, results and hash receipt |

No upstream files, lockfiles, project file, shared native driver, search implementation, release selection, storage allocation policy or another agent's worktree were changed.

## Retained evidence and continuation

Raw Apple work: `/Users/m1/builds/otzaria-wave2-library-controls-20261127/attempt-2`. Source archive SHA-256 `2ba338846a2153f5d756abc6e47cf3b9599069d13ccfe354e1b2d448f9d6effc`, 56,339 bytes. The preceding attempt remains in the parent directory and `attempt-1`; it passed a less strict obstruction control before immediate rollback was added. Its SentinelX SSH wrapper timed out after 15 seconds, but the native process continued and wrote its result. That earlier result is not the final acceptance proof. A later job `job_e3f6213164f5` failed before execution because its destination had not been created; it ran no compiler or tests. The final job above has a real successful terminal status.

Root owns the integrated native app and UI execution. Production v40 installation/search acceptance stays explicitly frozen to requested v40. Ordinary Settings updates retain the real latest-release lookup, which now returns v41; a v40→v41 Settings journey must be reported separately and must not substitute for v40 install or published v40-index acceptance.
