# History Reader retains original Search presentation history

Root's integrated History remembered-position path retained the original root, window, Reader and Workspace, but did not retain the original Search presentation history. Opening and closing Saved Results could leave those other sources unchanged. This packet verifies the narrow source fix and the later unmount callback-order correction. It contains evidence only; root owns the actual Session edit.

## Exact compared source

| Variant | Full SceneSession SHA-256 | Actual result against this new contract |
| --- | --- | --- |
| Original combined Saved/History/Search source | `5d3c30b6a119ce445cc343b17ff7c3aad7e70a0bb49b9d56622007d6d3da91f8` | 6 passed, 15 failed |
| Initial publication counter fix | `bbf93e364f006428f1db86de7845ab1f6ecb4a2bfca0366c3ea00246c65e3ea7` | 20 passed, 1 failed |
| Counter plus invalidation before original unmount callbacks | `a77dd4223cf3a9c8336d405e45690b02016a022031b9002a5b97bb795650a4d9` | 21 passed, 0 failed |

All three capsules compiled and ran with the recorded Swift 6.4.3 compiler. The initial source did not contain `retainHistorySearchPresentationObservation`; no replacement helper was invented for it. Its actual `captureHistoryReaderWindow`, original presentation callbacks and full `unmount` body are compiled. The new-contract failures are not historical native failures or a reclassification of previous acceptance.

The intermediate source's sole failure is precise: its full original `unmount()` called the first external retirement callback while `mounted` was still true and the Search publication revision still matched. That callback could validate the retained History observation. Moving the passive counter publication immediately after the original mounted guard makes that same callback reject. All original UI/retirement effects and their order are unchanged.

## What the controls execute

The capsule copies the exact original methods without modifying their bodies: `observeSearchPresentation`, `originalSearchPresentationWillChange`, `removeSearchPresentation`, `captureHistoryReaderWindow`, and the full `unmount`. The two candidate variants additionally compile their exact monotonic counter and retained observation helper. Every method is hashed against its full retained source in `inputs/SOURCE_INPUTS.json`; the extraction script is included.

The 21 controls cover stable absent/current owner; same-owner re-observation; wrong-owner notification/removal; original State open/close and equal publication; owner A→B→A and disappearance/rejoin; an already blocked presentation; blocker callbacks that publish State or replace the owner before returning false; invalidation before the original entry, replacement, removal and unmount callbacks; terminal revision exhaustion; the full caller's first window capture and its final window/readiness callback joins; and unchanged original callback ordering.

`OriginalStateBoundary` is an explicit Bool fixture that invokes the real original Session pre-mutation callback before writing. It does not claim to execute SwiftUI's Binding or sheet presentation. The exact original UI caller bodies and their source hash are retained in `SOURCE_HUNKS_VERIFIED.json` to show that the production wrapper invokes that callback before the original setter. Other app/window/store/backend/Observation dependencies are declared stable boundary fixtures. The result establishes this counter and callback lifetime contract, not the entire Session, original database, UIKit or Core execution.

The baseline fixture has an unused revision seed slot only so the same exhaustion probe can compile; its actual original caller never reads that slot. The initial source therefore cannot satisfy the new exhaustion contract. The intermediate-to-final unmount failure is a separate actual source counterexample, with the same callbacks and proof.

## Evidence and limits

The actual job `job_914857bd3d59` exited zero after compiling and executing all three variants. Its exact commands, PIDs, timings, stdout/stderr and failed cases are in `evidence/`. The final RESULT SHA-256 is `4faaf2f3c647a2cac66d46c565b0767032afee7898290dcc92501ed46aceed3f`. The transferred raw output archive is 6,071 bytes, SHA-256 `e461c65920f2d65cfd221f310f36341f973350d61a08f200a8cda2fe7da6172c`; all members were rehashed after transfer.

The exact execution controller and transport inputs are preserved. The compiler reused only this lane's private Saved Results Foundation cache. Final combined task footprint was 46,227,456 bytes, below the 100 MiB cap; free rootfs was 2,600,660,992 bytes, above the 1.25 GiB floor. No other cache or source tree was cleaned or modified.

This is source-only verification. No Apple SDK build, Core effect, simulator, system intent, production corpus or device run occurred. Original Native116/Release114 results, all original assertions, owner signatures and source gates remain unchanged. Root still must integrate the exact Session bytes and complete the original final product qualification.
