# Focused authority-lifetime review

Reviewed source: `bbd3605ac4b501e442fdfa6dfdc3ca2dd0f4ad16`. This is source review, not UIKit, provider or physical-device execution.

## Independent review

The parallel Actions owner reviewed the actual Composition, ChatOwner and ChatView changes read-only. The review included `closeHanlinHostSession` and `hanlinRegistration`, and reported no blocking source defect. It confirmed these ownership relationships:

| Boundary | Source behavior |
| --- | --- |
| Close before actual dismissal | The old SDK registration is removed; the same scene-owned pending consent remains intentionally retained. |
| Source/foreground invalidation in that interval | `invalidateHanlin` clears active and pending associations first, revokes the pending witness even without a live SDK registration, and tells the old owner to discard its pending reopen/connection. |
| Issue after dismissal | The exact registered consent object, original session/conversation/scene/configuration and current source/namespace must match; the witness is single-use. |
| Late sheet callback | Binding setters and onDismiss capture the presentation UUID; owner callbacks reject a different UUID, and onDismiss also requires the current presentation to be dismissing. |
| Granted SDK activation | `current()` requires the original required configuration UUID to match the locally activated immutable request. |

No new authority comes from the publication license, title, current selection, a model field or a test-only callback. The original native reader/profile/group/backend ownership remains the issuer's source.

## A → B → A, old callbacks and permission effects

A pending token created in source A cannot survive the original invalidation path through B, even if the visible source later resembles A. The scene association is cleared and the token's availability is permanently revoked. Source equality is an additional consumption check, not the revocation mechanism. The portable token fixtures separately execute revoked consumption and reject an A witness after a failed B observation is followed by A again. Those fixtures use explicitly declared source doubles; they do not prove native observation delivery.

A callback for old sheet A is rejected when current sheet B is either visible or itself dismissing. Rejecting it does not call the current scene's finish method or consume B's continuation. Repeated callbacks after A has already retired fail the same owner/session guard. The portable one-use and foreign-dismissal fixtures exercise the underlying witness. Actual SwiftUI closure selection and UIKit animation ordering remain Native gates.

The Grant path calls native consent creation and the original close/reopen path. The Revoke path cancels/retires and reopens without the configuration. Neither calls the consumer's `send()` or SDK `stream()`. The pinned original SDK Engine initializer resolves a provider locally, AgentSession initializer stores its identity/host/engine/store and creates the original dispatcher, and `makeFetch` returns the closure that performs a URLSession request only when invoked. This is a source-level call-path finding. No network observer was installed and no runtime claim of network silence is made.

The immutable original SDK `HanlinChatModelConfiguration` is retained in one transient request with a new UUID; its endpoint/model/key cannot be edited in place. A granted session refuses a different UUID. The key is not hashed, logged, saved with the consent or restored from history. Changing the model connection requires retirement/reconnection, and the native grant must be given again.

## Read-only source references

- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift`: Registration.pendingHanlinReadConsent, HanlinReadConsent, issueHanlinHostSession, makeHanlinCurrentWorkReadConsent, hanlinConnectionConfigured, requireHanlinReadConnection, invalidateHanlin, closeHanlinHostSession.
- `Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatOwner.swift`: ReadReopen, requestReadConnection, endCurrentWorkReadAccess, requestClose, didDismiss, didMount.
- `Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatView.swift`: original presentation modifier's captured dismissedSessionID and native default-OFF connection form.
- `Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift`: immutable OtzariaHanlinConnectionRequest, configure overloads, requireCurrent and explicit send.
- SDK `e00498e33f106cc43be0476ffa2e09329c8ca300`: original HanlinAISDKAgentEngine.init, HanlinAISDKProviderFactory.resolve/makeFetch, HanlinAgentSession.init.

## Actual RED that source review did not detect

The first complete portable execution ran all 48 cases: 38 passed and 10 failed. All 28 original cases passed. The ten failures shared absence of the search descriptor. Original Core advertisement first executes the discovery action system.listBackends, so the new separate context must retain the existing discovery scope alongside explicit contentRead. This is a real integration correction, not a reason to weaken the positive catalog/dispatch assertions or content-rights denial tests. Its exact-source GREEN must be recorded before integration.

The Apple typecheck script already includes the entire Native test source and hashes its bytes. It also invokes the original host and filesystem-store drivers. The two new device-specific Native selections still require the next root-owned freeze; no current immutable run can cover this later source.
