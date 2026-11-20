# SQLite acceptance fixture: async barrier correction

## Observed failure

Apple SDK run https://github.com/davidpovarsky/Maktabah/actions/runs/44648487731
compiled source 83bc48f7b27e41d5580124a974d78bfad6ace50c and rejected five
DispatchSemaphore.wait calls from async contexts in the acceptance fixture:
original lines 69, 81, 94, 262, and 288. The retained diagnostic is
apple-sdk-original-failure.log.gz (exact bytes); the readable .log only normalizes
trailing whitespace. Its durable parent evidence commit is
41cd32b0ea8857241d05f9e2fe977461cf2af3c6.

The correction is based on bd5142ca5da7c7fe6b658dba2323ac0b463b6672.

## Source and ownership

Only Tests/HQ/sqlite/SQLiteDatabaseAcceptance.swift changes executable source.
It is an existing downstream acceptance fixture introduced in be9f4718 and
extended for actual lock cancellation in b3ae11f7. Source/Core/Database/SQLiteDatabase.swift,
the original acceptance driver, and the shared Apple typecheck script remain
unchanged. The remaining added files are evidence in this directory.

A private async helper suspends its Swift task through withCheckedContinuation
and performs the bounded semaphore wait on a Dispatch worker. It is not a
synchronous wrapper called on the cooperative executor. Each absolute
DispatchTime is evaluated by the caller before enqueueing, so queue delay cannot
restart the timeout. One bounded wait resumes one continuation exactly once.

The helper does not check, consume, or translate task cancellation. The original
SQLite fetch must still observe cancellation in its own task. The synchronous
outer 15-second harness join and the actual synchronous SQLite holder row
callback remain unchanged; the latter intentionally holds the real recursive
lock for the contention oracle.

All original 28 require assertions and all case registration templates are
retained. Existing 5-second barriers, the 250-ms completed-before-owner-release
gate, 5-ms cancellation setup, and 32 acquisition-race repetitions remain.
Two previously ignored start-barrier timeout results now fail explicitly,
preventing a failed fixture start from falling through into a fetch.

## Actual validation

| Run | Executed | Passed | Failed | Meaning |
| --- | ---: | ---: | ---: | --- |
| Windows current production plus corrected fixture | 26 | 26 | 0 | Actual SQLite 3.53.4, complete original wrapper, current cancellation behavior |
| Same corrected fixture plus exact pre-fix production b3ae11f7 | 26 | 23 | 3 | Negative control still exposes the three original cancellation defects |

The failed negative-control cases are pre-cancelled fetch, cancellation while
contending for the real lock, and cancellation as the recursive lock becomes
available. The same fixture source hash and same 26 case identities were used
for both runs. This demonstrates that the async waiting fix does not replace
the production cancellation test with a fixture cancellation error.

The current-production run uses the unchanged tools/hq-sqlite-acceptance.py.
The negative control compiles the exact original SQLiteDatabase.swift Git blob
from b3ae11f7 in an owned build directory, with that same fixture and compiler
command. The tracked production file is never replaced. Each execution creates
a separate UUID-owned fixture database.

One existing full-v32 source is opened only through mode=ro&immutable=1 and
SQLITE_OPEN_READONLY. The original Python query independently supplies the five
expected source rows; the Swift wrapper must return those same identities.
No full corpus is copied, created, or rewritten. This is the existing source
identity check, not a new full corpus stress or coverage claim. The ZSTD
fail-on-call boundary remains unexecuted.

The original driver command and exact source hashes are in windows-green.json;
the old production ref, copied blob hash, compile command, and results are in
windows-old-production-red.json. verification.json binds the LF-normalized
source files to both outcomes. Source inventory also records all preserved
registration templates and timing gates.

Independent read-only review by github_native_audit found no source/logic
blocker: caller deadline, exactly-once continuation, cancellation state,
holder-release cleanup, and original gates were retained.

## Remaining gate

The corrected fixture has not yet run on the Apple SDK or Native UI in this
tranche. Windows validation does not prove Apple compiler acceptance. The parent
will freeze the combined source and rerun the actual Apple workflow. No fixture
case, failure assertion, production SQLite behavior, or Native gate is removed.
