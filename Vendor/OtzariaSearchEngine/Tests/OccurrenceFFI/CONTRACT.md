# Original-engine occurrence C bridge, contract v1

This component calls the bounded exact-token primitive in the original engine
fork at d5d59d1269bdf87fb0a6901cf31941726a0c699b. Its documented upstream base is
265a14ea54f959a3e266d6e8acfa3a3b98101d68. Search/query normalization, indexed
positions, facet semantics and live-document filtering remain in that engine.

The Maktabah application and index policy are not connected to this API by this
tranche. A component test is not an application, artifact compatibility, Apple
SDK, Native, or full corpus acceptance result.

## Additive C API

| Function | Ownership and result |
| --- | --- |
| otzaria_search_engine_occurrence_request_new | Copies a length-delimited JSON input into a validated request. Returns a nonzero process-local uint64 token, or zero plus typed error JSON. |
| otzaria_search_engine_occurrence_request_cancel | Signals the request's one-way shared cancellation token. It never acquires the engine mutex. Unknown/released tokens return false. |
| otzaria_search_engine_occurrence_request_release | Removes the token and cancels any in-flight retained Arc. Double/unknown release returns false without dereferencing a freed pointer. |
| otzaria_search_engine_count_occurrences_json | Executes a request once against a genuine live EngineHandle and returns owned JSON. The caller runs it on a worker thread. |

The input pointer must be readable for exactly request_length bytes for the
duration of new(). A NUL terminator is unnecessary; embedded NUL is invalid JSON.
The output error slot must be writable or null. All returned JSON strings are
freed exactly once through the existing otzaria_search_engine_free_string.

Request tokens are IDs, not memory addresses. They are never reused or wrapped
within the process, and must not be persisted across process launches. Execute
uses a one-use CAS, including failed execution. A fresh request is required for
a new invocation.

The existing EngineHandle ownership contract is preserved: the caller keeps the
genuine handle alive until execute returns, and must cancel/join before
engine_free. This new request registry does not make arbitrary or prematurely
freed engine pointers valid. cancel and release of the new request token may
race safely with an executing call.

## Strict request

Required input:

    {"version":1,"mode":"exact","query":"משה","timeoutMs":5000}

Optional fields:

- facets: raw original-engine facet strings, default ["/"].
- bookIds: original unsigned book IDs, resolved through the existing bridge's
  original /book facet adapter.
- limits: maxCandidateDocuments, maxPositions, maxPositionsPerDocument,
  maxSegments; missing fields use the original primitive's finite defaults.

Unknown fields are rejected. Version 1 and mode "exact" are required. The
original analyzer must produce exactly one token; empty/multiple-token input
returns unsupported_query. There is no phrase, regex, fuzzy, morphological,
vocalization-specific, semantic, grouping, paging, or negative-query fallback.

"Exact" refers to the original mark-free indexed-token semantics, including its
normalization. Distinct indexed positions are counted. Two occurrences in one
document count as two; duplicate stacked positions count once. Matching
documents are reported separately and never substituted for occurrence count.

## Resource, deadline and cancellation contract

Input JSON is at most 512 KiB. A query is at most 1000 Unicode scalar characters.
At most 200 supplied facets and 200 book IDs are accepted, and the resolved
facet set is at most 200 entries. Each facet is nonempty and at most 512 scalars.

There are at most 64 live request reservations. The reservation follows the
final Request/Arc lifetime, including a released request that is still returning
from engine work. Releasing an in-flight token does not prematurely reopen its
capacity slot. The maximum retained request-input envelope is 64 times 512 KiB;
this is not a claim about total process memory or caller-owned response buffers.
The response envelope is capped at 1 MiB.

Original primitive limits are retained:

| Limit | Default | Hard maximum |
| --- | ---: | ---: |
| Candidate postings visited | 100000 | 1000000 |
| Raw positions inspected | 1000000 | 10000000 |
| Raw positions per document | 65536 | 262144 |
| Segments | 1024 | 4096 |
| Total timeout, milliseconds | caller required | 60000 |

timeoutMs may be zero, which produces an already-expired request. The monotonic
deadline is captured at new() entry and includes parsing, scheduling and time
before execute. No lock acquisition or retry restarts it.

Execution uses the existing engine mutex through try_lock. Contention waits
are at most 1 ms each, capped by remaining time, with cancellation/deadline
checks on every iteration and again after acquisition. Registry guards cover
bounded metadata operations only; they never cover engine work, waits or JSON
serialization. Cancel/release cannot wait behind the engine mutex.

The exact original control/cancellation token is passed to the primitive.
Checks also run after the count and after success serialization. A cancelled
or expired result is discarded, including its already-serialized scalar.
Cancellation is cooperative, not a hard real-time interrupt of a synchronous
Tantivy operation already executing.

Success linearizes at the final cancellation/deadline check. A later cancel
cannot retroactively revoke a response already returned. The host still
revalidates its invocation/source witness after awaiting the call.

## Success proof

The value contains occurrences and matchingLiveDocuments separately. Proof
contains requestToken, countKind=distinctTokenPositions, exact=true, the original
analyzed token and sorted/deduplicated requested facets, the actual held
Searcher generation ID and segment UUID/delete-opstamp map, that snapshot's live
document count, original schema/package version, actual compiled fork commit,
repository and branch, and the recorded original upstream base.

Work records visited candidate documents, inspected raw positions and segments.
These diagnostics are not alternate occurrence results.

The proof is exact for the held index snapshot. It does not establish that an
application database, catalogue, edition or installed corpus is complete. The
host must bind it to actual source/database/index identity, profile, invocation,
deadline and publication revision before exposing a capability or numeric result.

The isolated pin/build provenance reports d5 as the actual owned-fork source.
It must never label this binary as the original 265 source, silently accept an
old source artifact, or relax an application's existing exact compatibility
guards. Apple artifact and application policy integration are separate gates.

## Typed failures

Every failure has ok=false, value=null, and error with code/message. No partial
occurrence scalar or lower-bound success exists.

Codes include invalid_request, request_too_large, unsupported_query,
invalid_limits, request_capacity, request_id_exhausted, unknown_request,
request_already_executed, invalid_engine, engine_unavailable, cancelled,
deadline_exceeded, budget_exceeded, positions_unavailable, invalid_positions,
count_overflow, engine_error, response_too_large, and internal_error.

Unsupported/malformed data, an unavailable engine, panic, cancellation,
deadline, capacity exhaustion or incomplete work can never become exact zero.

## Test boundary

Focused Rust cases invoke the actual C exports and original engine in TempDir
indexes. They compare two token positions with the unchanged old search's one
matching document, verify original facets/deletions/normalization, and exercise
real mutex contention and request lifetime. A private cfg(test) scheduling hook
runs only after a real count has completed and been serialized; it cannot replace
a provider, query, result or proof. It makes the final cancellation/expiry race
deterministic.

Held-lock test workers retain a Rust borrow of their fixture owner. Their Drop
releases only the fixture's held mutex and joins the worker on every failure
path, so a test timeout cannot free a still-used C engine pointer.

The existing 12 bridge regressions retain their original assertions and owned
temporary indexes, including the 1024-book lifecycle case. The old four
user-path engine diagnostics are never selected. Runtime results and exact
source hashes are recorded separately; a dependency/compile failure is not a
test pass.
