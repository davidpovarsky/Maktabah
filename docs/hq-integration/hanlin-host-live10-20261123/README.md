# Hanlin Live10: bounded post-Send diagnosis

## Outcome and scope

This branch prepares an original-flow diagnostic. It does **not** claim to fix the Host receipt failure, qualify a live provider conversation, or complete UI-06.

Base: 1969b2065469b55e38e42cbb838a469ffa6a80f7.
Owned branch: codex/otzaria-hanlin-host-20261123.
Task: https://app.asana.com/0/0/1220542467495722.
SDK remains pinned to e00498e33f106cc43be0476ffa2e09329c8ca300.

## Original failure recovered

Run https://github.com/davidpovarsky/Maktabah/actions/runs/45058647581
used 9533a8017adadecf770b19811e72b495f32e90f7.
The one real native test failed after 255.77671599388123 seconds at
HanlinConsumerAcceptanceTests.swift:674, waiting for the original Host source button.

Original artifact 14769219319 is retained unchanged as
original-artifact-14769219319.zip: 91,105 bytes,
SHA256 c06f5fde77b026fcd68af1a7667bc34742becb89cdd2ed409f235495d1ddcc0d.
Its 23 members and CRC were checked. No prior archive existed in either migrated
Live10 build directory or the owned checkout; this intake fetched the artifact once.

The 21 original fixed-schema events reach configurationCompleted with no overflow
and no recorded connection rejection. They prove the read consent/dismissal/reopen
and configuration sequence, not successful Send, provider execution, tool dispatch,
or source receipt creation.

The log says final hierarchy/screenshot attachments were added to the xcresult.
They are **not** among the 23 published artifact members. GitHub lists only this
artifact for that run. The raw result bundle/container were intentionally not
published. No missing screenshot or hierarchy is presented as reviewed evidence.

The pinned SDK invokes onHostResult only after original receipt persistence and a
fresh context check, and before returning the tool output to the engine
(Packages/HanlinAgentSDK/Sources/HanlinAgentCore/HanlinAgentSession.swift).
This inspection does not support an asserted callback-order race.

## Change

Only one existing downstream product file changes:
Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift.

Its existing diagnostic gains 19 fixed stages spanning Send admission and checkpoint,
stream opening/completion/failure, original Host callback/retention, tool events,
source creation, and final settled state. Seven additional flags are booleans.
Fifteen additional reason labels classify existing public Host/SDK error cases;
associated text, tool names, attempts, and provider payloads are discarded.

Only the three matching enum sets change in Scripts/CI/runtime27-hanlin-live.py.
The complete rest of that Python module is AST-identical to the base. Original
owned-input binding, simulator-only writer, 96-event/9-flag caps, 64-KiB collector
limit, private atomic writes, and evidence admission rules are preserved.
No raw model/source text, credentials, account IDs, UUIDs, or provider call IDs
are added to the journal.

No original assertion, receipt authority, error outcome, Host invocation, SDK pin,
project file, workflow, routing composition, or existing product test changes.
The two edit receipts show exact inverse reconstruction through their recorded
before/after hashes. Git history locates the two changed files in downstream work;
neither exists at pinned upstream d46af139b3a265399c16d87f5923acd8e3444024.

## Validation

Four new schema/privacy controls executed once and passed:
Tests/HQ/hanlin-host/test_stream_diagnostic_schema.py.
They check exact Swift/Python vocabulary parity and retained old values, admission
of new bounded enum/boolean combinations, rejection of strings/numbers in new
flags, and preservation of original collector/private-writer guards.

swiftc -frontend -parse -target arm64-apple-ios27.0-simulator passed for the final
Swift source. This is syntax-only on Linux; it is not Apple typechecking or runtime
acceptance. git diff --check passed. VALIDATION.json records exact inputs, commands,
exit codes, and stream hashes. Original accepted suites were not rerun.

## Next required result

The coordinator owns credential lifecycle and any new live dispatch. No credential
was read/created and no provider/Apple run was started by this branch.

One coordinated, source-pinned live continuation must collect the extended original
journal. Use its actual last stage/error class and tool/source flags to determine the
root cause. If no source was created, do not substitute a fabricated callback.
If sourceLinkCreated and settled hasSources=true occur, diagnose the actual mounted
UI separately. A source pin or workflow admission change is a separate reviewed
integration step; this diagnostic commit does not alter that gate.
