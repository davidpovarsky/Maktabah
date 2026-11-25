# Backfill batch and full saved-text consumer

Source checkpoint only. This consumer depends on original SDK6168d8b4ee875b58f534eddec190d072cfb3a5ac and the Host preservation boundary ce0f62baba7360514e7fa8cad21f0caaf2d0ab8f. It incorporates root's exact closed batch-retirement bridge6f6e3c2a3ebfcc5b8c36247e113b65306d644b7d as ee724395f35a49c730daa84d13f5ddbab57378a8. The original13-case planning proof is unchanged. The earlier7323950c14-case native candidate gate remains a historical source-only checkpoint; no unexecuted gate is relabeled PASS.

## Behavior

The user explicitly chooses conversion in the existing preparation screen. The consumer captures the original profile/database/scene mapping, creates a closed batch source, links it synchronously to BOTH the actual run lifetime and captured connection lifetime, then calls the original SDK batch factory. The factory may create one private localOnly native Space; ordinary interactive editor opens remain unchanged.

Each selected original row is re-read through the existing LocalEditor, matched to its exact preparation/source/revision/identity, and bound to its actual per-note source lifetime before native materialization. The batch admits one UUID once and one active draft at a time. Capturing uses the original native editor/export without injecting or constructing native block bytes.

The full native text must equal the complete original saved note as exact UTF8. The bounded preview must equal the scalar-safe original prefix of at most8192bytes. The original SDK plain seed cap remains1,048,576bytes; larger notes stay unchanged and display a supported-size reason. Existing rich or unsupported bodies are kept opaque. Normalization, whitespace, missing suffixes, NUL, stale source or wrong profile cannot silently flatten or truncate a note.

Save uses the closed `prepareNativeBackfill(snapshot:mutationID:capture:nativeSession:hostProfileID:)` entry. Its actual source/capture checks and original SQLite CAS preserve the actual saved note bytes and metadata while adding the genuine rich body. The configured original CloudKit Save path remains intact. No Anytype destination/outbox/remote delivery claim is introduced by conversion.

At5000native admission attempts the run pauses visibly. Continue performs a new read-only canonical scan; successfully converted rich rows are skipped. Pause/owner loss retires current note and batch tokens, then independently retains the real native Stop/drain. Only failed Stop is retryable; no native creation or Save is automatically repeated.

## Verification prepared

The extended component runner compiles27 complete original Foundation/SQLite/source files on the real Mac and executes17 exact candidate/full-text boundary cases, an independent cold rescan and a separate read-only Python SQLite oracle. It uses the existing declared UI/CloudKit component doubles and an explicitly opaque test body. It grants zero native-engine, UI, CloudKit transport or native5000 credit.

New controls cover the8192/8193multibyte boundary, actual1MiB seed limit,1MiB+1 unchanged note, matching previews with different full suffixes, exact Hebrew/emoji scalar cutoffs, Unicode normalization and NUL. Existing ownership/profile/legacy identity/source revision/opaque body/tombstone/readonly/idempotent selection controls remain.

Actual Apple typing of the SDK/consumer, no-mount native capture, ordinary app UI/cold reopen and genuine native5000 performance are still pending. Exact source inputs are recorded in INPUTS.json. The original planner and the root-owned LocalEditor persistence/session algorithms were not edited by this consumer commit.
