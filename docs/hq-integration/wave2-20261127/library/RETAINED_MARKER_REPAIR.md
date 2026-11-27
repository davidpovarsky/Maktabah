# Consecutive update: retire the previous transaction before replacement

Wave 3 reproduced a genuine recovery defect against `0d0a010c3ee1edda244f9fb37431016d12320234`. Its evidence commit is `d9e299787302a7c6ac6475120ada760de80781ba`; the original Apple result SHA-256 is `666930306b64f16ea1331c103cd8f0c63fb8c7272aa808c3f6c332f8802c111a`. The original nine controls passed and the new consecutive-update control failed. The new fixture uses distinct, valid, same-sized SQLite databases with synthetic release identities. It is not production-corpus or UI acceptance.

## Cause and repair

If cleanup after the first update cannot delete the old database, the implementation correctly retains its previous-manifest marker. A later `promote` previously removed that previous database but reused the marker. Interruption after the second replacement, before its pending identity persisted, could therefore misidentify the second database as the first committed release. File size and SQLite integrity cannot identify a release.

Under the existing database-mutation lock, the repaired `promote` retires the previous database **before** retiring its previous-manifest marker, and completes both operations **before** another replacement. If database cleanup fails, its marker remains available for correct recovery. If marker cleanup fails after database cleanup, the current database and matching stable manifest remain untouched. A pending identity together with a retained previous database rejects a new transaction until normal launch recovery has activated and finalized that transaction.

The installer path is downstream-only relative to inspected upstream `bismillah-100/Maktabah` commit `4203de5fd77beb119e5826e039be1a61325f7be0`. No upstream path, release selector, Settings controller, native observer or corpus was changed.

## Controls

`Tests/HQ/updates/LibraryRecoveryControls.swift` now adopts the **exact, unmodified** ten-case control source from Wave 3. SHA-256: `1bf7513e57ae772870395dad9637717892a69c3f80c90dc2e3092084d33ab16b`. Its original nine case bodies and helpers remain byte-for-byte unchanged. The normal component runner now requires ten passing cases instead of nine.

The candidate run uses Wave 3's exact `run_control.py` and ten-case source in a new owned Apple directory, with a fresh input manifest binding the candidate product commit. Its prior nine-pass/one-fail receipt is reused as the negative control; no duplicate baseline rerun is needed. Native candidate results will be committed separately when observed. At this source checkpoint, candidate native status is **NOT_RUN**. No UI or full-production acceptance is claimed.

The earlier Settings retry test's immutable previous-manifest obstruction must be moved to the pending-manifest write after the old reader has cold-opened, because strict retirement now correctly rejects an obstruction at the previous-manifest path before replacement. That tests-only followup is tracked separately; the old test is not claimed as executed acceptance.
