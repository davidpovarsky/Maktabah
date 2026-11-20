# Preserve the original reader when the workspace feature is disabled

## Result and acceptance boundary

The product source now honors `ChavrusaTextFaithfulReaderUIEnabled=NO` at the actual iPad composition and scene lifecycle. The exact-source portable regression is **18 assertions / 18 passed / 0 failed**. Against immutable pre-fix source `799c30e06f73b97e39cbe08afc2e77a29b2906d1`, the same final fixture is **18 assertions / 11 passed / 7 failed**. These are portable assertions, not XCTest or Native cases.

The existing Native case is prepared for the normal original interface and bootstrap:

`FaithfulReaderUIAcceptanceTests/testFeatureOffCreatesNoSidecarAndPreservesAnExistingWorkspace`

**Native acceptance, Apple SDK typechecking, and physical-device checks are NOT_RUN for this change.** The integrator owns its membership in the next frozen matrix. No workflow, manifest, engine, Core package, persistence model, or user data is changed by this branch.

## Confirmed defect and minimal change

The iPad viewer unconditionally mounted `ReaderSidebarPager` and `Exact9401ViewerToolbar`, and `Exact9401WorkspaceLifecycle` created and attached its workspace without consulting the feature flag. A disabled launch could therefore create or checkpoint workspace state.

- `iPadLayout.swift`: retain the current enabled composition unchanged in a separate private property. For the disabled branch restore the original Library / TOC / Reader three-column `NavigationSplitView` from `3dc5100900fc25eac1b312d7893eb50e7bd510cb` (the parent of the original-reader restoration). Use the current original Library search, reader, TOC, toolbar, and passive routing surfaces. The disabled path does not mount the downstream pager or toolbar.
- `ReaderSidebarPageCoordinator.swift`: gate the existing store creation and attach task, scene identity/checkpoint observers, exposed routing owner, and retained workspace getter. Normal callbacks therefore cannot checkpoint a retained adapter while the flag is disabled. The enabled default and original owner identity stay unchanged.
- `iOSMainView.swift`: advertise a sidebar routing coordinator only when the corresponding iPad sidebar is mounted.
- `FaithfulReaderUIAcceptanceTests.swift`: a trailing optional tier override preserves every existing default and caller. Only the existing feature-off case selects `.realUI` and explicitly rejects the smoke-bootstrap bypass. Its positive selector now targets the actual current palette launcher and sidebar pager; the removed historical `chavrusa-reader-host` is no longer used as enabled proof. Original highlight equality, no initial sidecar, and byte-for-byte preservation after disabling remain mandatory.

The three application edits are narrow upstream composition/lifecycle hooks. The portable extraction driver and fixture are downstream test tools. No replacement renderer, content loader, database, or persistence implementation was added.

## Meaningful source-bound regression

`tools/hq-feature-off-lifecycle.py` extracts the actual flag enum and lifecycle task, workspace/owner getters, background predicate, and open-tabs callback from the repository source (or an immutable `git show` source). It compiles these expressions in Swift 6 strict concurrency mode. The fixture uses real Foundation `UserDefaults` with a temporary, restored volatile argument domain. Explicit platform, manager, owner, adapter, and store-effect doubles record only effects on an owned temporary sidecar. This does not execute SwiftUI or the original workspace store.

The seven pre-fix failures prove the disabled source constructs/attaches a store, creates a sidecar, exposes an owner, mounts observers, changes existing bytes, checkpoints a retained adapter, and returns that adapter. Positive controls preserve the enabled default, exactly one owner, no duplicate attach, missing-scene rejection, existing iPhone owner behavior, and the original enabled checkpoint.

Both final runs used fixture LF SHA-256 `767d60d1a7f550d4a62407dd97c6814f0f08f40a2834504acd0627f2dcb661c7`. Original lifecycle source LF SHA-256 is `d89dc4c50797c1dc0d6558ff253d744e91b09421d7c8a6da84d1e84bfbd3e604`; candidate lifecycle source LF SHA-256 is `64f534d1db5e265d515ebb9081f14d91e0f5b515dfb05d8ad6b62e9248047eca`. Every changed source/tool is listed in `SOURCE_HASHES.json`.

The first RED attempt is retained separately: 10 passed / 8 failed. Its final enabled callback control inherited a counter increment from the deliberately failing disabled callback. Resetting only that counter before the independent positive control removed the coupled fixture failure. The final RED still fails all seven genuine product gates. No product assertion or expected disabled behavior was relaxed.

Reproduce with `OTZARIA_TEST_SWIFTC` set to the chosen portable Swift compiler:

```text
python tools/hq-feature-off-lifecycle.py --source-ref 799c30e06f73b97e39cbe08afc2e77a29b2906d1 --out build/feature-off-20261120/red
python tools/hq-feature-off-lifecycle.py --out build/feature-off-20261120/green
```

The RED driver exits 1 as expected; GREEN exits 0. The emitted executable reports assertion counts in JSON, and the driver enforces a nonzero exit when any assertion fails.

## Other verification and review

Swift frontend syntax parsing of the four changed Swift files returned 0 for the iOS Simulator target. The Windows compiler emitted the preserved SDK/sysroot warnings; this is explicitly **syntax only**, not Apple framework compilation. `git diff --check` returned 0 with only Git line-ending notices.

Independent read-only source review by `asana_audit` found no blocker in the three application files. The reviewer confirmed the enabled composition remains intact, the disabled branch restores the original interface, and routing/checkpoint exposure is suppressed. That review covers a flag fixed at process launch; live feature switching and SwiftUI runtime behavior still require their own actual Native evidence.

Evidence is kept under `red-initial-coupled-control/`, `red/`, and `green/`, including the exact generated Swift, compiler output, original assertion JSON, and result metadata. `VERIFICATION.json` records counts, scope, source and job identities. This evidence does not transfer to another source merely because it is merged.

Generated Swift and compiler logs are preserved verbatim in each phase's `RAW_TEXT_EVIDENCE.json`, with raw and LF hashes. JSON string encoding preserves the original whitespace and line endings without turning copied evidence whitespace into a source-formatting error. The first full staged whitespace check identified only that original generated/log whitespace; source checks already passed. The evidence representation was changed, without rerunning or modifying test results, and the final full staged check passed.
