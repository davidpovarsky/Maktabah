# Target the original native Reduce Motion switch

The original Release44665679661 failed this case on11-inch and13-inch iPad before launching the Reader. The authenticated11-inch video shows Reduce Motion OFF before the automatic switch tap and stillOFF afterward; the34.5/40/48second frames are identical. This is not evidence of delayed preference propagation.

The original synthesized toggle event records raw coordinates704,765 in the same Settings process/window/orientation as two successful navigation events. Comparing the navigation events with their actual original frames empirically corroborates the mapping (raw_y,834-raw_x). The toggle event therefore lands at765,130, in the centre of the labelled row, around376points left of the visible switch. This interpretation is cross-checked from three original events; it does not assign a public UIKit meaning to a private archived enum.

The test now sends one tap to the trailing side of that same native switch, using a normalized coordinate from its current frame. The original Settings English language setup remains. Each actual tap requires an existing/hittable original control, finite live geometry and a point inside both the control and its own Settings window. Before tapping it retains the real Settings accessibility tree, live frames, screen point and system state. There is no retry, fallback action, preferences injection or application change.

The original enabled-state15second expectation and the original restoration15second expectation remain exactly intact. The initial wasEnabled logic, teardown registration and all subsequent Reader/palette behavior assertions are preserved. The same original target calculation is used only when enabling or restoring the setting requires a real switch action.

An exact inverse reproduces every original source byte. Windows Swift6.3.3 frontend parsing completed with exit0 and two Apple-SDK warnings; this is syntax evidence only. Independent source review found no concrete actor/lifetime/geometry blocker. Apple typecheck and Native verification of the candidate are NOT_RUN.

The first patch attempt was stopped by a strict source anchor before any file mutation. The corrected anchor and full inverse proof are retained. Original binary events, authentication/range receipts, unmodified frames and raw records are preserved; readable JSON copies are canonicalLF and gzip copies retain original bytes.
