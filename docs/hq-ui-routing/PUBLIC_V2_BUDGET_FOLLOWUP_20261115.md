# Public navigation v2: normalized byte budget and reader-plan regressions

Separate follow-up to frozen public-v2 packet `9835982a8bb629965c925337d4dcb94c941f678b`; no native checkout/run is repinned by P.

The v2 decoder previously checked the incoming JSON's 4096-byte budget, then inferred a missing top-level backend from content. A Unicode reference near the boundary decoded successfully although its normalized representation exceeded 4096 bytes and could not subsequently be encoded/bound. This was an inconsistent acceptance boundary, not an authorization bypass. The new regression executed against the original production codec: **1 XCTest / 1 expected assertion failure** (`XCTAssertThrowsError` did not throw). The raw log is `results/public-v2-budget-before.log`. An earlier test-only throwing-expression compile error executed zero tests; its log is preserved separately.

`decodePublicV2` now checks the sorted JSON encoding of the validated, normalized DTO against the same budget before returning it. The existing encoder budget guard remains. The regression now passes and also checks that the adjacent smaller normalized intent can decode, encode and decode unchanged. No schema, DTO, registry, native API or v1 behavior is changed by this production fix.

Two additional regressions exercise the retained structural reader plan through actual canonical Core execution, for all three synthetic backends:

- The exact host assessment permits the variant and backend content rights, but the canonical context allows only a different work. Binding produces only a structural plan; `reader.open` refuses with `permission_denied` before the resolver or sink, with zero effects.
- Generation changes after binding. Core executes against the newer generation and reaches its actual resolver/sink. Constructing the command from the retained route plus the actual Core invocation and fresh scene refuses `backend_generation_changed`; the test host translates that refusal into the existing Core stale-state port error. No retained expectation is refreshed or silently rebound; zero effects occur.

The final affected-package run executed **75 distinct XCTest methods / 0 failures / 0 compiler warnings**, including 17 v2 methods (the prior 14 plus these 3). The prior 72, focused 1/0 and red 1/1 are not added to that count. Swift 6.3.3 on Windows validates portable Swift only; fixtures are synthetic host/native authorities. Native, real public URL import/publishing, physical behavior and shareability acceptance remain open/NOT_RUN by P.

Only two downstream UIRouting Swift files changed from `9835982a`: the v2 codec and v2 tests. Core, Resolver, Bridge, Reader, manifests, current native handler, upstream UI, workflows, signing and gates remain unchanged. Old public/private goldens and v1 codec/schema/migration sources retain their exact Git blob identities. The original 50-input proof is retained unchanged; current working byte hashes, Git blobs, all retained new raw logs, final 75 method names and unchanged-source checks are recorded separately in `results/public-v2-followup-summary.json`. Working-byte hashes and Git-normalized blob hashes are deliberately separate.
