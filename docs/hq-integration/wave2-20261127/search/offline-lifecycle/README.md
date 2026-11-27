# Original offline coordinator and exercise process ownership

This is a source-only follow-up to the explicit-checkout checkpoint. No Mac, SSH, PF, launchd, native UI, network denial, live process signal or no-denial exercise ran for these controls. The real owner window and original runtime acceptance remain pending.

## Concrete corrected paths

The coordinator records a spawn attempt before each controller/RPC Popen. It retains every returned handle before the caller can assign it. An interruption before a handle is returned stays unknown; it cannot produce a verified cleanup claim. Known handles are swept once even when the caller's assignment did not complete. A failed/uncertain stop is retained and prevents cleanup acceptance without a blind repeated signal.

The coordinator now aggregates RPC cleanup as well as the main SSH, relay and stream lifetimes. A successful early cleanup snapshot does not cover a later evidence-readback RPC: a new spawn invalidates that snapshot, and final cleanup includes all attempted/known children. Numbered immutable cleanup receipts preserve the earlier observations. The final result points to the final cleanup receipt and its history.

Failure cleanup can attempt the fixed, current source/PID/start/parent/argv-checked Mac interrupt using the retained original boot/binding even when the initial SSH has already disconnected. It never infers Mac transport restoration from local SSH exit. An unreachable or mismatched remote identity remains explicit and unverified.

The shared owned stop wrapper rechecks the original Popen, kernel identity and directly created process group before every original group probe/signal. When the original leader is absent or reaped, only signal 0 may prove that its group is gone. A surviving group receives no signal and remains unverified. The original subprocess stop helper is reached only after actual leader/group exit, making that call observation-only. The common `runtime27_interruption.py` is unchanged.

Both exercise/relay wrappers also mark attempted spawn before Popen. A failure with no returned handle cannot return a successful abort. These changes do not change original native selectors, source providers, lease durations, probes, root receipts or owner-acknowledgement requirements.

## Baselines and controls

`BASELINE_INPUTS.json` binds two complete gzip-preserved source baselines, including their compressed and uncompressed hashes:

- Coordinator commit `1d5140c271d3e666f4c631d40876ab812563ba10`, uncompressed SHA `7f40ce53485a56e327f6a09012066a8ee6d97dd4f0ce65363e30de8387110c9c`.
- Exercise ownership commit `8dba94565372a15fe232d8135e3d447494318c9c`, uncompressed SHA `c6a5b80c7015374b487dddb49b12cd1852c6d85ae90b468337b289fc9402c406`.

Twenty-six focused controls pass on coordinator SHA `14cdb114a733c698d99b98c290619ec42a8c72beebbad5ab968d105e33e336ee` and exercise SHA `d0431a3a58b9e30cd3195744df8bd745c80ee5622261f650da09d603242ae45b`. They execute the actual baseline/candidate Python functions with explicit synthetic child/kernel/SSH boundaries. The original unchanged interruption helper is exercised through those synthetic callbacks; no real signal function is invoked.

The retained baselines reproduce the interrupted main/RPC spawn being labeled clean, omission of a failed known RPC stop, skipping a bound remote interrupt after SSH loss, and group signals after leader reap. Candidate controls cover those counterexamples plus the caller-assignment gap, continuing cleanup after a separate failed child, no repeated uncertain stop, final readback ownership, normal original live-child cleanup, PID/PGID replacement, absence-only probes, no unguarded subprocess fallback, and actual flag placement before exercise/relay Popen.

Two development-control corrections are retained transparently: `attempt1-syntax.stderr.log` records a malformed multiline `with` in the new control script; `attempt2-*` records that the historical exercise abort returned its original `{verified: true}` object rather than the initial test's assumed `None`. The fixture expectation was corrected to that actual baseline result. Neither was a product/native failure, and neither is counted as a candidate pass. The final receipt is `SOURCE_CONTROLS.json`.

The reader lane independently reviewed the exact two final source hashes and found the reported lifecycle gaps closed in the inspected paths. Its review was read-only and did not run controls or confer runtime acceptance; `PEER_REVIEW.md` records that scope.

All preceding source, environment, API and historical control receipts remain retained. A genuine current-source three-exercise sequence, real private owner coordination, immutable original build/corpus/package admission and native offline windows are still required before any offline UI claim.
