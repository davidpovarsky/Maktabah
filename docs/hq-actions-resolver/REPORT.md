# G2 semantic resolver — implementation handoff, 2026-11-15

[נועם | DEV] [MAIN_SESSION]

Source Asana: 1219614268854015 (only this GID). Primary UUID: 01a1dc8a-3c0e-7493-98cd-9a8062091a5d.
Worktree: C:/Users/DAVID/Code/Maktabah-hq-actions-resolver-20261115.
Branch: codex/otzaria-actions-resolver-20261115.
Exact base: 3d6f90c90403a18e780ca37504da1c71285b219e; application source base: 07d1cafa6c6bc27aaf299aa826d28a4c02090cb5.
Status: initial portable semantic resolver READY_FOR_QA. Source task remains open; no production/device completion claim.

## Implemented

Public `CatalogActionResolver` actor implements the existing `ActionResolverPort` with injected data/state/monotonic uptime, preserving shared DTOs/ports. Work queries resolve exact source titles/keys and source-owned aliases, with bounded NFC/whitespace/quote normalization and preserved case/nikud. Explicit title query/workRef conflict is rejected. A full bounded source snapshot is examined before uniqueness is decided. Duplicate qualified identities are deduplicated while distinct identities/editions/revisions remain ambiguous even at limit=1. Candidate output retains safe source provenance and confidence.

Reference input text/section is forwarded unchanged to the authoritative data parser; returned qualified refs must satisfy requested backend/work/revision and source catalog membership. Every reference candidate, including candidates beyond the returned cap, receives exact source existence validation. An unknown Embedded candidate that only survived trim/normalization does not pass without source validation. Caller-supplied section/focus are validated without replacing either ref; same backend/work and compatible explicit revisions are required.

Catalog, text/alias, candidate and aggregate byte budgets fail explicitly instead of silently searching only a prefix. Catalog scans check cancellation/deadline per entry, yield and recheck generation/Embedded RPC epoch at bounded intervals. Snapshot checks surround successful and failed provider awaits; untyped provider errors become safe unavailable. A known Embedded RPC epoch is required. An invocation's temporary identity sets are discarded afterward; there is no persisted index, alias store, global cache or MainActor resolver loop.

Detailed public usage, budgets, typed errors and source trust contracts: API.md.

## Files and ownership

| File | Ownership | Purpose |
| --- | --- | --- |
| Source/Otzaria/Actions/Sources/OtzariaActionCore/Resolver/CatalogActionResolver.swift | DOWNSTREAM_OWNED, new | Shared actor resolver implementation |
| Source/Otzaria/Actions/Tests/OtzariaActionCoreTests/Resolver/CatalogActionResolverTests.swift | DOWNSTREAM_OWNED, new | Transparent source-shaped behavioral fixtures |
| docs/hq-actions-resolver/ACK.md | DOWNSTREAM_OWNED, new | Verified ASSIGN/ACK, clean pre-edit branch/base/lease |
| docs/hq-actions-resolver/API.md | DOWNSTREAM_OWNED, new | API behavior and integration obligations |
| docs/hq-actions-resolver/REPORT.md | DOWNSTREAM_OWNED, new | Scoped evidence/limits/handoff |
| docs/hq-actions-resolver/PROJECT_BOARD.md | DOWNSTREAM_OWNED, new | Durable implementation discovery |
| docs/hq-actions-resolver/tests.log; tests-initial.log | DOWNSTREAM_OWNED, new | Final PASS and earlier failure evidence |

The package is fork-owned at the assigned checkpoint. P owns all unchanged Contracts/Ports/Policy/Registry/Engine/Resources/Package.swift. S owns BackendSemantics and production Integration. Original upstream pinned SHA d46af139b3a265399c16d87f5923acd8e3444024 has no Source/Otzaria/Actions tree. Upstream source/hook edits: NONE. App source, project, workflow, locks and original Inspector tree remain untouched. SwiftPM default discovery includes the new source/test folders; no manifest or Xcode registration was made. Manual ownership review only; no automated boundary PASS is claimed.

