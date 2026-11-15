# Stage 2 merge ledger

[תומר | INT] [MAIN_SESSION] — 2026-11-15

Integrated source SHA: `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5`. Rollback: `codex/otzaria-integration-pre-stage2-20261115` at `242571c9a1502d068410c82af753ba2a8a2b0bbf`. Actual upstream remains pinned d46af139; no upstream sync.

| Merge | Ours before merge | Lane parent | Conflict disposition |
|---|---|---|---|
| `41e655baa8bbab4136f4a1f7eb3f273e3af4783f` | `299a86878b2c22e180a786d37eff0b65116f2bdf` | `08fa32f7e1e4a4af7d0286732d9b8976abd593f1` | No conflicts; all delivered paths match donor blobs exactly |
| `589f21c784efa845cedb20667bd506a39a1aded7` | `41e655baa8bbab4136f4a1f7eb3f273e3af4783f` | `b7c4f05c24ca7c603bed512b3f8bad4d33f799cb` | No conflicts; all delivered paths match donor blobs exactly |
| `9b21ba9684c0a3b8043b192d9a0fde4bc350f11a` | `589f21c784efa845cedb20667bd506a39a1aded7` | `a1bfa5f8ec89535115fd825efdd292d8e3bee5e3` | No conflicts; all delivered paths match donor blobs exactly |
| `00339ac433eebd04c9489aa601480f805a7875e1` | `9b21ba9684c0a3b8043b192d9a0fde4bc350f11a` | `1d3e6659bc0145becbc6b30e155ed631eaca9918` | No conflicts; all delivered paths match donor blobs exactly |
| `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5` | `00339ac433eebd04c9489aa601480f805a7875e1` | `3086d10ddfd24edad470535495fc101284a0b38c` | No conflicts; all delivered paths match donor blobs exactly |

No ours/theirs selection, rename/delete resolution, application rewrites or source-owner corrections were needed. All source worktrees/branches preserved. Changed path ownership and exact blobs, including Vendor wrapper and protected hooks, are in STAGE2_INVENTORY.json. All delivered docs/tests/audits also retain donor blob identity.

Composition is not compiler/runtime/device acceptance. Legacy exact-source guard is unchanged; current-policy hook audits remain separate. Apple authority is preflighted by Lead, not duplicated here.

## Scoped verification at integrated source

Executed PASS: every changed path from all five donor tips matches exactly the integrated blob (includes tests/docs/audits); five lane tips are ancestors; source overlap zero; 34 changed application/project/Vendor paths have exactly one lane owner; target registration check now finds the safety source in the integration tree itself and all three app targets; existing iOS membership check PASS (91 Otzaria sources, engines/dictionaries); application-only whitespace check PASS.

Full-tree whitespace check reports one inherited documentary patch-context blank line in docs/hq-sidebar/upstream-hooks.patch:10. It was not introduced by conflict resolution; donor blob was retained exactly. Requested a doc-only correction from Maya with no concurrent integrator edit. This is separate from the application/SDK acceptance gate. Do not claim full-tree whitespace PASS until corrected. Apple compiler/runtime and device evidence remain NOT_RUN.

## Documentation correction integrated

Maya supplied doc-only commit 3c369ea097e41a8a41850dc52db5744c3ec2dad1, regenerated zero-context exact sidebar hook patch. Verified only docs/hq-sidebar/upstream-hooks.patch differs from her prior tip 3086d10d. Integrated via true merge 24dab7d960ddc146ee4a5e37fe7efd6163d82c2e; no conflicts, no application changes. Full `git diff --check df2a2194 HEAD` now PASS. `git diff --exit-code 07d1cafa HEAD -- Source Vendor Maktabah.xcodeproj` PASS: application payload is unchanged from the immutable source package already supplied to Q. No guard/config/source was adjusted to mask a failure.

Apple route remains unavailable under current transport/publication constraints. APPLE_FOCUSED_PLAN.md gives the exact existing unsigned app-target command and required real dependencies, plus a strictly bounded actual-source safety-core alternative (no app-model mocks, explicit adapter exclusion and proof limits). Neither was executed. No source push, toolkit/workflow modification or signing action performed.
