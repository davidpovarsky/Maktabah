# N detached-owner correction and joint P dependency

Scoped candidate following independent P/manager review of N7be2aba. N correction is `d9310293`; joint source merge is `98e6c7b94fd5e4c06b83cdda57cd6c9d9f41db6e` with immutable P `050031fac1bb21f738048beb8b5d011d5d0a6b4d`. Source acceptance remains subject to the manager's joint review and real producer/native gates. No current app/handler/Global Search source, native run, producer or public enablement is changed.

## Reproduction and correction

P's independently executed two-method review of exact N7be reproduced one pre-apply defect: a synchronous backend callback after beginObservation unregisters the driver; Core's guard succeeds and N invokes the detached driver's apply once. Final acknowledgement was correctly refused, but that refusal was too late to prevent the effect. P's exact fixture/red log are retained in the immutable dependency, without inserting the review test into N's worktree or an app target.

N independently extended the reproduction across all three backends and three owner changes: detach, replacement driver and re-registration of the same object. Same object identity alone is insufficient because its original active dispatch was removed. N also exercised original reader execution ownership at its initial backend read and inside the actual Core-delivered sink, plus revocation from a final synchronous backend getter after the Core operation had returned. Baseline: **4 distinct methods / 22 expected assertion failures / 0 compiler warnings**, raw `N-detached-owner-before.log`.

The narrow dispatch correction is immediately AFTER `prepared.authorizeCommit` and BEFORE `didDispatch`/apply: synchronously require the same live driver object, the ORIGINAL dispatch token, active/unapplied/unacknowledged dispatch state, and any original reader execution ownership. There is no await, re-preparation, remount, replacement driver, re-admission or retry in this refusal path. A consumed grant can safely be refused before native apply. Observation cleanup still runs; original borrowed admission remains with its caller.

Reader execution now retains the original driver/request/token in its existing bounded in-flight slot. Unregister retires that slot as invalid until the original call finishes instead of deleting it and permitting an unnoticed replacement. The actual reader sink checks that same slot before observation, after preparation, immediately before apply and after final completion validation. The caller checks it around its existing scope/Core awaits. Late cleanup only removes its own token; it cannot repair or take a replacement owner. The slot remains flow control, not another permission authority or tab reservation.

The separate N wrapper freshness check now obtains the synchronous backend snapshot BEFORE reading N's concrete native authority. Previously that getter could revoke the native owner after N had already captured it, allowing a completed result to escape the final scope-return check. The concrete N native getter reads its admission storage without an external callback; no P source was edited to fix this N wrapper. The new controlled regression triggers the backend callback after outer-scope cleanup and refuses completion as `native_effect_uncertain` after the existing one effect.

Predispatch detachment causes zero native apply and a stale refusal; it is not mislabeled as an already-applied effect. Existing postdispatch failure paths retain `native_effect_uncertain`. No rollback or side-effect absence is asserted after actual apply.

## P dependency and absolute budget

P owns the separate generic Core read-order fix. Its final immutable guard brackets native ownership with two reads from the SAME synchronous backend source and requires both exact invocation/backend/generation/Embedded epoch observations. N consumed only that published immutable packet. P's intermediate one-way reorder and its lost reverse-direction generation/epoch controls are explicitly rejected historical candidates, not final proof. P's final85-method UIRouting result is P evidence, not newly executed N coverage.

The original absolute cooperative scope and retained P guard remain required. Core computes its relative deadline at actor start; scheduling delay may make that relative deadline later than the original import deadline. Rounding remaining milliseconds down does not remove that scheduling interval. The P-owned controlled-clock test simulates original3e9, actual delayed Core relative4.9e9 and sink attempt3.1e9, and requires zero driver effects under the retained original guard. It is not measured queue latency, a hard real-time timer guarantee or native behavior.

## Execution and scope

N's four focused regressions pass after its correction; the full host package passes **84 distinct XCTest methods / 0 failures / 0 compiler warnings** both before and after consuming immutable P050. The prior80 are included, not added. Exact code inputs/log hashes/methods and the isolated P review result are recorded in `N-detached-owner-joint-report.json`.

The joint isolated snapshot is an exact archive of the committed Host/UIRouting/Actions inputs at98e6c7b plus ONLY the unchanged P review fixture copied into its temporary test target. `N-detached-joint-inputs.json` records102 input hashes, fixture Git identity and a short dedicated scratch path. Its two selected review methods are separate supplemental evidence, not a relabeled86-method product suite. The actual review execution result is recorded after completion; no pass is inferred from starting it.

These are portable Windows Swift6.3.3 tests with synthetic native driver/model/clock over actual N/Core/P code. Finite observation checks do not certify arbitrary mutually mutating authority callbacks or cross-source atomicity. New Apple SDK/native/physical acceptance remains NOT_RUN. The real R producer and any exact manager-reviewed native setter hook remain pending; helper, readerPlan, v2/content/newTab remain inactive. Source HOLD is not lifted by this report alone.

No R producer/shared model, P source beyond consuming its immutable dependency, app Integration/current URL/Intent, native project/deployment, Search, runner/workflow, signing, release or live-user data was edited. Current separate Search run43744659996 is terminal compiler-failed/18NOT_RUN from the manager's report; N did not poll/watch/retry/cancel it or the old run.
