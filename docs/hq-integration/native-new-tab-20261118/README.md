# Native new-tab continuation — source review

Status: source implemented; actual app/SDK compile and Native scenarios pending. This is one developer's review, not independent QA.

## Original ownership and authority

The existing R scene adapter reserves an actual original ReaderTab and ReaderViewModel without loading, selecting or persisting content. The reservation advances R's mapping epoch before N issues the request's original Core admission. It is mapping data, not a permission.

Only Core's original one-use grant can reach the existing synchronous native presenter. The R policy accepts precisely two actual setter publications: append that reserved tab, then select that same tab. It compares both expected willSet transitions and actual didSet getters. Unrelated tab, owner, backend, workspace, selection or ABA transitions revoke the original context. Reads fail closed during publication.

The original linked-source new-tab presenter is shared rather than duplicated. It saves the previous reader state and loads the original ReaderViewModel. The saved workspace keeps every foreign-backend document. Only its exact normal checkpoint for the already committed native reservation preserves the native epoch; arbitrary store transactions retain their original invalidation.

N retains the same tab, scene owner, Core context and binding through Core's final completion checks. The existing TextKit witness must independently observe the exact rendered section and focused segment. The native receipt records newTab only while R proves actual committed creation of that selected original tab. Cancellation or an uncertain partial effect never deletes a tab or reverts user work.

## Verification boundaries

- Original Foundation reservation policy: 16 scenarios /47 assertions PASS on Windows Swift6 strict concurrency; synthetic owner/projection inputs, Native UI0.
- Actual changed Swift source parses for the iOS27 simulator target on Windows. This is syntax only, not Apple SDK type checking.
- Frozen ActionCore, P/UIRouting and host-package authority/orchestrator source remain unchanged.
- The original R27 interaction and Sidebar acceptance source is byte-identical after line-ending normalization.
- Two new actual Native methods are registered in the existing matrix, taking it from48 to50. Both remain NOT_RUN.
- They require a real system URL in the same app PID, independently sealed miniTest10 DB metadata, actual TextKit locator/highlight/title, one full-Core receipt, exactly one new persisted tab, all previous identities retained and return via the original native tab control.
- The original sameTab cross-book refusal remains required.

## Remaining scope

This change does not certify phone content routes, rich components/TOC/Inspector routes, Siri voice, physical-device behavior, Hanlin consumer acceptance, provider-compatible Books Updates, or release readiness. Full app compile and the real Native results are required before accepting this feature.
