# Focused source review

Reviewer: `/root/reader_perf` (same development session).

Reviewed exact sources:

- `study-ui-offline-oracle.py`: `14cdb114a733c698d99b98c290619ec42a8c72beebbad5ab968d105e33e336ee`.
- `study-ui-offline-exercises.py`: `d0431a3a58b9e30cd3195744df8bd745c80ee5622261f650da09d603242ae45b`.

The reviewer confirmed in the inspected source that the main/RPC attempt ledger precedes Popen, known handles sweep once, unknown spawn/failed RPC cleanup stay unverified, and the final readback RPC invalidates the earlier cleanup receipt and is included in the final one. The failure interrupt uses the known original remote boot/binding independently of the old SSH connection's liveness.

The review also confirmed that every original group probe/signal rechecks the directly created child identity, absent/reaped leaders allow only a signal-0 absence probe, uncertain remaining groups receive no signal, and the original subprocess helper is reached only after reaped/absent proof. No additional concrete blocker was found in those scoped fixes.

The review performed no tests, process actions or edits. It is independent source review only; it does not qualify an actual no-denial exercise, network window, Mac run or native offline case.
