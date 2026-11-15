# I-ACTIONS-RESOLVER ACK — 2026-11-15

[נועם | DEV] [MAIN_SESSION]
Primary UUID: 01a1dc8a-3c0e-7493-98cd-9a8062091a5d.
Manager: 01a1dc84-2697-7902-b100-9e23913eb7f4.
Verified new worktree C:/Users/DAVID/Code/Maktabah-hq-actions-resolver-20261115.
Verified branch codex/otzaria-actions-resolver-20261115.
Verified base/HEAD 3d6f90c90403a18e780ca37504da1c71285b219e; pre-edit status clean.
Task GID1219614268854015 read including comments; historical research label is superseded by the explicit current activation.
Lease: Source/Otzaria/Actions/Sources/OtzariaActionCore/Resolver/**, Source/Otzaria/Actions/Tests/OtzariaActionCoreTests/Resolver/**, docs/hq-actions-resolver/** only. Test folder follows existing SwiftPM test target path. No shared API/manifest/Integration/engine/policy/registry/resources/project edits. P owns contract changes; S owns BackendSemantics/production adapters.
Existing Inspector worktree is preserved. No subagents/child chats. Focused SwiftPM -j1 strict-concurrency checks authorized; no native build/CI/release/live data. Source changes will be new downstream files only; no original upstream hook. Rollback: revert lane commits only.

## Resolver pre-edit design / provenance
All20 planning MANIFEST files read/parsed, SHA256 and byte lengths match; planning116cases remain NOT_RUN. Read G0/G1 freezes and committed public API/Contracts/Ports at3d6f90c. All new Resolver/test/docs paths are DOWNSTREAM_OWNED (new package at application base07d1cafa); no upstream hook. CatalogDataPort remains the authoritative source: aliases are never invented; reference validate must prove existence, not echo a trimmed string. Existing API cannot independently inspect DB/RPC proof, so that trust boundary and production NOT_RUN will be explicit.

Implement actor CatalogActionResolver with injected data/state/uptime; no mutable catalog cache or parallel index. Bound text/aliases/catalog/candidate CPU and memory, scan all allowed entries before deciding unique, retain ambiguity at limit1. Match source-owned titles/aliases by NFC/whitespace/quotes only, preserve nikud/case and exact reference query strings. Check identity, same-work/backend, revisions, cancellation/deadline/generation/RPC epoch around every source await; validate all candidate refs and exact destination section/focus without substitution. Typed errors distinguish malformed input, invalid source response, unavailable and true notFound. Fixtures label source-shaped data and no production proof.
