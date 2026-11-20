# Original-engine exact single-token occurrences

Published owner-controlled fork:
https://github.com/davidpovarsky/otzaria_search_engine/tree/d5d59d1269bdf87fb0a6901cf31941726a0c699b

Original upstream remains Otzaria/otzaria_search_engine at base
265a14ea54f959a3e266d6e8acfa3a3b98101d68. No commit was pushed there and its
origin remote was not replaced. The fork preserves the original MIT license.
The additive primitive is fffd346555d4c4a0e487b30619aa79253b2372c3; explicit
disposable-fixture test hygiene is d5d59d1269bdf87fb0a6901cf31941726a0c699b.
Remote branch SHA and the clean source checkout were verified after publication.

## Reviewed behavior and executed proof

The original Hebrew query analyzer, exact query and facet semantics are retained.
A held Tantivy Searcher supplies complete indexed positions and live-document
membership. Distinct positions count repeated occurrences without treating
document hits, merged rows or bounded snippets as occurrences. The proof includes
the real segment/delete snapshot, normalized token, original facets and schema.
All numeric work is bounded with checked arithmetic and a monotonic deadline;
cancellation or incomplete/unsupported work returns a typed error without an
exact numeric value. Synchronous Tantivy operations are cooperatively checked
around calls, not preempted. Supported scope is exactly one analyzed token,
with the original mark-free exact semantics. Other modes remain unsupported.

The deliberate baseline counterexample returned one matching document containing
two copies of the token. Expecting an occurrence count of two failed; the original
document-count API was behaving according to its own contract.

Actual new focused tests: 19 PASS. Original default suite attempt: 360 PASS,
4 FAIL, preserved as that historical result. After separate fixture hygiene:
360 PASS, 0 FAIL, 4 ignored; the same 19 new cases are INCLUDED in those 360.
A separate repeat of the 19 passed. Eight filesystem fixture-guard checks passed
without linking/opening an engine. These totals are not additive independent
engine acceptance counts.

The four original diagnostics addressed an ambient user-index path; failures
occurred at the schema mismatch before writer creation. Their exact call trace,
original failure logs and after-only filesystem observation are retained in the
fork. There is no pre-run snapshot or byte-equality/no-touch claim. They now
require an explicitly owned disposable temporary fixture and opt-in execution.
They remain ignored/NOT_RUN, never counted as passes. No subsequent user-index
reopen, schema repair or reindex occurred.

Root independently reviewed the primitive, its original exact-query hook and
tests, plus the separate diagnostic guard. Complete evidence and contract:
https://github.com/davidpovarsky/otzaria_search_engine/tree/d5d59d1269bdf87fb0a6901cf31941726a0c699b/docs/exact-occurrences-20261120

## Integration still in progress

The Maktabah pin, original indexed data, artifact policy, C/Swift/Core surface and
capability advertisement are unchanged by this publication. The existing index
and artifact policy requires exact engine commit identity; a new fork pin cannot
be silently substituted for the current prebuilt v32 source. A reviewed bridge,
genuine Apple build, source/coverage witness and compatible artifact validation
remain necessary. Work on the bounded C bridge is a separate isolated tranche.

No app occurrence capability, full-corpus count, Apple XCFramework, Native UI,
model/provider journey or physical result is claimed by these Rust tests.
