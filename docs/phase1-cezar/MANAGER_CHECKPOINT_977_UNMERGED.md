# Manager checkpoint — quota-blocked scoped review, candidate retained

**Phase 1 NOT READY / incomplete. No final source-integration approval or native acceptance.**

## Exact recovery identity and source

- Manager Cezar run: `f51775d6-ad62-41ad-82b3-fe225d71cd05`, branch `cez/f51775d6`, original isolated worktree retained.
- Original source: `4065feef11bd5a8997ea34364516468105778688`.
- Integrated A/B source checkpoint: `84b533700c6f6401750e3f4f45d89123b55751fb`.
- Pre-final-wave manager checkpoint: `cc020cc02104324b6fc0f846861f4f653d0639f8`; later checkpoint documentation changes no code.
- Unmerged final candidate: `cez/c4687096`, `977a02a1a6c6167188d99f0ef5eba51b6c70b784`.
- Candidate app source commit/tree: `a316f0167d62a57e505c0f99c2e8694414d6e0de` / `45a956ff63f48b641f07369064dbb960c7e254a8`.

Eight unique children were used, one in flight at a time. No ninth task, nested worker or replacement manager was created. Exact children/conversations/commits are in the HQ `PHASE_1_CEZAR_ORCHESTRATION_RECEIPTS.json`.

## What is verified and what is not

Candidate `977` has exact allowed scope, no Source/Vendor/project/workflow/full-case-manifest/pinned-test changes, and the input JSON differs only in the two permitted SHA values. Real source-only preflight PASS; manager directly re-ran Python suites 13/13, 7/7, 6/6, 10/10 and 17/17 PASS. These are portable/source/evidence checks, not native cases.

The scoped continuation of reviewer `b777cd73-0910-4aa4-8c69-90453f4f0b9a` failed quota on original conversation `24909b34-c16b-449c-a9ee-2ec18b7c3af3`. Its branch remains clean at original report `207093515dd850f4cfd036273311dc2444921c8f`, with no new review of `977`. Do not merge from passing tests alone. Reported reset was `1h9m54s`; recorded `autoResumeAt=2026-11-17T15:59:27.813Z` is not proof that recovery is running or will succeed.

## Acceptance and owner gates

- All 27 native cases on repaired code: **NOT_RUN**.
- Old `4065feef` run `43891893650`: 9 PASS / 13 FAIL / 1 interrupted / 4 NOT_RUN, cancelled; historical only.
- Body paging #21 remains unfixed; startup `invalidLocator` #22/#23 remains unverified.
- Actual Apple SDK/app build, real iOS 27 UI/AX/reader/phone/window/HID and macOS POSIX cleanup remain open.
- The existing workflow needs an exact remote SHA. Candidate lookup returned GitHub HTTP 422; no-push/local-only/no-manual-paid-CI constraints were not bypassed.
- Approved NavigationStack/Dynamic Type hooks remain applied and hash-identical. Do not request the same approval again or infer a new protected exception.
- All six primary and both parent Asana tasks read back OPEN; privacy remains DONE, not reopened.

## Rulings made and costs

1. Reuse existing process-group teardown rather than duplicate kill logic; a wrong diagnosis would require later targeted rework.
2. Keep unknown reader/gesture causes diagnostic-only rather than guess; actual paging/startup bugs remain unresolved.
3. Treat rotation results under queued system prompts as contaminated, not proof of a new layout regression; alert-free native evidence is still needed.
4. Require the reproduced timeout/first-signal fix before A integration and the numeric-formatting fix before B integration; cost was two scoped fix/re-review rounds on existing tasks.
5. Reconcile only the proven downstream CI-input pin fields, without changing protected source, engines, resources or case manifest; source preflight is not native acceptance.
6. Preserve local-only/native-checkout gates rather than publish or substitute old-source passes; all repaired-source native cases remain unexecuted.
7. Hold final candidate unmerged after quota blocks independent review; manager retains its prior pin blocker and no READY claim is made.

Recovery preserves all branches, original/frozen worktrees and raw evidence. No reset, discard, main/base merge, push, release, production/email action or user DB migration was performed. To roll back, select a known earlier checkpoint in an explicitly approved separate worktree; no destructive rollback was executed.

HQ result/matrix/ledger/receipts/cancellation-reconciliation files now carry this superseding checkpoint while retaining their original historical evidence. Source workflow stops at these gates; it does not start Phase 2.
