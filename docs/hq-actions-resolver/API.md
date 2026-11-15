# Source-backed semantic resolver

[נועם | DEV] [MAIN_SESSION] — 2026-11-15

`CatalogActionResolver` is a public actor conforming to the frozen `ActionResolverPort`. Construct it with existing `ActionResolverDataPort` and `ActionBackendStatePort` implementations. There is no singleton, UI/backend switch, second search engine, persisted alias store or parallel catalog index. Temporary identity sets exist only for one invocation's source catalog snapshot.

```swift
let resolver = CatalogActionResolver(data: dataPort, state: backendStatePort)
let work = try await resolver.resolveWork(query, invocation: invocation)
let reference = try await resolver.resolveReference(referenceQuery, invocation: invocation)
let exactDestination = try await resolver.validateDestination(destination, invocation: invocation)
```

## Matching and identity

- Work matching uses source-owned titles, aliases or exact work keys. Name normalization is NFC, whitespace collapse and explicit geresh/curly-quote equivalents. It preserves case and nikud. No transliteration, morphology, fuzzy guesses or natural-language planner is added.
- Work refs include the canonical backend and source work key, plus any supplied catalog revision. Otzaria keys must have the canonical nonnegative `book:<integer>` form. Position kinds are backend-specific: Otzaria nonnegative legacyLine; Sefaria/Embedded nonempty canonicalRef. No numeric surrogate identity or line arithmetic is introduced.
- `query` plus `workRef` must agree with the source catalog; an explicit work cannot silently override contradictory title/alias text. A reference query's text and section are forwarded unchanged to the source parser. Its returned identities must agree with every supplied backend/work/revision. The parser must honor the entire supplied query; the resolver is not a second reference grammar.
- The complete bounded catalog is scanned before declaring a match unique. Duplicate identical qualified identities are deduplicated; distinct work/edition/revision identities stay ambiguous. `limit=1` caps candidate output, never changes `.ambiguous` into `.unique`. Ordering compares identity components, not concatenated strings with collision-prone delimiters.
- Ambiguous work candidates retain source title/kind/provenance and exact/alias confidence. Normalization in `reason` names the profile, not a claim that every transformation changed the input. Sources must provide public-safe provenance identifiers, not credentials/private filesystem paths.
- Every distinct unique/ambiguous reference is checked against the catalog and then `data.validate`. Identical full qualified refs share that existence proof only within one invocation; different catalog/data revisions stay distinct. An identical section/focus pair uses one proof and returns the original pair. No proof is cached across invocations. Destinations validate the exact supplied section and focus and return the original destination without substitution. The pair must share backend/work and compatible explicit revisions. No additional containment relationship is inferred from line numbers or canonical string prefixes.

## Source contracts and errors

`data.validate` is an authoritative existence check against actual source catalog and section/segment data and must return the exact supplied `ActionTextRef`, including optional revisions. Trimming an unknown Embedded string and echoing it is not a conforming implementation. The resolver cannot independently establish DB/RPC existence from an equal string; production source proof is the separate Integration owner's responsibility. Source-shaped fixture acceptance does not establish production proof.

- Verified no work/reference: `.notFound`. A source unique candidate failing existence validation becomes `.notFound`; a broken member in an asserted ambiguity is an invalid response, not a silently omitted match.
- Unavailable assets/network/runtime or failed RPC: throw a typed port error, not an empty catalog or `.notFound`.
- Caller malformed/cross-backend arguments: `ActionContractError.invalid` before data calls where detectable from typed input. Contradictory source identities, malformed catalogs/candidates, source substitution and resource overflows: `ActionPortError.invalidResponse`.
- Existing typed source errors propagate; unknown provider errors become `.unavailable` without raw error/SQL/path text. Cancellation/deadline throws `CancellationError`; snapshot drift throws `.staleState`.
- An invocation must already target its snapshot backend; the executor remains responsible for the public `requires_backend_switch` policy. Embedded requires a known RPC epoch. The resolver never switches backends.

## Resource and concurrency boundaries

Default hard ceilings: 100,000 catalog records, 32 MiB aggregate catalog names/keys/provenance/revisions/aliases, 64 aliases per record, 512 characters and 8 UTF-8 bytes per character budget for catalog names/keys, 1,000 characters for reference text, 500 for section input, and 128 for revisions. Candidate input is capped at 256 and output at 25. Constructor configuration can lower entry/candidate ceilings, not raise the hard maximum. Oversized data fails rather than being searched partially.

The actor checks cancellation/deadline during scans, yields and rechecks backend generation/RPC epoch at bounded intervals, and checks snapshots before/after every provider await, including failed calls. Work candidate retention is bounded to the requested output cap while counting all distinct matches. Catalog identity membership is O(1) after the bounded per-invocation snapshot validation. Reference candidate validation is sequential and bounded; a cap never skips proof for distinct candidates outside the returned page. Duplicate candidate payloads still undergo full shape, catalog, title and reason validation before proof deduplication, and source ambiguity is never promoted to uniqueness.

Limits cover resolver-owned work. The current data API returns a complete catalog array, so its provider controls acquisition/allocation and must offload expensive work appropriately. Cancellation/deadline is cooperative; the resolver cannot forcibly interrupt a noncooperating provider before its await returns. No MainActor app/SQLite/RPC performance claim is made by this portable package.
