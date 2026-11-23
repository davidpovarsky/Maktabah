# Original Composer sizing contract adaptation — 2026-11-23

## Concrete native failure

Maktabah native run [45111458365](https://github.com/davidpovarsky/Maktabah/actions/runs/45111458365)
at consumer `2393e9f3` stopped in `OtzariaHanlinChatView.swift` at the original
`HanlinMorphComposer` call. The compiler reported extra arguments, missing
`inputHeight`/`home` and an uninferred `Home` generic. No successful original-host
UI result is inferred from this failure.

## Historical API and chosen correction

Canonical SDK commits `9c66a724` and `72bf6f2b` accepted
`onInputHeightChange` and measured the input internally. Commit `641d2c72`
replaced that feedback contract with an explicit `inputHeight` supplied by the
host; the later original glass correction `8e0d3b0224f22946d8b9fda2141152e7991d18fc`
preserved that explicit contract. The `home` builder did not change name. Its
diagnostic was a consequence of the mismatched initializer, not a missing second
host page.

A forwarding overload could not truthfully reconstruct the missing height
without restoring the obsolete measurement/feedback geometry. This correction
therefore adapts the actual host to the current original public contract:

- Native editor measurement still owns `editorHeight`.
- The existing `HanlinMorphGeometry.editorBudget` helper and its `max(38, ...)`
  policy remain unchanged.
- The host's existing ten-point input padding is one local constant, used both
  in the actual `padding` modifier and in its explicit input height.
- The rendered editor keeps the same `min(editorHeight, budget)` height. The
  existing input HStack height is that rendered height plus its two padding
  edges, and is passed to the original Composer.
- The obsolete callback and its duplicate measured-input state are removed.

All original host content, send/stop, editor revision, profile picker, page
bindings, toolbar measurement, callbacks and outer padding remain in place.
There is one original SDK Composer and one existing SDK geometry implementation;
no SDK source, glass parameters, animation or replacement UI was added.

## Verification boundary

The changed host Swift file passes Oracle syntax parsing and `git diff --check`.
This is source validation only. The parent-owned next native Maktabah gate must
compile the actual application with the coherent corrected SDK pin and establish
its UI result. This source-only change does not modify the running-source SDK
submodule or lock. No native test or CI was dispatched by this lane.
