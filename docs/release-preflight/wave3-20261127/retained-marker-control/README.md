# Consecutive update with a retained cleanup marker

## Observed result

**The defect is reproduced on Apple.** Product source is exactly
0d0a010c3ee1edda244f9fb37431016d12320234. On Scaleway Mac, the unchanged original
nine filesystem/SQLite controls passed and the added tenth control failed:
**9 PASS / 1 FAIL / 0 SKIP**, actual process exit **1**. This is a regression
finding, not product acceptance.

SentinelX job: job_90ace220a2b3. Test runner interval:
2026-11-26 23:36:02.701795–23:37:40.727463 UTC.
Xcode 27.0 (27A266a), Apple Swift 6.4, arm64 macOS 27.
RESULT.json SHA-256:
666930306b64f16ea1331c103cd8f0c63fb8c7272aa808c3f6c332f8802c111a.

The failure is:
> Recovery accepted the second database under the first update's stable identity

The original nine cases and their helpers remain byte-for-byte intact in the
diagnostic copy. The only additions are CryptoKit for fixture fingerprints,
one test-list entry, and one case. Product files, original test runner, original
test suite, source admission, owner approvals and release gates are unchanged.

## Exact sequence

The original fixture creates distinct, valid, same-sized SQLite databases.
The release labels/IDs 32, 40 and 41 in this fixture are synthetic component
identities. This test does not download or exercise a production corpus.

1. Promote the first update with the original installer.
2. Make its previous database immutable and complete promotion. The first
   update's stable manifest commits, while cleanup retains the previous
   database and previous manifest.
3. Remove only the fixture's immutable flag. Do not call completePromotion
   again. This represents cleanup becoming possible before a new update.
4. Prepare and promote a distinct same-sized second update through the same
   original installer.
5. Remove the new pending manifest to represent interruption after database
   replacement but before its pending identity persisted. This is exactly the
   interruption model used by the original unrecordedReplacement control.
6. Run the original recoverInterruptedInstallation.
7. Require restoration of the first update's committed database and identity.

The actual recovery leaves the second database active under the first update's
stable release identity. The trace in run.log and RESULT.json preserves the
file size, SHA-256 and manifest release ID at each transition:

| State | Final database SHA prefix | Stable manifest release | Previous database SHA prefix | Previous manifest release |
| --- | --- | ---: | --- | ---: |
| First commit; cleanup retained | b262a2e0 | 40 | 55f7387c | 32 |
| Second replacement; no pending identity | fd8ee643 | 40 | b262a2e0 | 32 |
| After original recovery | fd8ee643 | 40 | b262a2e0 | 32 |

Every database is 16,384 bytes and passes the original SQLite validation. Equal
size and integrity therefore cannot distinguish the two releases. The unchanged
old cleanup marker satisfies the recovery guard even though it belongs to the
previous transaction.

The original cleanupFailure test finalizes cleanup before its next operation.
It proves recovery of one transaction; it does not cover this consecutive-update
sequence. This finding does not invalidate its reported nine successful cases.

## Repair constraint

Before accepting another replacement, the implementation must distinguish or
retire the prior transaction's marker. It must preserve the latest committed
database and matching manifest if the next transaction has no pending identity.
Simply accepting any previous-manifest file is insufficient. Wave 2 owns the
product repair; this branch intentionally contains only executable evidence.

## Reproduce

The prepared archive is 58,582 bytes with SHA-256
d6872dff98952aa6a88f03f1b97975903cce6f52b677cf3e5ab4cf025fee05e5.
It contains exact Git-derived inputs from the product commit and its original
baseline, the diagnostic control, and the existing fatal app/search boundary.
REPRODUCTION_INPUTS.json binds every input by bytes and SHA-256.

Extract prepared-source.tar.gz into a new, dedicated directory on the Apple
runner, then run:

~~~sh
python3 run_control.py --prepared-dir /absolute/path/to/new/prepared-directory
~~~

The command requires Apple SDK/compiler and the existing /opt/homebrew/lib
zstd library. It uses a private module cache. It preserves a nonzero test exit;
NEGATIVE_CONTROL_REPRODUCED describes the evidence, never a green product gate.
Use a fresh directory for a rerun because compile.log is created exclusively.

The retained original run is:
    /Users/m1/builds/otzaria-wave3-library-retained-marker-20261127

The source archive, control and runner, exact input manifests, terminal job
receipt, raw compile/run logs and result are retained alongside this report.
The compile log is empty because compilation succeeded without diagnostics.
The Mac source/output directory is preserved; no shared cache was modified.

## Limits and resources

The application/search bridge is the same explicit fatal boundary from original
evidence commit 618dd4d1fdabae66b4f515436e006c216734a36e. No app UI, simulator,
production installation, live annotation/history store, iPad, iPhone or physical
device test ran. All source input hashes were checked before and after.

Mac free bytes were 7,418,286,080 at staging and 7,002,439,680 at completion.
These are host-wide observations while other owners were active, not this
control's measured disk high-water mark. Staging reserved a conservative
536,870,912-byte incremental budget. No cleanup was performed.