Planning inputs: all 20 MANIFEST artifact hashes/byte counts verified unchanged, G0/G1 freezes and exact committed API/Contracts/Ports inspected. The 116 planned backend acceptance cases remain NOT_RUN; this is not a repeated project-wide audit.

## Executed checks

1. `swift build --package-path Source/Otzaria/Actions -j 1 -Xswiftc -strict-concurrency=complete` — EXECUTED_PASS on Windows Swift 6.3.3, portable package only.
2. Final `swift test --package-path Source/Otzaria/Actions -j 1 -Xswiftc -strict-concurrency=complete --filter CatalogActionResolverTests` — EXECUTED_PASS, 15 XCTest cases / zero failures. Final build 22.41s; test execution 0.09s is fixture timing, not app performance. See tests.log. The trailing Swift Testing runner's zero tests is separate; the executed XCTest suite contains 15.
3. `git diff --check` and changed-path/ownership review — EXECUTED_PASS.

The tests cover:

- all three canonical backends, source alias matching, exact section/focus and presentation preservation;
- NFC, Unicode Hebrew/curly quotes and whitespace, without stripping nikud/case or creating aliases;
- duplicate titles/editions/aliases, same-identity duplicates, 35 matches with stable caps 1/25, explicit title/work conflict;
- malformed/oversized/control input, cross-backend/work/position and revision mismatch, no provider calls for detectable malformed requests;
- genuine zero vs typed/untyped unavailable, unknown/trim-like Embedded refs, unchanged forwarded text/section, source work mismatch;
- source substitution, malformed catalog/provenance and malformed/oversized candidate wire objects;
- 30 reference candidates: all validated, only 25 returned; empty ambiguity rejected and single capped ambiguity not promoted;
- entry/alias/candidate budgets, 2,000-entry last-match discovery and deadline expiration during actor scanning;
- generation/backend/RPC epoch changes across catalog/reference/validate awaits, unknown RPC epoch;
- deadlines before dispatch and after every data-await stage, cancellation before SQL/RPC-shaped data dispatch and during source await;
- opaque key/revision component ordering (no delimiter collision).

An initial run compiled and executed 11 tests but failed two assertions in candidate ordering: concatenating key+delimiter changed prefix order (`book:10` before `book:1`) and could collide for opaque keys/revisions. It was corrected by typed component comparisons and a dedicated opaque-key regression. The final 15-case run passes; tests-initial.log is retained as failure evidence, not a baseline acceptance claim. Duplicate source metadata now prefers exact over alias evidence deterministically when retained.

## Integration and acceptance limits

- NOT_RUN: production catalogs/aliases, real DB/remote API/Hermes source proofs, source-specific reference parsing and unknown-vs-unavailable behavior, whole-app wiring, original UI, Apple compilation, simulator and physical iPad acceptance. Source-shaped fixtures are not these proofs.
- Integration must supply an authoritative `ActionResolverDataPort.validate`; equality with a trimmed string alone cannot prove source existence. S explicitly confirmed actual catalog/section/segment proof and error propagation without API changes. Public-safe provenance is the source adapter's responsibility.
- Resolution of arbitrary natural language/commentary hierarchy is not invented: source aliases/parser must provide that evidence. No new transliteration/morphology engine or source index was built. Exact search modes/options are untouched.
- The frozen port validates individual refs; no extra section/focus containment relationship is inferred from same-work positions. Additive source-pair proof, if required beyond G0's same-work rule, would need P-owned contract coordination.
- Provider acquisition/allocation and a noncooperating await are outside resolver-owned CPU limits; cancellation/deadline is checked around such awaits rather than forcibly terminating them. Provider MainActor behavior needs actual production review.
- Registration/capability/rights/active-backend switch policy remains with the existing executor and S's semantic adapters. The resolver does not select a backend or duplicate those policies.
- Independent QA/security review, coherent later integration and original source-task acceptance remain OPEN. No CI/native build/archive/release, push/merge, user DB, dependencies or additional chat/subagent was created.

Rollback: revert the lane commit; all production code changes are additive within Resolver. Shared API files are unchanged. A future compatible integration can include the actor without a manifest edit; actual app composition belongs to its separately assigned owner. Local package acceptance does not close the source task.
