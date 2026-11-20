# Explicit current-work read consent for the original Hanlin consumer

Status at the source commit: implementation prepared; Windows syntax parsing completed for eight changed Swift files. The bounded original-Core/Host and original filesystem-store continuations are running. No Apple build, Native UI, real-provider search, or physical-device acceptance is claimed here. The subsequent evidence record must identify actual executed cases before any acceptance status changes.

## Provenance and scope

- Base app source: `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`.
- Original Hanlin SDK: `e00498e33f106cc43be0476ffa2e09329c8ca300`; the gitlink, SDK source, original engine, dispatcher, session, presentation modules and store remain unchanged.
- Branch: `codex/otzaria-hanlin-read-actions-20261120`.
- Tasks: ACTIONCORE `1219614315863536`, SEARCH-API `1219614472017979`, UI-03 `1220542361203468`.
- Only the existing adapter, native composition, original chat owner/session/view and their tests change. No workflow, project membership, deployment target, transport, write-action or backend implementation change belongs to this tranche.

The previous production host grants discovery and navigation, with no content-rights authority. Optional publication-license metadata cannot create that authority. This change adds an explicit native user action, default OFF, for one source-verified current Otzaria work. It does not infer consent from opening the reader/chat, selected text, metadata, or a model argument.

## Actual authority and lifetime

The existing connection form shows the original reader book title and the Otzaria backend. Its opt-in text explains that, when the user sends a message, matching excerpts may be sent to the configured service/model. Initial support requires an authoritative original Otzaria reader tab and a canonical positive `book:<ID>` work key. Unknown sources, Sefaria and Embedded have no read offer.

Connect validates the original immutable SDK model configuration locally and creates an ephemeral UUID for that exact endpoint/model/key configuration. The one-use consent witness binds the old SDK session, conversation UUID, profile/group/backend namespace, complete original native source observation and configuration UUID. The observation includes the backend generation/RPC epoch, original workspace source identity/mapping epoch, projection/active tab, reader content/focus, selection range and locale.

The original scene registration retains the same pending consent object while the old SDK session closes. Existing source/foreground/lifetime invalidation revokes the pending object and its credential continuation even if the old live SDK registration is already nil. Returning to an earlier-looking source cannot restore a revoked witness.

The old owner revokes/cancels synchronously. Reopening occurs only from the actual old sheet dismissal, qualified by its captured session UUID, with no replacement sheet while the old presentation remains owned. A late binding/dismiss callback from another sheet cannot consume the current continuation. The issuer requires the exact registered consent object and consumes it once. It creates a new SDK session/generation for the same saved conversation UUID and namespace.

Only after the new exact sheet mounts does the owner configure the unchanged SDK with the original immutable connection request. Until the matching configuration UUID is activated, the host refuses the granted binding. A different configuration cannot reuse the grant. A granted configuration failure closes the session. Grant/revoke alone does not invoke Send; the original consumer still requires the user's explicit message action.

End book access synchronously revokes/cancels and reopens the same saved conversation without a key or read grant. Closing, source/account/profile/group/session/foreground changes and native context transitions revoke the current authority. Consent is not stored with conversation history and does not follow history selection or navigation. The original scoped filesystem store, draft serialization, rich message payloads and SDK metadata ownership are unchanged.

## Core/Host seam

The optional `OtzariaHanlinBinding.searchExecutionContext` is selected only by the adapter's fixed `search.query` mapping. Request arguments cannot choose a context. The original metadata/navigation context remains unchanged; its three reads are `system.listBackends`, `catalog.resolveWork` and `catalog.resolveReference`.

The separate content context retains the existing `discovery` scope alongside explicit `contentRead`, Otzaria content rights and exactly one allowed work key. It has no navigation scope. Original Core advertisement first executes `system.listBackends`, which requires discovery; the actual 38-pass/10-fail execution exposed this requirement. It shares the original subject, correlation budget, origin, backend and foreground scene. Its upper bounds are 20 Core actions in the shared correlation and 32,768 result bytes; the existing Core request deadline and search schema bounds remain in force. Catalog discovery and invocation use this same trusted context and the unchanged original Core policy/readiness checks. Search is not advertised if Core cannot support it.

