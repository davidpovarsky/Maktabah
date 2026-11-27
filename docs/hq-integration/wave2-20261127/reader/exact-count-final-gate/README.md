# Separate exact-count final gate for full v40

The original Inspector observation host records natural workloads at least as
large as 100, 500 and 2,000 relationships. It separately reports whether their
actual cached counts are exactly those sizes. A successful native XCTest and
at-least observation completion do not alone satisfy the exact-size criterion.

This change adds `require_exact_inspector_scales` to the v40 wrapper only. The
native `execute` entry point calls it after the original controller has returned
successfully and finished its immutable source, database, image and cleanup
checks. The gate requires three distinct original observation IDs, actual and
requested integer counts of exactly `[100, 500, 2000]`, and the original host's
matching exact-count flags. It also requires the unchanged database/source and
successful cleanup fields from that same full-v40 result and an explicit owned
Simulator identity.

The gate writes a separate `v40-exact-inspector-final-gate.json` with `MET` or
`NOT_MET`, the hashes of the original result and scales receipts, the actual
counts, source attribution and UDID. `NOT_MET` makes the v40 execute entry point
fail. The two original receipts are never rewritten. A prior gate receipt is
never overwritten.

The original v32 file, both original v32 test bodies and the common observation
host are unchanged. The v40 `load_core` API and the `source-check` entry point do
not execute this new gate, so other controllers that reuse source/ownership
admission retain their separate explicit scopes. This check does not assert all
row bodies, performance thresholds, trace coverage, disk-cold behavior, a
physical device or overall PERF completion.

## Verification performed

`SOURCE_ONLY_CONTROLS.json` records 17 Python controls of this additional gate.
Inputs are explicitly synthetic host receipts. They cover rejection of at-least
counts disguised as exact, inconsistent count flags, booleans/floats, missing or
duplicated observations, failed original UI status, changed database/source,
cleanup failures, v32 relabelling and absent source/device identity. Every case
also checks preservation of the original input bytes and false full-performance
and full-row-rendering claims.

Re-run only these source controls with:

```sh
python3 docs/hq-integration/wave2-20261127/reader/exact-count-final-gate/check-exact-gate.py Scripts/CI/reader-full-v40-ui-observation.py
```

No native UI case, full-v40 catalog or full-corpus query was executed for this
checkpoint. No exact natural 100/500/2000 target has been qualified yet. Bounded
discovery remains pending a current verified source database location, followed
by original adapter and UI verification. The historical large-window and
prefix-body controls keep their original scope.
