# Reader lane source ownership

Base: `29a731e273f9a757c743c49e182fece0e8047d46` (fast-forward from `31b29f8f`; only unrelated NativeRouting test labels differ).
Actual upstream HEAD/main observed 26 November 2026 UTC: `4203de5fd77beb119e5826e039be1a61325f7be0`; merge base `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. No upstream sync performed.

The owner's current Wave 2 request authorizes reader, TOC, backend switching, loading state, and regression repairs. AGENTS.md standing authorization supersedes the older per-hunk confirmation rules while preserving original UI and technical contracts.

| File | Ownership | Scope and reason | Validation |
| --- | --- | --- | --- |
| Source/Features/Reader/ViewModel/BookTOCViewModel.swift | Upstream-owned with existing downstream backend integration | Minimal request-generation fencing around the existing private async load; one current loading owner; complete original success/failure/reset state. An external adapter cannot control the private task or its defer. No new TOC UI, backend, locator, or data model. | Whole actual source on Apple Swift with controlled delayed transport/database boundaries; original native TOC gates remain required. |
| Tests/HQ/reader/TOCLoadLifecycleSupport.swift | Downstream test boundary | Explicit backend and database continuations; no app data or native UI claim. | Same support for baseline and candidate. |
| Tests/HQ/reader/TOCLoadLifecycleTests.swift | Downstream regression | Exercise overlapping requests, same work retry, backend transitions, cleanup, empty/error states and balanced releases. | Actual source runs, before/after. |
| tools/hq-toc-load-lifecycle.py | Downstream runner | Preserve immutable production snapshots and exact test hashes across Oracle-to-Mac transfer. | Input checks and real compiler/process exits. |

Rollback: revert the scoped source commit. Existing source/metadata/production DB, search packages, reader rendering and app routing remain under their original owners.
