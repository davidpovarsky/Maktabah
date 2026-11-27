# Interrupted fresh SDK attempt — immutable execution evidence

The original Anytype SDK source was 1be970356c655bcef3688ddf1d129d5029bbc533. Fresh execution local-21943899-924b-4a63-9f3b-556c0bf8fcfc reached the original framework build and was stopped at the owned process-group boundary when live free space crossed the supervisor reserve. The original execution reported FAIL, phase ORIGINAL_FRAMEWORK_BUILD; no SDK framework/consumer acceptance, app build or new native acceptance is supplied by this attempt.

failed-sdk-original-evidence.tar.gz contains all 57 regular files from the exact five named evidence roots in MANIFEST.json, including the original supervisor, recipe/contract, prelaunch rejection, both source snapshots, original package/build output, native ABI donor receipt, initial interrupted macro cleanup and its later original-script recovery. Every member was verified on Mac, Windows and Oracle. The failed receipts remain unchanged. The archive is 790,399 bytes, SHA-256 73d688afbf0adc80cfea3db7dd94c160b1a2f0a3bdf15da49d4faf464b9422e3.

The original prepare_reviewed_macro.py --restore subsequently returned exit 0 on its separately recorded recovery attempt. It reported PREEXISTING_APPROVAL_NOT_CHANGED_BY_THIS_JOB, wrote_trust_store=false. The trust-store before/after bytes are equal. This recovery does not change the original failed framework status or make the interrupted producer a qualified cache.

The large interrupted producer was separately preserved and retired by the scoped packet in docs/hq-integration/wave3-fresh-sdk-preservation-20261127. Both its verified base archive and differential are required for recovery; this smaller archive preserves execution evidence, not the producer payload.

The archived source-before and source-after snapshots are byte-identical. The root Maktabah Source tree is unchanged by this documentation-only intake. Original raw output is not normalized. No physical testing or TestFlight distribution is claimed.

An initial local orchestration submission was rejected by the JavaScript parser before any host/tool action because a Markdown backtick ended its template string. The corrected submission uses a separately encoded README. This preparation failure is not an SDK run.
