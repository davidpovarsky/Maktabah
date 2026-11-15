# G1 portable action engine — scoped handoff

[נועם | DEV] [MAIN_SESSION],2026-11-15. Primary Desktop UUID `01a1dc89-87bb-7521-b249-ed383392e940`; source GID `1219614315863536`; HQ activation `1220541793847728`.

Worktree `C:\Users\DAVID\Code\Maktabah-hq-actions-core-20261115`, branch `codex/otzaria-actions-core-20261115`, base `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5`. Initial API checkpoint `3d6f90c90403a18e780ca37504da1c71285b219e` compiled with two DTO tests. The G1 implementation SHA is the commit containing this report, recorded exactly in authorized source-task notes. No merge/push occurred.

## Implemented behavior

- A dependency-free Swift6 package, public Codable/Sendable contracts, immutable29-descriptor registry and one executor actor. The initial five operations execute through injected ports: `system.listBackends`, `catalog.resolveWork`, `catalog.resolveReference`, `search.query`, `reader.open`. All three canonical backends are equal targets; no source substitution or automatic selection occurs.
- Strict bounded raw JSON parser rejects duplicate decoded keys, including escapes, unknown envelope/descriptor keys, invalid types, sizes, depth/nodes and semantic position errors. All explicit backend references agree before any provider call. Focus and section share the exact work/backend.
- D's API-02 exact-number finding is addressed before Foundation coercion: decimal/exponent grammar is classified mathematically, exact integral forms stay Int64/UInt64, fractional/underflow/overflow cannot round into version/generation/paging integers. The original argument tree is retained in the single DTO rather than round-tripped before descriptor validation.
- Caller bytes cannot construct context. Subject/scopes/corpus rights/allowed works/origin/device/scene/budgets come from trusted non-Codable context. Deep-link content search is refused; unpaired MCP is unavailable; absent rights fail before data execution.
- Snapshot backend+generation+Embedded RPC epoch is rechecked after awaits and before UI. Each provider receives the pinned invocation and monotonic deadline. Support is distinct from registration/readiness; missing assets/network/runtime is not a verified empty search. Exact search defaults are shared by assessment and execution.
- Resolver ambiguity is capped without guessing. Typed output preserves real qualified refs and actual nextOffset, segment/document total semantics and precision; wrong-backend/scope, duplicate hits, stalled cursors or invalid pages fail. No occurrence total is inferred.
- Deadline/cancellation race returns without waiting forever for an uncooperative child. Such workers retain their admission slot until they actually finish; capacity is bounded. Replay is subject/authority/request bound, generation checked and budgeted; the ledger fails closed on saturation.
- UI enqueue returns `ui_queued`, missing scene returns `requires_foreground`. Completion requires a receipt matching UUID, backend/generation/epoch, scene and exact canonical destination, including focus/presentation. The required destination field corrects Lead/D's API-01 initial receipt finding.
- Output uses typed known fields, result-schema/byte checks, strict candidate ref shape and safe error codes. Provider debug reasons and arbitrary error descriptions are not relayed. Raw provider SQL/path/token failures and extra candidate privateText are regression-tested.
- Counts, note save, package mutations, backend switching and all other staged operations remain fail-closed. Metadata for29 actions never advertises29 working tools. `includeModes:true` is explicitly unsupported until a variant report contract exists; no invented mode metadata.

## Executed verification

Command: `swift test --package-path Source/Otzaria/Actions -j 1 -Xswiftc -strict-concurrency=complete`.

Original7060be46 checkpoint:23 XCTest methods PASS. After independent ENG-01/ENG-02 corrections: EXECUTED_PASS26 methods,0 failures (2 API,18 engine,6 wire/security tests), Swift6.3.3 Windows portable compiler/runtime with explicit synthetic backend/resolver/UI ports. No Apple SDK or app runtime. Final log and source hashes: `results/swift-tests.log`, `results/summary.json`. Exact corrections and separate D evidence: `ENG_REVIEW_FIXES.md`.

Coverage includes all initial five operations on all three mocked targets; strict wire/descriptor/semantic gates;11 frozen example schema/DTO projections;29 catalog descriptors; exact-number attacks and integral positives; duplicates/escaped keys and exact wire property names despite Swift Unicode canonical equality; input/output limits; rights/origin/work scopes; backend mismatch before commands; metadata/readiness vs zero; actual continuation; ambiguity; redacted errors/candidates; generation/epoch drift; UI queued/missing scene/wrong UUID/wrong section/wrong focus/stale ACK; cancellation/deadline with controlled uncooperative providers; replay and admission/retention budgets. Eight uncooperative workers are retained at most, the ninth request is refused, and all8 deadlines return. Tests always release controlled blocked providers, leaving no indefinite test tasks.

Six bundled JSON resources exactly match frozen MANIFEST bytes/SHA256 (`results/resource-provenance.json`). The20 planning artifacts were implementation inputs, not runtime evidence. The116 historical planned cases remain NOT_RUN. The schema validator implements the frozen resource keyword set, not arbitrary complete Draft2020-12 validation. UUID case is compared semantically in example round trips; other wire fields remain exact.

## Remaining gates / limitations

- D's independent exact7060be46 review closed API-01/API-02 PORTABLE and found ENG-01/ENG-02 (102/104 synthetic engine cases passed). Those two local corrections now have26 passing P tests; independent D retest remains open. No native/device acceptance follows from either result set.
- Real resolver and production state/search bridges in separately owned Resolver/** / Integration/**. Mock ports prove dispatch/contracts and fail-closed behavior, not live provider semantic correctness.
- Real SQLite/Tantivy, Legacy network/offline, Embedded Hermes/RPC readiness/epoch and full corpus acceptance; actual original Maktabah/RN reader and scene acknowledgement. All NOT_RUN here.
- Apple-platform SDK/compiler/native integration, AppIntents, deep/universal links, AI/guide/MCP transport, licensing review and physical iPad. No framework/app targets were touched or tested.
- The in-memory256-request ledger has no persistence/expiry policy and intentionally refuses overflow. Production replay lifetime and per-session admission lifecycle must be specified before app integration. Cancelling a noncooperative provider cannot forcibly terminate its implementation; at most8 may remain outstanding, and native UI ports must check invocation immediately before actual commit.
- No note persistence, package mutation, exact occurrence count, background device relay, data migration, costly CI, dependency install, app build, signing/distribution, push or merge occurred. The assigned source task remains incomplete.

Ownership and rollback: `HOOKS.md`. All source is new downstream package code; zero original upstream/app/project hooks. Revert only G1 commits if required, preserving other worktrees and active Apple work. API corrections are documented in `API.md`; I/S resolver/state/search signatures remain unchanged.
