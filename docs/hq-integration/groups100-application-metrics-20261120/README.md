# Original groups100 application observations

**Native execution, actual app timings and actual app memory samples are NOT_RUN.**
The 37 passing controls here are Windows Foundation/source-bound controls.
They do not establish that the 100-switch UI case passed or that performance
meets a product threshold.

Source commit: 42c9afa7b9ec8386c0fccd8fa5e9d3403b70abeb.
Base: d1ffa2bae34cd982ea7f081a7a463bacd2495f88.
Branch: codex/otzaria-groups100-performance-20261120.

## Original acceptance retained

The original iPad realUI case
StudyGroupStressNativeAcceptanceTests/testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore
still creates three groups using the original UI, verifies separate document
UUIDs, makes 100 consecutive real selections, checks exact membership/locators
and observes cold restoration. Every original assertion and operation is
preserved by the recorded whole-file inverse.

The same original case now explicitly enables a passive application probe.
Its two launches use the existing realUI overload that actually forwards the
case's additional arguments. The R27 base override otherwise omits those
arguments. No global launch helper or other case is changed.

The probe is compiled only in DEBUG. It requires the explicit process flag,
enabled defaults value, matching miniTest10 environment and active registry,
and a valid disposable workspace UUID. Disabled/production contexts emit no
measurement. It has a 512-operation process limit.

## What the application observes

Two additive blocks surround the accepted original switchGroup operation.
The original membership guard, staging, backend generation checks, transaction,
mapping publication, retained Reader instances, cancellation/error behavior,
and ordinary persistCurrentSession call are unchanged.

The monotonic interval starts after the initial memory probe and ends after
the original operation returns or throws, including its original defer.
It excludes the second memory probe, JSON encoding and asynchronous log I/O.
It measures the group operation through ordinary session persistence. It
does not measure first pixels, TextKit/layout completion, frame pacing or CPU.

The memory observations call the existing, unchanged
OtzariaIndexFileLogger.memoryFootprint implementation. On Darwin this reads
task_vm_info.phys_footprint. These are two operation-boundary byte samples,
not continuous peak memory or RSS. Unavailable memory stays absent and
cannot satisfy the Native evidence check.

The existing OtzariaFileLogger serial queue writes the small JSON observations
to its ordinary reader log. The new probe creates no persistence service,
sidecar owner, renderer, user-data action or acceptance acknowledgement.
It records UUIDs/revisions and process identity, not reading text or note content.

## Independent Native matching

The test reads the original reader log from the app container already verified
by the original sidecar ownership checks. Exactly 100 unique records must match
the independently observed scene, source/destination groups and document UUIDs.
Commit revisions must lie inside the corresponding UI observation interval;
ordinary background checkpoints may advance revision inside that interval.

The selected records must have consecutive sequence numbers, one launch UUID,
one positive process ID, distinct operation UUIDs, normal returns, the exact
backend/metric/scope, finite nonnegative durations and positive memory samples.
Missing, duplicate, stale, mixed-process, wrong-locator, unavailable-memory,
malformed or partial records fail the additional requirement.

Native attachments retain available matching-namespace raw records, then
nearest-rank p50/p95/max operation times, all 200 boundary sample points,
first/last footprint and the maximum observed boundary footprint.
No performance threshold has been invented. The existing XCTest tap-to-UI
timing remains separately labelled as automation observation time.

## Actual verification

- Swift 6 strict Foundation compile and execution: 37/37 controls, no failures.
  The real process clock/PID and actual probe are exercised. The registry and
  log writer are explicit test boundaries; the original complete memory-reader
  source is compiled. Windows returns unavailable memory and that fact is tested.
- A separate set of 100 **fake metric records** exercises the exact production
  Native evidence-reader source. Those records are test inputs, not benchmarks
  or app memory samples. Missing/duplicate rows, stale identities, revision
  errors, failed operations, metric substitution, process/launch changes,
  malformed JSON and partial expectations are all refused.
- Three whole-file DEBUG syntax parses passed with the two documented
  Windows-to-Apple-target warnings per file. They are not Apple SDK typechecks.
- Exact inverse reconstruction preserves the original adapter, Native test
  file and Xcode project bytes.
- The new file is registered only in the adapter's original Maktabah-iOS source
  phase F30576E22FA46222005732C6 and target F30576DD2FA46222005732C6.
  No new target, dependency, SDK pin, workflow or active CI ref is changed.

Peer review found the initially missing explicit PBX membership before any
Apple dispatch. Four additive project entries correct it. A missing-revision
fallback was replaced with XCTUnwrap before compilation. The initial membership
patch script had a Python syntax error before any mutation; its output is kept.
Initial preparation receipts are retained separately from final source proof.

The original 100-switch case must now execute against this exact source on
Apple. Physical iPad, full production corpus, Stage Manager, VoiceOver,
continuous-memory/CPU/frame profiling and final product performance acceptance
remain separate open requirements.
