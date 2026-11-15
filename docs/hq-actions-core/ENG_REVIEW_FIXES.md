# ENG-01 / ENG-02 — independent review corrections

[נועם | DEV] [MAIN_SESSION],2026-11-15, primary `01a1dc89-87bb-7521-b249-ed383392e940`.
Reviewed parent `7060be466425ad052faffeef21c309708ac0e506`; branch `codex/otzaria-actions-core-20261115`.

D's exact-parent external review reported API-01/API-02 CLOSED_PORTABLE,39 codec assertions PASS and104 independent synthetic engine cases (102 PASS,2 concrete failures). This is D's distinct evidence, not part of P's original23-test count and not Apple/device evidence. Original observations: external temp directory `otzaria-actions-security-engine-7060be46-gzxs_m47`, files `typed-vs-wire-counterexample.json`, `discovery-policy-counterexample.json`, `engine-observations.json`.

## ENG-01: typed unsigned arguments

Descriptor validation accepts bounded `.unsigned` integer storage, but search conversion used only `.integer`, silently selecting0/20/0 instead of requested offset5/limit1/distance4. The same flaw affected resolveWork.limit.

Correction: one checked internal integer conversion handles signed and unsigned exact values with `Int(exactly:)` and explicit descriptor bounds. A default applies only to an absent key; present invalid values fail. Applied to search offset/limit/wordDistance and work-resolution limit. Already-validated signed/unsigned representations of the same canonical JSON request also compare equally for subject/authority-bound replay, so typed-to-wire retry cannot spuriously conflict or execute twice. Fractional values still fail descriptor validation before this equivalence check.

Regressions compare actual provider-observed queries between typed and wire entry points, including5/1/4 and upper bounds; verify same-executor replay makes only one search call; cover unsigned work candidate limit and rejection of Bool/floating/oversized integers.

## ENG-02: discovery policy drift

Discovery duplicated scope/rights checks and missed the execution policy's deepLink content-read prohibition. It advertised search.query while that exact context was refused at execution.

Correction: descriptor-level authorization is shared by execution and discovery, including origin, scope, rights, allowed backends and device rules. Scene validation is also shared, so an empty scene cannot advertise Reader opening. No provider interface, wire/schema/resource or I/S signature changed.

Regression matrix compares search advertisement with actual execution across six origins and all three backends using independent requests and injected mock ports. DeepLink is not advertised and remains not_supported/origin_action_not_allowed. Empty scene does not advertise reader.open.

## Scope / rollback / evidence

Only P-owned ActionValidation.swift, ActionPolicy.swift and ActionExecutor.swift plus P mock/regression tests/evidence are changed. Initial status at this correction's start was clean at7060be46. No upstream/app/UI/Resolver/Integration/project/workflow/database change. Rollback is a scoped revert of this correction commit. EXECUTED_PASS:26 XCTest methods,0 failures with Swift6 strict concurrency, including three new regression methods. Final local results are recorded in `results/swift-tests.log` and `results/summary.json`.

## Independent correction gate delivered

[דנה | SEC] [MAIN_SESSION], primary `01a1dc86-01b1-71e3-b863-1b7f55ed21d3`, independently inspected exact correction `ba39471476a607c6b520742577db4b4d3c6ef613` in a fresh external snapshot. Result: **62/62 focused external assertions PASS,0 failures**. ENG-01/ENG-02 are CLOSED_PORTABLE; API-01/API-02 retained regressions also pass. D verified all26 exported committed snapshot file hashes remained unchanged.

The62 comprise5 original typed/wire/default/bound cases,15 present invalid search-number cases,7 resolver-limit cases,3 replay/fractional/rights cases,18 origin/backend combinations,3 missing-authority/device cases,4 scene cases,4 destination-receipt cases and3 exact fractional-token cases. D did not rerun or relabel the earlier104 engine cases or P's26 XCTest methods.

Durable independent disposition: `C:\Users\DAVID\Code\Codex-Agent-HQ\docs\otzaria\unified-actions\SECURITY_REVIEW_G1_20261115.md`, section "Correction checkpoint ba394714". The delivered62 observation records are preserved locally in `results/independent-D-ba394714-observations.json`; provenance in `results/independent-D-review.json`. P verified the delivered artifact count/pass flags and unchanged production-source hashes without rerunning tests or modifying code.

Only these named portable findings are closed. Real Resolver/Integration providers, native scene commit, data/auth/licensing, full corpus/Hermes, Apple compiler/app integration, physical iPad and116 historical planned acceptance cases remain NOT_RUN. The source task remains incomplete.
