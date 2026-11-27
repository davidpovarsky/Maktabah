# Inspector repository identity follow-up

## Product change

This packet is based on `f000c095cea53945eba3859eb8a25c0f60906970` and changes one line in `OtzariaReaderSourcesInspectorHost.originalInspector(selection:)`:

```swift
.id(ObjectIdentifier(repository))
```

The modifier is attached to the existing `TorahInspectorUI.TorahInspectorView`, immediately before its DEBUG observation background. It uses the same local repository already supplied to the original Kit. The outer generation/mode/contentID identity and all other product source remain unchanged.

The original f000 Session repair and its eight component controls are preserved. Their published aggregate copy555 contains identical changed files; choose one source commit, not both.

## Why the Kit subtree needs this identity

The exact pinned Kit file used by the recorded Apple build has SHA256 `92295e1d372d393309fc03d15ea2cd2ea51997acf22a065ec865dea72ed89c33`. Its relationships entry keeps `@State focus` and starts loading with `.task(id: selection.id)`; the selection ID contains source scope/reference but excludes repository and text mode. A remounted host can form that subtree before its initial mode callback replaces the retained Session. Repository replacement alone does not change that task ID.

The added identity binds the original subtree to its actual repository. A matching Session/mode retains the existing repository and therefore the same subtree state. A changed repository replaces the subtree, giving the newly mounted Kit its own first load and focus state. A noncooperative old load may still complete into the retired subtree; this change does not assert cancellation of provider work. The old subtree retains its repository, so its object identity cannot be reused while it still owns that state.

This is a source/lifetime correction. Actual SwiftUI scheduling and displayed content must still be checked through the original native UI.

## Independent review and exact workspace scope

`INDEPENDENT_REVIEW.json` verifies both donor product hashes, all25 aggregate file matches, all13 stored/decoded evidence checks, exact8 candidate cases, the original receipt and four model inputs. The actual pinned Kit source was read on the Mac and matched to its build receipt.

The current reviewed root workspace is SHA256 `38c1143e488411cd71e3be02935ee6eba67d74943a87a06e344dba5475d730ad`, while the old structural witness used `fa5c00a3544b2543e1e482d6f1fb97b8a2a12f87c8cae6bd67c536c1b8d7fb38`. The retained Session state, initializer, binding and outer mode identity statements still match exactly. Neither the old structural witness nor the following component check compiles the current entire application workspace.

## Actual new validation

The complete candidate host and actual adapter passed Swift6 strict typechecking on the Scaleway Mac with **MacOSX27 SDK and target arm64-apple-ios27.0-macabi**, exit0 with empty stdout/stderr.

The check reused the existing verified TorahInspectorCore/UI modules, four original model inputs, declared InspectorModeBoundaries and the existing inspector-generation-attempt-2 module-cache. All7 source inputs and the three module/dylib hashes were unchanged before/after. No new module-cache directory or SDK rebuild was performed. No eight-case model rerun was performed.

Exact host SHA256: `1fb9c8c8db81b50f86541dd970e22bca8da934434c4c4990d47926f0f710ebb2`.

Actual result SHA256: `05acb04a9adb246f933b368ad6533eb389f972f5c5313bbc960c047c2839089f`.

The retained typecheck command includes explicit synthetic provider/Reader/annotation/routing boundaries. This is a complete host/adapter component typecheck, not an application build or native iPhone/iPad test.

## Required native acceptance

**NOT RUN:** source/translation/source with Inspector visible; mode change while hidden and original close/reopen; simultaneous backend/resource changes; and actual current displayed body/reference/version after a late retired request. The original production and physical-device gates remain required.