The adapter rechecks its full authority after Core awaits; revoked/stale results are not published. The original cancellation path reaches the Core task. The original SDK HostDispatcher consumes the scoped tool contract without a fork or SDK modification. Model instructions include the canonical work reference as encoded data, not an interpolated book title.

This enables a bounded read-only consumer path. It does not add App Intents, UI mutation tools, notes/search-results/commentary actions, corpus-wide grants, selections, or occurrence-count support.

## Verification declared and evidence boundaries

The host source declares 48 cases: all 28 original names plus 20 additions. New cases cover exact scope, default denial, omitted/broad/foreign scope, missing rights/readiness, argument authority injection, metadata compatibility, result scope validation, cancellation, in-flight revocation, original SDK dispatcher/invalidation, exact consent consumption, superseded dismissal, changed source/configuration/namespace and replay denial. These use the actual original Core/adapter/SDK dispatcher with explicitly identified native-source/backend/authority doubles. They do not instantiate UIKit, the app owner, AgentSession or a provider.

The filesystem store source retains its 11 original case names. Its existing reopen test additionally rotates the real scoped lease/session while preserving the same conversation UUID, rich history, draft and original SDK metadata, verifies unchanged file bytes after reading, and rejects writes through the revoked old lease. It uses the complete original production store and actual Foundation files.

Preserved unsuccessful attempts:

| Attempt | Actual outcome |
| --- | --- |
| Host job `job_4fa9d7562154` | 240-second compilation timeout; 46 declared then, 0 executed |
| Host job `job_c858343af37e` | 240-second compilation timeout; current 48 declared, 0 executed |
| Host continuation preflight `job_88bd2c6b000f` | Windows source-path comparison assertion before Swift; 0 executed. All 62 package inputs were subsequently compared byte-for-byte with the current sources and original SDK and matched. |
| Store job `job_b1598c8df7e0` | 300-second compilation timeout after generated XCTest discovery; 11 declared, 0 executed |

No timeout or declaration is a passing test. Continuation job `job_a58d37322a97` uses the exact unchanged prepared packages and commands sequentially with a finite 600-second bound per suite, fresh logs, the original strict XCTest verifier and before/after byte comparisons. Results belong in the evidence follow-up.

The recorded Windows frontend parses target `arm64-apple-ios27.0-simulator` syntactically only. They do not load/typecheck Apple frameworks and are not Apple build evidence. The source snapshot in `SOURCE_INPUTS.json` identifies the actual eight files. `git diff --check` passed and the original SDK tracked tree was clean at that observation.

## Native cases prepared, not executed

The two original Native case names and their behavior assertions remain; the old explanatory-text assertion now checks the real default-OFF wording/toggle. Two new cases use the original `R27NativeUIBase` `.realUI` launch tier:

- `HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending`
- `HanlinReaderConsumerAcceptanceTests/testOriginalPhoneCurrentWorkReadConsentReopensAndRevokesWithoutSending`

They select the original iPad reader and phone global entry respectively, verify the source fixture title, use the real original configuration path, preserve a multiline Hebrew draft and the exact saved conversation UUID across the actual grant/dismiss/reopen/revoke flow, and check the unchanged native reader locator/text/workspace afterward. Neither taps Send. They do not instrument network silence or assert provider authentication.

Both cases are NOT_RUN and require registration in the next source freeze on their declared device destinations. The existing immutable Native88/Release source/run is separate and cannot validate this later source.

## Remaining gates

1. Actual passing exact-source portable executions, with no failed/missing case, must be recorded.
2. Apple SDK typecheck/build of the full original app and combined Core/Host/SDK regressions.
3. The two original Native consent cases on iPad and phone, plus existing consumer/navigation/draft regressions. SwiftUI closure selection and actual presentation timing remain an Apple/Native observation.
4. A configured real-provider invocation and the original live Otzaria backend search, with bounded scope, cancellation and no stale excerpts, remain unexecuted. No test fixture makes an external model request.
5. Physical-device latency, backgrounding/account transitions and accessibility/RTL interaction remain unverified by these portable fixtures.

The root integration owner controls source freezing, Native selections and Asana status. This branch must not turn declared or historical coverage into current Native/provider acceptance.
