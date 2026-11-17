# O1-A manager evidence review

## Scope and identity

Manager `f51775d6-ad62-41ad-82b3-fe225d71cd05`, OpenCode Sol; logical role Tomer/Roni, MAIN_SESSION. This is manager verification, not another independently dispatched QA worker.

Reviewed child `19efbb02-ad93-42f1-9d3c-71af01b63955`, Antigravity `gemini-4-hydrogen-xhigh`, conversation `2fcfe19e-6bc8-43f9-8b91-04658ab6701c`.

Child commit `8d7fdde2134c2dead9697bfb135066abf41295e0` adds only `CI_NATIVE_FORENSICS.md` (312 lines) directly on `4065feef11bd5a8997ea34364516468105778688`. It was locally merged for evidence retention; this does not certify the child lifecycle, root-cause hypotheses, proposed repairs, or Phase 1.

## Verification and recovered provenance

The originally unresolved `scratch/run_43891893650` directory is:

`C:\Users\DAVID\.gemini\antigravity-cli\brain\2fcfe19e-6bc8-43f9-8b91-04658ab6701c\scratch\run_43891893650`

It was located from the original child's saved tool-call records, without invoking another agent or reading credentials.

Actual checks:

- `git rev-parse 8d7fdde2^`: exact base above.
- `git diff --name-status 4065feef 8d7fdde2`: only the permitted forensic report.
- `git diff --check 4065feef 8d7fdde2`: exit 0.
- Both worktrees were clean before integration.
- Git-blob SHA256 values for approved `iPadLayout.swift`, `iOSTOCView.swift`, and `ListContentView.swift` match the report's LF baseline values. No protected application source was changed.
- Existing GitHub run `43891893650`: completed/cancelled, exact checkout `4065feef11bd5a8997ea34364516468105778688`.
- Recovered `artifacts/runtime27/checkout.txt` and matrix `appSHA`/`testSHA`: same exact checkout.
- Recovered build receipt: `SIMULATOR_BUILD_FOR_REAL_UI_PASS`, checkout `4065feef…`, application source `d9ab40fbfa9d357dc07af8afbc847f6d7a4bbc1b`. Build evidence is not UI acceptance.
- Canonical content hashes match the existing CI verifier receipt:
  - summary: `eed57ae89d00beac95d16c36943a3fd083152b21feafe4b3763c9946778d0bc5`
  - tests: `0853927226abec0bcef4260910d9c03b2c648ece93e47968b2725b08ceb9bf40`
- All 22 reader test leaves match the report's named PASS/FAIL outcomes and the immutable execution manifest. All 27 report rows match the manifest's execution IDs.
- Reader cleanup receipt is PASS; the window phase snapshot is `RUNNING_NATIVE_XCTEST`; no phone phase appears.
- Seven URL transport rows report delivery, but the native lifecycle log contains only one URL event (the passing cold case). Seven subsequent SpringBoard Open-in interruption-monitor invocations corroborate a delivery gate; they do not validate warm app behavior.

**Hash convention:** `tools/verify_xcresult_zero_skips.py:143` hashes Python `json.dumps(value, sort_keys=True).encode()`, not the bytes of the pretty-printed saved JSON. An initial raw-byte comparison correctly failed; reproducing the actual verifier's serialization matched both hashes. Do not silently equate byte and content hashes.

The deterministic review script and full per-case JSON receipt are in this manager's cockpit Assets: `verify_recovered_evidence.py` and `VERIFIED_NATIVE_43891893650.json`. It reads existing evidence only and launches no native test or CI.

## Exact current-source outcomes

| Source / run | PASS | FAIL | STARTED/INTERRUPTED | NOT_RUN | Aggregate acceptance |
|---|---:|---:|---:|---:|---|
| `4065feef…` / `43891893650` | 9 | 13 | 1 | 4 | **NONE — cancelled** |

The 22 completed cases are 9 PASS / 13 FAIL / 0 skipped on the 11-inch reader simulator. The first window case has no completed result; the second window case and all three phone cases are NOT_RUN. The forensic report contains the selector-level matrix. Counts are not pooled with historical runs.

This manager executed **zero new native tests**. These are verified existing CI outcomes, not newly executed passes.

## Qualifications that govern use of the child report

1. “Completed all 22 cases cleanly” means completed test accounting and reader simulator cleanup, **not** a successful suite: 13 cases failed.
2. Seven routing failures cannot demonstrate correct or incorrect warm URL product behavior while system URL confirmation blocks delivery. Transport acknowledgements and same-PID observations are not scene receipts.
3. Contrast, return-swipe and rotation failures are observed. Exact gesture/container/toolbar causes remain hypotheses; historical correlations do not prove a particular source hunk caused a regression.
4. The two startup `invalidLocator` failures remain unresolved. No reader/backend repair is justified solely by the proposed diagnosis.
5. Proposed O2 paths are candidates, not permissions to change protected source, weaken assertions, activate public-v2, or rewrite the acceptance manifest to claim a smaller suite is final acceptance.
6. The child's report calls its local mode MAIN_SESSION. At the manager/team level it is the existing dispatched child, not independent manager-session work.
7. The unrelated HQ `native918-selective` summary (7 PASS / 15 FAIL, another device UUID) must not replace this recovered run's evidence.

## Lifecycle and next gate

The child delivered a report but Cezar recorded failures, including individual quota errors. Latest readback showed QUEUED / `continue-4` pending, no running step. No exact run/conversation process match was found; other live AGY/Python processes were left untouched. This is not proof of process death and no cancellation/resume/retry was issued.

Evidence retention is accepted; successful child/parent execution lifecycle is **not** claimed. No replacement worker may be dispatched merely to work around this state or its quota.

Phase 1 remains **NOT READY**. O2 requires scoped implementation by the authorized worker setup after the existing queue/quota is resolved. O3 requires actual coherent native execution; the latest owner instruction forbids manually launching paid CI or pushing. No Phase 2, releases, production, emails, credential changes or account/model fallback.
