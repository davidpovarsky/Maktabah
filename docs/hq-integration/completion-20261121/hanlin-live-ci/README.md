# Original Hanlin live consumer route

Application/test source: `2818019c7dcecda953c74caa4f38823fb97cf70f`. CI integration base: `04bb2a540e9843e80e26b50f4fcd37b73481f0a1`. This change adds only CI tooling and evidence. Native116 and Release114 catalogs and their assertions are unchanged.

The dedicated workflow builds the original app/UI runner once with the existing stage2 builder and compiler cache. Its sole selector is `HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent`. That original-app journey uses native Connect and book-read consent, the original SDK/AgentSession, actual canonical Core search/reference tools, the visible source receipt, native revoke/reopen and Open source, then checks the original Reader receipt, locator, text and workspace preservation.

## Provider configuration

The reviewed CI model is `gemini-2.5-flash-lite` at the fixed official OpenAI-compatible endpoint `https://generativelanguage.googleapis.com/v1beta/openai/`. The application accepts a bounded public Gemini model ID; it does not embed this CI model choice.

One authorized read-only ListModels request returned HTTP200 and this candidate with generateContent/countTokens support. This metadata is not generation or tool-continuation acceptance. Google currently documents the model as not deprecated but available to existing users. The pinned SwiftAI producer's OpenAICompatible v3 contract omits tool-call provider metadata; Gemini3/4 require thought signatures for function-call continuations, so those models were not selected for this unchanged SDK route.

Primary references:

- https://aistudio.google.com/docs/openai
- https://aistudio.google.com/docs/models/gemini-2.5-flash-lite
- https://aistudio.google.com/docs/deprecations#gemini-2.5-flash-models
- https://aistudio.google.com/docs/thought-signatures?generate-content=true

## Private input and evidence

The workflow references only the dedicated temporary Actions secret name `OTZARIA_LIVE_GEMINI_API_KEY`. Provisioning/removal remains an explicitly owned operational step; this commit contains no credential. The value enters only the live step, is removed from the process environment before any child starts, and is written once with mode0600 inside the newly owned Simulator's app data. XCTest receives only public configuration and nonce. The existing native form consumes the file before displaying its original Connect flow. No credential is typed by XCTest, put in app launch environment/arguments or printed.

Cleanup attempts private-file removal, owned Simulator shutdown/deletion and original-evidence restoration independently. It verifies removal and retains errors. A second cleanup cannot turn an originally unconsumed input into a consumed result. The original job evidence directory is temporarily moved and restored with byte hashes and directory identity checked, including interrupted paths.

Only the allowlisted evidence directory is uploaded after an in-memory raw/base64 credential scan and successful final cleanup. It contains original xcresult summary/tests/test-details and strict verifier outcomes, the original native witness, exact source/binary identities, and independently derived miniature-fixture hashes/query. Raw app data, private input, raw xcresult bundles, attachments and video are excluded. Compiler cache save precedes credential delivery; no cache is saved afterward.

## Verification performed

`LIVE_RUNNER_CONTROLS.json` records eighteen disposable Linux controls using an explicit public dummy string. They include unsafe evidence rejection, ownership and cleanup failures, evidence byte restoration, repeated-cleanup state and a syntax-tree comparison proving the default matrix is identical when the optional live hook is absent. Original log verification and xcresult zero-skip verification remain mandatory. Python syntax checks passed. The repository reproduction script is `tools/verify-hanlin-live-runner-controls.py`; its path adjustments do not change the tested control bodies.

These controls executed zero Native tests and zero provider requests. A live acceptance PASS requires the dedicated workflow's actual one-case execution, original verifiers, native witness, unchanged source/binaries/database and verified cleanup. The workflow is intentionally separate from the full Native116/Release114 routes. Its push trigger is limited to `codex/otzaria-hanlin-live-20261121`; the preparation branch is different and is not pushed by this commit.
