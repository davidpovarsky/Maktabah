# Actual U75 runtime result: Escape still fails

Source candidate `83c13b41` then `75ea765d` was integrated by T; actual run [43696201794](https://github.com/davidpovarsky/Maktabah/actions/runs/43696201794), checkout `6a54a44f` (T reports application source e64 via068 integration; Q test ab23 unchanged), compiled with the Apple SDK and executed the one affected window case. T reports **build-for-testing PASS; fresh native tests 0 passed /1 failed**, same line169. Inspector remains **NOT_REACHED**. The prior eight healthy reader passes are preserved prior-run evidence, not eight fresh passes at this checkout. U75 is **not a verified runtime fix**.

U independently inspected the new raw log. Focused fixture-title input and a real hittable result precede `input.typeKey(Escape)`: t89.63 request, t90.91 event synthesis, t91.70 idle. Palette existence remains true through the full assertion timeout. No new source behavior changes have been made in response to this failure.

## Existing evidence and its limits

Artifact root:

`C:/Users/DAVID/Code/Maktabah-hq-integration-20261115/docs/hq-integration/.cache/run-43696201794-selective/artifacts/`

- `test-simulator-11-window.log`: actual invocation, local CommandPalette package resolution, event synthesis, line169 timeout, failed one-test result.
- `visual-11-window/F37E991B-03AA-41C7-AE37-A4CF83F335BC.txt`: before Escape, actual375x486 window, palette345x290, native search input explicitly labelled and **Keyboard Focused / Focused**; software keyboard exists.
- `visual-11-window/66DFC112-AA1D-4289-8F86-877789371271.png`: U viewed this pre-Escape screenshot; it visibly shows the same query/result and software keyboard.
- `visual-11-window/535D7040-2738-4CF7-AE45-556C6E564A1B.txt`: palette remains after full-screen restoration; input no longer carries Focused flags. This is **after teardown/restoration**, so it cannot establish when or why focus changed.
- `visual-11-window/manifest.json`: first post-event debug description is `C7333D36-3056-4E09-8DBE-552209175FF3.txt` at1794734210.012 (event attachment1794734208.679); later descriptions continue. These may offer a closer post-event focus snapshot if T retrieves them.

The current two leased source blobs equal their versions at actual checkout6a54a44f. Visual differences from the earlier ancestor-host run (palette height290 instead of525.5; explicit native-input label) support use of the candidate input, but are not substitutes for proving the local Swift package was actually compiled. Q requested exact compile path and binary symbols; T is retrieving the **existing** build log and binary evidence before another source change or run. Source-file inventory alone does not prove a cached/local SPM object was rebuilt.

## Evidence-led next step

Hold production edits until T's exact local-package compile/binary evidence arrives. If it proves U75 was compiled, the next source change is **diagnostic only**, within the existing two-file lease. It must retain all current handlers, focus logic, callbacks, original UI/query, test source and visible-dismissal oracle.

Proposed bounded unified-log category: subsystem `com.davidpovarsky.chavrusatext`, category `R27PaletteInput`. Fixed stage names and Boolean state only; never log book titles, query/input content, clipboard text, locator/session IDs, user paths or arbitrary key characters. Trace:

| Boundary | Evidence needed |
| --- | --- |
| Native field mount/update | Candidate actually instantiated; own-window presence, key-window status, first-responder state, requested focus |
| Native begin/end editing and become/resign | Whether focus changes before Escape handling; same fixed flags |
| Key-command advertisement and own-action validation | Whether UIKit queries this actual input's command and considers it available |
| Raw press and UIKeyInput | Escape classification only, not text/key contents; whether an event reaches this input |
| Existing dismiss handler entry/exit | Whether its first-responder guard accepts the event and invokes its callback |
| Existing package/adapter callback and disappear | Whether delivery reaches original dismissal state and actually unmounts the palette |

If commands/events never reach the proven native input, further input rewrites are unjustified; inspect event/keyboard/window delivery with Q/T. If the first-responder guard rejects the event, use actual transition ordering to identify the cause before changing it. If callback delivery succeeds but unmounting does not, investigate actual state propagation/remounting through the appropriate owner/lease. Do not infer one of these from AX alone.

T alone would collect bounded simulator unified logs for that category with the unchanged single affected case; Q keeps the real Escape/visible-dismissal assertions and classifies actual results. There is no request for a new dispatch from this document. No blind third input rewrite, fake UIKit proof, relaxed test, tap workaround, broad CI, signing or data operation.

U native tests executed: **0**. Actual build/run evidence is attributed to T/Q. The original candidate evidence remains an immutable record of syntax/source checks, not native success. Physical iPad acceptance remains open.
