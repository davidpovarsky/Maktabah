# S-ACTIONS-BRIDGE — ready for independent QA

2026-11-15, Noam / DEV / MAIN_SESSION.
Desktop UUID: 01a1dc89-716c-7a01-b6fc-49cb16fe7822.
Branch: codex/otzaria-actions-bridge-20261115.
Base: 3d6f90c90403a18e780ca37504da1c71285b219e (app base 07d1cafa).
Source SHA: the commit containing this document; the full SHA is recorded in the
single material handoff on source Asana task 1219614472017979.

This is the explicitly activated implementation tranche attached to the existing
research task. Its original research description remains intact. Status is
READY_FOR_QA, with native integration and acceptance gates still open.

## Delivered scope

- Five Foundation-only files in ActionCore/BackendSemantics implement separate
  registration, semantic support and observed readiness for Otzaria, Legacy
  Sefaria and Embedded. Capability bits never establish runtime readiness.
- Target witnesses, reference and scope bounds, revision refusal, cancellation,
  monotonic deadlines, coordinator generations and Embedded RPC epochs are
  checked. An inactive target cannot silently select another backend.
- Source-specific search options are validated before dispatch. Otzaria accepts
  the proven phrase/exact baseline with relevance/canonical ordering. Legacy
  retains source restrictions on boolean ordering and Hebrew morphology; scoped
  searches use a unique catalog-owned search path, avoiding unbounded postfilter
  fallback. Embedded accepts only phrase/exact/relevance without scope.
- The three Integration files are outside portable package Sources. They adapt
  the real MainActor BackendCoordinator, real app models/protocols and existing
  providers. Native locator conversion is lossless and rejects revisions the
  existing persistence format cannot represent. No persistence schema changes.
- Catalog resolution uses actual catalog aliases and identities. References
  require catalog membership plus actual returned section/segment proof.
  Embedded bypasses its trim-only normalizer and permissive adapter decoding;
  bounded raw catalog/text RPC responses must contain genuine source evidence.
- Search preserves the provider cursor and qualifies hit identity by source.
  Public totals remain conservative/unknown and never mean occurrence counts.
  Embedded rejects missing raw-hit evidence and unproven empty/end responses,
  preserves a genuine cursor or proven raw-consumed position, and checks raw vs
  processed hit counts even when the processor groups or mutates its input.
- One explicitly leased, additive 25-line JS response-evidence change preserves
  the existing hits/total/start/size behavior. See HOOKS.md and the exact diff.
  No upstream submodule, existing adapter, UI, composition or shared API changed.
- Future operation/source feature metadata records partial/default-only/stub/
  network/runtime states. It does not make the 29 catalog actions executable.
  Exact counts and mutations remain unsupported.

## Actual verification

All commands ran locally on Windows using installed Swift 6.3.3 and Node;
no dependencies were installed and no real user database/index was opened.

1. `node docs/hq-actions-bridge/test-embedded-search-fidelity.cjs`
   PASS: 11 source-shaped payload cases execute the actual current JS handler
   and compare legacy fields with the actual base handler. Covers absent/malformed
   evidence, total relations, grouping, in-place processing and source failure.
   Output: embedded-handler-tests.log and embedded-handler-fixtures.json.
2. `swift test --package-path Source/Otzaria/Actions -j 1 -Xswiftc -strict-concurrency=complete --filter BackendSemanticsTests`
   PASS: 14 XCTest tests, zero failures. Includes the actual-handler JSON fixtures,
   semantic/readiness gates, backend witnesses, bounds, scope and epoch/deadline/
   cancellation proof. Output: portable-tests.log.
3. `C:/Users/DAVID/AppData/Local/Programs/Python/Python312/python.exe -X utf8 docs/hq-actions-bridge/check-integration.py`
   PASS: 20 assertions after compiling the REAL app models, protocols and
   BackendCoordinator with the REAL identity bridge and facade under Swift 6
   complete concurrency checking. Providers are explicit test doubles. Covers
   inactive dispatch, position/revision conversion, scoped search, actual cursor,
   conservative totals, section proof, backend switch and RPC epoch races.
   Output: integration-tests.log. The harness initially expected Windows .obj
   files; it was corrected to also link the installed Swift toolchain's .o files.
   This setup correction is not a native app build result.
4. Separate real coordinator/facade/identity Swift strict typecheck: exit 0
   (integration-typecheck.log is empty because the compiler emitted no diagnostics).
5. `swiftc -frontend -parse Source/Otzaria/Actions/Integration/ActionLiveBackendBridge.swift`
   PASS syntax parse, exit 0. This does NOT typecheck Apple/runtime dependencies.
   Output: live-factory-parse.log, empty on success.

The final factory-only readiness adjustment followed the integration fixture run;
it does not change the compiled/tested facade, identity mapper or portable core.
The final 11-case handler / 14-test run includes the in-place-processing fix.
The planning matrix of 116 scenarios was not executed and is not claimed as PASS.

## Remaining gates and deliberate unavailable states

- Factory is additive and unregistered. Project/target wiring, composition,
  native app compilation, matching Embedded bundle and physical iPad acceptance:
  NOT_RUN. No CI, signing, IPA, TestFlight, push or merge was performed.
- Live Otzaria proof reads existing DB/schema and artifact identity/compatibility;
  it never invokes repair, recovery, downloads or the writer-capable engine
  constructor. Compatibility alone does not prove a complete/open search index.
  The host must supply snapshot-bound `otzariaSearchReadiness` from an actual
  matching index/readiness observation; its default is unknown.
- Legacy network evidence defaults to unknown. Downloaded texts do not prove
  that its remote search is available. The host must supply a trusted observation.
- Embedded host, catalog, search and package flags remain separate. Search also
  requires a verified matching JS response-fidelity epoch; the factory defaults
  to nil. A parsed source hunk or fixture cannot establish a deployed bundle.
- Independent QA and integration owners must validate these host observations,
  native APIs, strict-source DTO shapes and the unchanged UI on their accepted
  runtime. The real provider-double harness is not physical-device acceptance.
- Shared ports, Package.swift, Registry, Engine, Policy, resolver and resources
  are unchanged. The prior Search worktree is untouched.

## Rollback

Revert this tranche's additive source/tests/docs and the exact leased fidelity
hunk, or leave the new factory unregistered. No data migration, index operation,
upstream rewrite or user-persistence rollback is required.
