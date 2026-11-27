# Actual Mac clock and retained exporter compatibility

This docs-only follow-up to `daccf4096eec0f1851cdb5c7bfd277916e9310c9`
records one authorized component execution at **2026-11-27 07:01:59 UTC**.
There was no compile, app or Simulator launch, production corpus read, original
Reader request, resource epoch or performance acceptance.

## Actual execution and source

The original retained `CatalystControls` executable was reused once, without
changing its bytes, from:

`/Users/m1/builds/otzaria-wave2-reader-controls-20261127/sqlite-fetch-wait-20261127T052034Z/CatalystControls`

Its 600,512 bytes hash to
`daa58a1b273fde2dee7c37c4965d3a9c8bfa1ef009f918cf2bde5d4c39fc4683`.
Before/after file identities and hashes agree. The ten original retained Swift
inputs were rehashed against the original actual Apple RESULT
`00a7e67662d7b3a92511be1a85d99dfad665e69f02acb80e9ece83391c37a7ee`.
That receipt's successful Catalyst compile command is copied into this RESULT;
its explicit app and unused-Zstd boundaries remain part of this component.

The argument was `companion-export <fresh-owned-fixture-directory>`, with
`CHAVRUSA_FULL_V32_SOURCE_OBSERVATION=1`. The existing original runner creates
one 8,192-byte three-row SQLite fixture, performs its original fetch, and
exports the actual passive companion. It also checks invalid-request and
missing-parent failures through its original exporter. It neither opens nor
represents the full production corpus.

The helper was the unchanged committed 58,976-byte source SHA-256
`4e2421361013659285c67459601bc705c2d89a2b7abe2313a0a4974b0b34dcee`.
The new component runner is retained verbatim in the archive, SHA-256
`3d48f72acb2a2e8a9b5819d215d204919f6fc5a84cd2931e3afe9b4762263c73`.

## Observed clock result

Actual **CPython 3.12.16 on macOS 27.0 arm64** reports nonadjustable monotonic
`mach_absolute_time()`. The helper calls the actual native timebase and Mach
clock, and its three startup samples each enclose the actual
`time.monotonic_ns()` observation. The actual timebase is **125/3**, with
a recorded 43 ns integer conversion allowance.

| Actual native clock observation | Nanoseconds |
|---|---:|
| Lower bound before the child starts, including allowance | 246734287465373 |
| Original companion snapshot | 246734429105458 |
| Upper bound after reading that companion, including allowance | 246734431892127 |

The one child PID was **91505**. Its original stdout and snapshot agree on that
PID; the snapshot has the fresh canonical UUID
`96FFC23E-CDAD-4C11-A47A-A6E181D632AE`. The unchanged helper parser accepted
the exact companion schema, original counters and file identity. The companion
has one completed fetch, no active fetch and no dropped operation. Its 1,700
bytes have SHA-256
`8523941a38f1a7bf73fd7ba6ae36864e10f2acafcbe19135437911084e809c03`.

This verifies runtime clock/exporter compatibility on this machine. It does
**not** qualify an app epoch or prove that a future request will be captured:
the full helper still requires its real MCM/image/corpus admission, original
source validation, fresh request brackets and complete per-epoch accounting.

## Storage, ownership and preserved evidence

The owner authorized this single component after the Reader owner confirmed
binary reuse and no own active job. Three fresh process inventories, including
one immediately before the native invocation, found no active compiler or
xctrace command. Free space was 11,494,531,072 bytes on admission and
11,493,736,448 afterward; this difference is host-wide and is not attributed
solely to this component. No cache or foreign output was modified.

The complete actual output remains at:

`/Users/m1/builds/otzaria-wave2-library-controls-20261127/sqlite-wait-clock-20261127T070159Z`

The raw actual RESULT is 13,467 bytes, SHA-256
`7cd69407ce116619ec41a7645a1f854f1e2c392e3a8a6c082aab765b1be60a30`.
`actual-apple-files.tar.gz` preserves all ten raw files, including the three
process snapshots, exact helper and runner, fixture, companion and stdout/stderr.
Its 126,027 bytes have SHA-256
`a70570e347acaec843a374abf0305392e9180d2f0872814cce6dc3a2dbfd13da`.
`TRANSFER.json` binds every archive member to its actual file bytes.

The first read-only evidence transfer reached the actual files successfully
but could not create the proposed Oracle artifact parent because ubuntu lacked
write permission. Nothing from the native run was retried. A second read-only
transfer wrote the identical evidence into this agent's owned worktree build
directory. `TRANSFER_ATTEMPTS.json` preserves that collection limitation.
