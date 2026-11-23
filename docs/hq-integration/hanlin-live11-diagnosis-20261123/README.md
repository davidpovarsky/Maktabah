# Live11 evidence diagnosis and bounded stream observations

## Result and acceptance boundary

Live11 run [45103578190](https://github.com/davidpovarsky/Maktabah/actions/runs/45103578190) failed its one original native acceptance test. The actual app build passed, but the test recorded zero passes, one failure and zero skips. Its assertion at HanlinConsumerAcceptanceTests.swift:674 did not observe the source receipt that only the original Host result callback can create.

The run's immutable source is fdb78a44778c318b277506f0b09ba91c3b678e91. Its reviewed application source is 438de95a675f34006bee54e339b37d88c87c032a. Vendor/HanlinSDK is the unchanged original gitlink e00498e33f106cc43be0476ffa2e09329c8ca300.

This packet contains a downstream diagnostic extension and source/schema controls. It does not fix the Host, qualify a provider conversation, replace the native oracle, or authorize a live run. No credential or provider request was accessed or sent during this preparation. The existing accepted no-send result remains historical lineage; this changed diagnostic application tree is not asserted equal to that earlier app tree.

The existing Live11 workflow, reviewed-source binding and source-admission controls are deliberately unchanged. A separate reviewed source admission would be required before executing this candidate.

## What the actual retained evidence establishes

The retained ZIP is 90,039 bytes with SHA256 6fc18f6d96e3f12c36b888eabdefdb97cded20706f04faa7e513863dfc015b65. All 23 ZIP members are CRC-valid and all 22 file rows in admission.json match their retained byte counts and SHA256 values. The source-before and source-after snapshots are byte-identical. The archive is reused from the original intake and is not duplicated here.

Its bounded connection journal has 27 events and overflow=false. It records completed source-qualified consent/configuration, send checkpointing, stream opening, stream opened, normal stream iteration completion, and send settlement with closed=false, hasActivities=false and hasSources=false. It contains no Host-result callback, toolCall, toolResult or toolOutputDenied event and no thrown stream error.

The callback's journal call precedes its closed/streaming/session guards. The toolCall journal call likewise precedes its validation guards. Therefore this evidence does not support reordering the callback, loosening its source checks or fabricating a source receipt. It places the observed gap before any recorded Host callback or complete tool call.

The current adapter does not record several original public events. The original e00498 engine can finish its outer stream after:

- A real finished event. Its final-content guard accepts visible text or a denied approval even when no Host tool completed.
- A real abort event, emitted to the adapter as cancelled.
- End of the underlying fullStream without a terminal finish event, through the existing fall-through at HanlinAISDKAgentEngine.swift:458–460.

The current retained journal cannot select among those paths. An original AgentSession completion with outcome completed is also insufficient by itself: that session calls completion after normal source exhaustion. No provider text, raw response, screenshot, hierarchy or conversation container is present in the published ZIP.

## Exact evidence hash representation

The original tools/verify_xcresult_zero_skips.py, at the immutable Live11 source, hashes json.dumps(value, sort_keys=True).encode() for the parsed summary and test tree. It writes each sibling file using json.dumps(value, indent=2) followed by a newline. The live evidence admission function scans and copies those written bytes unchanged.

Both retained JSON values reproduce their declared canonical hashes:

| File | Retained file SHA256 | Declared canonical JSON SHA256 |
| --- | --- | --- |
| verified-11.summary.json | d1f7a93702215c85ca749aa34d7c374c8d0948cf404239ffd620eb410a8f53be | fb264bdb45a0267e33565bc9ba7d60e605e0432e2d2554a610b2097bf504c2ab |
| verified-11.tests.json | a8a24e18d44b05471776348ce7e4b139f0a709289cdaae2baf515940aa257142 | 3770d4e59609a981a62bb17ef497156d88a278913476cc04ef54767c779343f2 |

This validates the declared parsed-JSON representation. It does not verify the unpublished raw xcresult bundle.

## Two-file diagnostic delta

Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift extends its existing DEBUG/simulator, one-input-owned journal. It observes original public stream and completion events:

| Original observation | Bounded fact retained |
| --- | --- |
| runStarted | Fixed event type |
| stepStarted | Whether aliases are nonempty, whether the two exact existing search/reference aliases are present, whether schema bytes are positive |
| text/reasoning deltas | First visible text / nonempty reasoning observation per send |
| tool argument start/delta | First start / nonempty delta observation per send |
| tool approval request/resolution | First request and first resolution; resolution is one boolean |
| stepFinished | Fixed finish bucket and whether meaningful event count is positive |
| finished / cancelled | Original event type and fixed finish bucket where applicable |
| onRunCompletion | Original completed/cancelled/failed outcome, original session comparison as a boolean, existing safe error classifier |
| send settlement | Whether the original assistant message and reasoning contain text |

Finish strings map only to fixed stop/tool-calls/length/content-filter/error/other enum buckets. Provider strings themselves are never serialized. The existing first-observation state stores finite enum raw values only, is reset after the actual send checkpoint, and cannot grant authority. The completion callback only journals; it does not settle, cancel or invalidate the original run.

The existing 96-event limit, nine-boolean-per-event limit, 64KiB collector limit, overflow behavior, private-input ownership, original connection/send/Host lifecycle, stream processing, callback guards, SDK/provider/model configuration and native test assertions remain unchanged.

Scripts/CI/runtime27-hanlin-live.py changes only the three finite enum allowlists. It does not change credential handling, source binding, execution, collection, cleanup or acceptance.

Both modified product/control files are existing downstream-owned adapter/CI files. No upstream Maktabah source, shared Hanlin SDK source, UI, dependency, project or workflow is changed.

## Focused verification actually executed

Five new source/schema controls pass:

1. The expanded Python allowlists match the actual Swift enums, and the new finite schema values are admitted.
2. Dynamic payload fields, arbitrary event/reason strings, unknown flags and nonboolean flag values are rejected.
3. The largest expanded fixed values still fit 96 events inside 64KiB; a 97th event is rejected.
4. The complete runner AST is unchanged outside the three allowlist assignments; the collector validator is unchanged.
5. Applying the exact inverse substitutions restores both original fdb78 source files byte-for-byte.

These are explicitly synthetic schema controls and source comparison. They do not inject or simulate a Host callback and are not native runtime proof. A portable Swift 6.4.3 syntax parse also passed on aarch64 Linux. It is not Apple SDK or imported module typechecking.

Retained controls: CONTROL_RESULT.json, CONTROL.stdout.log, CONTROL.stderr.log and SWIFT_SYNTAX_PARSE.json. DIAGNOSTIC_SOURCE_DELTA.json and DIAGNOSTIC_ONLY.patch preserve the exact reversible delta. SOURCE_PROVENANCE.json binds original sources, actual intake and candidate bytes.

Remaining gates: independent patch review, any future exact-source execution admission, genuine Apple build, and the unchanged original live native acceptance. Root owns any subsequent provider credential lifecycle and run decision.
