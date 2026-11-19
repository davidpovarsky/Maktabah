# Hanlin navigation context transition — reproducible upstream requirement

## Current original SDK

Consumed Hanlin SDK: 080d1a2b264ead9e3f9df690f2dd0d3e81ebd07e. Current upstream integration reviewed at ae3948f27710888c19b0e0dfe9baa01db2b21452 (2026-11-19 01:28 UTC).

The whole original HostDispatcher and HostIntegration contract are byte-identical at those revisions:
- HostDispatcher.swift: bb4a4c7c97559687f6a2d739f5f1e2d2f779a4a6c7d6f0c4a1f6a8d64b2a3e7f
- HanlinHostIntegration.swift: 5058e0e331612aa8d9eba2372f77530947719156efc7c8c40c0bee98144df7bf

The newer upstream package change since the prior review is in the original Chat UI editor, not this navigation contract. The consumed SDK's existing ZIPFoundation compatibility pin remains the separate previously recorded change.

## Reproduction, not feature acceptance

`tools/hq-hanlin-navigation-transition.py` copies 28 complete original source/resource files from the immutable SDK git object: all Platform/Host contracts and the WHOLE unchanged HostDispatcher. The fixture supplies an explicitly synthetic host with counted navigation effects; it does not replace the dispatcher, AgentSession or the application.

Eight XCTest assertions pass using Swift 6.3.3/strict concurrency (48 compiler warnings are retained in the original log):
1. Stable-context presentation preserves the exact acknowledgement.
2. Queued is not presentation.
3. A host generation change after navigation causes staleContext, after one effect.
4. A changed original content object after navigation likewise causes staleContext.
5. Account transition remains rejected.
6. Replying with the new context instead fails resultMismatch.
7. A context already stale before invocation produces zero navigation effects.
8. Revocation before invocation produces zero navigation effects.

These passing assertions reproduce a current contract limitation. They are zero Native/UI/provider/model acceptance. RESULT.json and INPUTS.json record exact input hashes and boundaries; the existing Apple SDK job also executes the fixture.

## Integration consequence and required upstream capability

HostDispatcher.open first checks the session, awaits the host, validates the reply against the ORIGINAL requested context, then requires the ORIGINAL session context to remain current. Real Otzaria Reader navigation can legitimately change the original workspace mapping epoch/content owner. Its existing Hanlin registration is correctly invalidated when that source changes.

Therefore a caller cannot return a successful acknowledged cross-content transition through the current original SDK contract: the old context becomes stale after the effect, and a new reply context is rejected. Otzaria currently refuses this variant BEFORE mutation with `hanlin_content_context_transition_not_installed`.

A reviewed original SDK transition contract must correlate the original request, native effect and resulting context while retaining exact namespace/account/scene ownership, cancellation, revocation and last-boundary checks. It must distinguish a legitimate navigation transition from unrelated authority changes. Do not remove the post-await guard, reuse an invalid registration, fake a stable context or treat queued as completion.

This requirement is upstream task 1220542199992529 and Otzaria UI06 task 1220542467495722. No SDK engine/permission/store fork is created here.

## Independent host work still open

The SDK already provides the original Chat UI/composer, AgentSession/engine and private conversation store. Missing production Otzaria UI composition and provider configuration are host integration work, not proof that the SDK lacks them. HanlinCredentialResolver explicitly leaves Keychain/entitlement choice to the host. No credentials were read, transferred or logged by this reproduction.

The Apple on-device provider advertises no tool support, so it cannot alone satisfy the three required model-to-ActionCore/UI journeys. Production lifecycle, credential delivery, content rights, original SDK UI composition and genuine model/native acceptance remain open. UI-only roots/panel can be evaluated independently where the original context stays valid.
