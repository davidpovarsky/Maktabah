# Inspector public binding completion — 2026-11-20

## Change and source attribution

Base: `e90feda1ed411b98ebc4a55f1d6df0b089a6f305`.
The two production changes are confined to
`MaktabahNativePublicBindingAdapter.swift` and
`MaktabahNativeSceneSession.swift`.

The original public-v2 Inspector binding returned `inspectorVisible = nil`
at both admission and completion. The unchanged
`PublicNavigationLocalBindingGuard` requires an independently observed
`true` at Inspector completion. Consequently a successfully presented
original Inspector could never complete through that binding.

The scene now passes the visibility already observed through its original
current Reader or Inspector witness. The adapter uses this value only when
the existing Inspector availability, native Reader ownership, backend,
workspace mapping epoch, scene admission and presentation checks pass.
Unknown visibility remains `nil` and fails closed. No visibility is
inferred from the URL. The original Inspector owner, receipt validation,
one-use Core authorization and final visibility checks are unchanged.

Historical Native evidence is attributed separately: Native78 checked out
`7d05dd0bb25a7df307b35174e49e18d0f22eecee` with application source
`5d8ef991554b01ba6bf3d39222c5ef6cc00a264b`. Its verified result was
65 PASS / 13 FAIL / 0 SKIP / 0 NOT_RUN. In the original iPad reader log,
00:47:47.188–.189 records an actual visible, matching Inspector followed by
00:47:47.198 `native_effect_uncertain`; the AppIntent case records the
matching visible witness at 01:02:32.244 before destination-changed.
This source defect is consistent with those observations; this portable
fixture does not itself re-execute the original Native cases. The separate
phone public-Inspector missing-PID launch failure occurred before its
Inspector operation and is not claimed fixed.

## Actual verification

| Attempt | Original production input | Executed | Result |
|---|---|---:|---|
| Setup attempt | e90 base | 0 | Fixture double supplied String for Int topLevel; retained in archive |
| Discriminating RED | e90 base | 24 | 16 PASS, 8 FAIL; 0 compiler warnings |
| Candidate GREEN | Two-file worktree change | 24 | 24 PASS, 0 FAIL; 0 compiler warnings |

RED and GREEN use byte-identical fixture files and the same 64 original
Core/UIRouting/Host package inputs. The driver records all 10 app source
inputs, the exact extracted method hashes, generated inputs, commands and
expected/executed case identities. Package inputs were rechecked after
each run. Candidate app inputs and fixture bytes were independently
rechecked after GREEN. No source mutation occurred during these runs.
Full attempt reports, logs and generated source snapshots are retained in
`evidence/attempts.zip`; `evidence/verification.json` binds its hash.

The 24 cases cover six inline/modal boundary combinations across the
three backend identifiers, initial false visibility, an already visible
original Inspector, missing native witnesses, a presentation blocker,
missing navigation scope, model-only visibility, wrong-scene and old-request
witnesses, changed private selection, Reader replacement, backend generation
change, mapping ABA, replaced workspace owner, foreground revocation,
deadline, cancellation, one-use authorization, and unchanged history-root
binding. Backend combinations exercise the actual identity/authorization
contracts with explicit fixture backend state; they are not real corpus or
network tests.

## Executed component and limits

The fixture compiles the complete actual app binding adapter, original
workspace owner and mapping ownership source, the unchanged original
Inspector binding block, the exact original scene mount and public-binding
presentation method bodies, and original Core/UIRouting/Host packages. It
runs actual registry preparation, original Inspector application and strict
receipt/completion validation.

ReaderViewModel, UIKit visibility evidence, window rendering, navigation
manager and workspace/scene projections are explicit boundary doubles.
The unrelated content-opening resolver fails closed in this fixture.
No original app target, UIKit layout, screenshot, hittability, AppIntent
delivery, live backend or provider is executed. The full navigation
orchestrator is not substituted by a fake successful receipt; this fixture
directly exercises the original preparation/completion boundary.

**Apple app build and Native acceptance for this change remain NOT_RUN.**
Historical 78/88/90 selections and their outcomes are not relabeled.

## Reproduction

From the repository with Swift 6 installed:

```text
python tools/hq-native-inspector-binding.py --source-ref e90feda1ed411b98ebc4a55f1d6df0b089a6f305 --artifacts-dir build/inspector-binding/red --timeout 600
python tools/hq-native-inspector-binding.py --artifacts-dir build/inspector-binding/green --timeout 600
```

Each output directory must be new so prior evidence cannot be overwritten.
The runner builds with one job and complete Swift concurrency checking,
then executes an explicit 24-case inventory. A build/setup error records
zero executed cases and cannot be reported as a passing regression run.

The same candidate command is suitable as an Apple source fixture gate;
its execution there is still pending. The original Native public-v2 and
AppIntent Inspector cases must run unchanged to establish actual UI
completion.
