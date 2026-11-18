# Original Hanlin host linkage and catalog repair — 2026-11-18

The app now references the complete original nested SDK packages through the
Vendor/HanlinSDK git submodule, pinned at 080d1a2b264ead9e3f9df690f2dd0d3e81ebd07e.
Only HanlinHostContracts and HanlinPlatformContracts are linked at this checkpoint.
The existing OtzariaHanlinHostAdapter is registered in the iOS source phase.
This is source integration awaiting real Apple package resolution and compilation.

The original SDK branch codex/otzaria-host-sdk-compat-20261118 changes only the
HanlinPlatform ZIPFoundation requirement from exact0.9.19 to 0.9.19..<0.10.0.
Otzaria retains its original exact0.9.20/revision22787ffb dependency. All6 existing
host pins are preserved; the3 additions come from original SDK lockfiles. Their
combined graph is not considered accepted until strict Xcode resolution succeeds.
No SDK runtime/contracts/provider/permission/store/UI code was copied or changed.

## Proven contract repair

Catalog discovery now uses the same ActionExecutor.advertisedActions policy and
actual backend availability as the app. It preserves metadata discovery without
content rights, hides unavailable/metadata-only actions, and revalidates host
context after the Core suspension. Execution still uses the original Core schema,
policy, budgets and readiness. No second permission policy was introduced.

The exact same17-test fixture yielded13PASS/4FAIL before and17PASS/0FAIL after,
with0 Swift6 strict-concurrency warnings. All56 frozen input hashes were verified;
only the adapter executable input changed. The recorded current-source difference
after this run is a documentation comment. SOURCE_REVIEW.json lists the four
regressions and input identities.

These tests compile actual original SDK contracts, actual ActionCore and the
actual adapter with explicit backend, authority and native-receipt doubles.
They do not execute AgentCore, a model/provider, the app, UIKit or a device.

## Original source closure

Scripts/CI/prepare-hanlin-sdk.py preserves the original3 sibling-package layout
and verifies every original package Git blob. It refuses a changed or mismatched
checkout. The focused Apple build verifies SDK bytes before and after compilation,
uses only committed remote package revisions and retains actual resolved locks.

The original HanlinPresentationSDK already supplies HanlinChatUI, HanlinChatView,
HanlinMorphComposer and Markdown rendering. Historical missing-ChatUI claims
were based on incomplete intake and are superseded. Runtime scene/context/rights
production, original UI composition and3 real model/native journeys remain open.
No replacement agent, chat/composer, conversation store, MCP transport or
permission system is authorized by this checkpoint.
