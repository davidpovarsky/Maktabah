# Native75 repair evidence — 2026-11-20

## Source and observed failure

Base: `508d15149b5c1ba0d9949279755ba286fd57a138`.
Observed run: https://github.com/davidpovarsky/Maktabah/actions/runs/44559352638
Observed source: `ef449e640c3fd538b52627a48ea09846a785c52e`.
This repair has not yet passed Native acceptance.

The original xcresult summaries recorded 73 cases: 52 passed, 21 failed,
zero skipped. Two window cases did not run because fixture download failed.
Search: 17/21 passed; Reader: 25/34; Sidebar: 2/4; Phone: 8/14.
Textual runner restarts reported partial totals (Reader max 16), so they were
not a reliable source for the matrix execution count.

## Narrow harness repairs

- Allow the existing public-v2 `native.reader.inspector` system URL envelope.
  Preserve credential, target UUID, nonce, request age, query and endpoint
  restrictions; the actual app parser/Core/receipt ledger remains authoritative.
- Report recorded/executed/passed/failed/skipped counts from actual xcresult
  summary fields. Missing or inconsistent counts fail closed. A diagnostic
  failed-summary count cannot produce an acceptance status.
- Permit one repeat of the same miniTest10 installer after the exact native
  DNS failure observed in window provisioning. Retain the first failed report;
  a second failure, hash/data failure, other profile or later phase still fails.
- Query the exact `global-search-history` identifier as the actual native
  CollectionView in three focus/refusal cases. Keyboard, receipt, query and
  non-submission assertions remain intact.
- When normal phone bootstrap restores a durable Reader, prepare the Library
  using that Reader's unique native Back button before sending the tested
  route. Verify the selected Reader owner/tabs survive. Post-route refusal and
  navigation assertions do not invoke this preparation helper.

## Executed validation

On the Windows worktree:

- `test-runtime27-url-delivery.py`: 16 passed.
- `test-runtime27-fixture-recovery.py`: 6 passed.
- `test_verify_xcresult_zero_skips.py`: 12 passed, including contradictory,
  missing, failed and skipped result rejection.
- `test-verify-faithful-xctest.py`: 8 passed.
- Python byte compilation of the matrix driver: passed.
- Swift 6.3.3 frontend parsing of NativeRoutingAcceptanceTests.swift: passed.
- `git diff --check`: passed.

These are 42 portable contract tests and syntax checks, not iOS SDK compilation
or Native UI acceptance. Logs are in `build/native-repair-20261120/`.

## Native regression still required

Retain every original Native75 case, including the two previously unrun window
cases. Specifically inspect public-v2 Inspector on iPad/phone, unknown Inspector
refusal, public/system search first responder and unknown-component refusal,
phone warm/cold History and wrong-backend refusal, and actual xcresult totals.
No source-level Search/Sidebar/Intent failure is waived by this harness repair.
No Native run was dispatched from this branch during this change.

## Upstream integrity

Read AGENTS.md, PROJECT_AGENT_GUIDANCE.md and UPSTREAM_INTEGRITY_POLICY.md.
The live upstream HEAD examined was `d46af139b3a265399c16d87f5923acd8e3444024`;
its tree has no Scripts/CI or Maktabah-iOSUITests paths. These repairs are in
existing downstream tests/orchestration and do not change production app logic.
