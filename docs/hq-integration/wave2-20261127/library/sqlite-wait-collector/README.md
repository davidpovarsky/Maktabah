# Retained SQLite fetch-lock companions for the original v40 host

This checkpoint adds only `Scripts/CI/study-ui-sqlite-wait.py` and evidence/docs.
It changes no product Source, common/v32 driver, v40 wrapper, UI test, SDK,
simulator, corpus or root study controller. The integration owner must explicitly
compose it in the **v40 execute path only** after reviewing the hooks below.
Importing the helper or running its component parser does not install hooks.

The instrument is the actual DEBUG source from
`0b445db8a8ee5bc53a1a729c9b65693b51cc88fe`. Its original passive schema remains
authoritative. A retained observation and a fully attributable resource epoch
are different states. Neither constitutes PERF acceptance.

## Exact integration API

| API | Where the v40 owner calls it | Effect |
|---|---|---|
| `bind_admission(core, retained, original_call, config, udid, build)` | Around the existing bound `RetainedV40Installation.admit_current_installation` | Captures MCM/database/manifest/native-image file identities immediately before and after the original full hash/count/image verification; returns the original tuple with an additional immutable `sqlite_wait_admission` witness. No second database hash. |
| `observation_host(previous_host, core)` | After the v40 natural-target host subclass is installed | Returns a composable subclass calling `super`; its methods are `__init__`, `begin`, `validate_source`, and `run`. There is **no `end` override**. |
| `validate_snapshot(value, request_id=..., process_id=...)` | Bounded native input parsing | Validates the original shape, timestamps, identities, capacities and counter invariants, retaining loss/unavailable/active states. It does not grant UI/corpus/epoch qualification. |
| `evaluate_epoch(baseline, end, epoch, database, resolution_ns=...)` | Internally, only after current source/identity validation | Returns explicit coverage or reasons for `NOT_QUALIFIED`; no elapsed-minus-CPU estimate or invented threshold. |

Illustrative integration, not applied by this checkpoint:

```python
# Existing v40 execute setup, after its natural-target host composition.
retained = RetainedV40Installation(core, owned_udid, original_install_result)
original_admit = retained.admit_current_installation

def admitted(config, udid, build):
    return sqlite_wait.bind_admission(
        core, retained, original_admit, config, udid, build)

retained.admit_current_installation = admitted
core.REUSED_INSTALLATION = retained
core.ObservationHost = sqlite_wait.observation_host(core.ObservationHost, core)
```

The original full-v40 source freeze must include the helper and all six paths in
its `SOURCE_PATHS` tuple. The ordinary `source-before.json`, original current
build receipt, exact native image closure and original retained installation
admission must exist. Generic `load_core()` consumers such as Groups/study setup
must remain unaffected. The owner also needs to retain the helper's complete
output tree alongside the original xcresult, zero-skip and trace evidence.

## Identity and lifecycle

The admission hook brackets the **existing** original v40 database hash, SQL
counts and installed-image verification with actual file witnesses. It binds
the official 4,355,063,808-byte database SHA-256 `8389709c…`, original installation
manifest, source/build receipts, actual main app and SDK native images, and
original MCM application/storage ownership. The existing Settings helper's
read-only MCM discovery is reused.

Subsequent captures recheck current MCM ownership, corpus device/inode/size/
mtime/ctime, manifest bytes, source/build inputs, installed image identities and
the exact live executable/PID. A later stat is never presented as continuity
with an old unbracketed hash. Any MCM/path/inode/image change requires fresh real
admission. This checkpoint does not automatically relocate a container or
rehash/relabel a copied database. Original same-source runner/SDK/post-UI image
and full database checks remain owned by the original driver.

The host is constructed before XCTest launches the app, so its initial check
does not assume a live PID. PID checks begin with actual original requests.

### Optional baseline before original begin

Only while both resource and Inspector fences are idle, and only after an actual
validated source request has established a constrained viewport basename, the
collector can issue a fresh UUID through the original `.request` protocol.
It writes no workspace/default/SQL/selection state and performs no navigation.
Only the exact owned request inode/bytes/UUID are retired afterward.

The original observer must answer with one mounted Reader. The source comparison
uses the unchanged `exact_source_comparison` against actual known catalog
targets. The original warm reader case deliberately navigates away before
`begin`; its known away target is only the first candidate, never a guessed
acceptance. Actual UTF16 length filters candidates; actual source file hashes
and the original UTF8/range comparison determine a match. At most 64 catalog
targets and 64 MiB per source reference are eligible. Natural source hardlinks
are allowed when their regular canonical path has the original catalog as its
direct parent and its original hash matches.

No matching source, an unknown basename, or an unmounted/hidden reader leaves
the baseline unqualified. Valid legacy navigation does not become an additional
UI failure. A new PID can qualify only by answering a **new actual request**;
an older PID's snapshot is never reused. The initial cold open may still have
no baseline. This helper does not infer a process-start baseline from an end
snapshot, even if that snapshot says complete lifetime history.

### Existing end ACK and post-ACK capture

The original `begin`, `end` and their ACK semantics are preserved. In particular,
there is no extra source/cache/request probe before the resource-end ACK.

`validate_source` first copies the bounded actual request, viewport and companion
to a fresh per-UUID evidence directory. The original method then validates the
source/workspace/route/epoch and retires its own request. Only after that success
does the helper qualify the retained capture. All this precedes the validation
ACK and the next overwrite. If an actual fresh companion is malformed or has a
wrong digest/schema, its safely bounded original bytes are retained **before**
rejection. Failed comparisons remain separate receipts; no stale companion can
replace an `UNAVAILABLE` descriptor.

## Clocks and coverage

Runtime qualification requires actual Darwin CPython >=3.10 reporting
`mach_absolute_time()` as its nonadjustable monotonic implementation. Native
`mach_absolute_time`/`mach_timebase_info` calls bracket actual `monotonic_ns`
values. The exact timebase and integer-conversion bounds are recorded. No such
native runtime call was executed in this checkpoint's Linux controls.

Apple documents DispatchTime uptime nanoseconds as converted Mach absolute time:
[DispatchTime init(uptimeNanoseconds:)](https://developer.apple.com/documentation/dispatch/dispatchtime/init(uptimenanoseconds:)).
Python documents its macOS monotonic implementation and cross-process behavior:
[time.monotonic](https://docs.python.org/3/library/time.html#time.monotonic).
Those contracts do not replace actual runtime checks.

Each actual app snapshot must also lie in a genuine request/response bracket:
the optional baseline has a host Mach sample before writing its fresh UUID and
another after reading the response. For the original post-ACK source request,
the lower bound is the actual completed host resource epoch and the upper bound
is the actual companion read. The unchanged original UI producer waits for that
end ACK before writing the new UUID; original validation must succeed. The
helper does **not** convert XCTest `ProcessInfo.systemUptime` to host time or use
filesystem wall timestamps to calculate lock waits. Original float monotonic
epoch endpoints receive outward rounding/resolution bounds.

Coverage requires:

- Validated baseline and end captures on the same admitted source/build/owner/
  corpus and live PID, with distinct UUIDs and actual native clock brackets.
- Snapshots surrounding the original completed epoch, no counter overflow,
  monotone lifetime counters, and no unresolved active operations at either
  snapshot.
- Zero lifetime drops and unmatched completions at the baseline, every new
  sequence retained, no intervening loss, and complete terminal accounting. A
  capacity-dropped operation from before the baseline could still be running
  invisibly; unchanged counters and empty active arrays cannot exclude it.
  Earlier completed-ring overwrites are separately admissible only with all
  new sequences retained and exact overwrite accounting.
- No operation crossing an uncertain epoch boundary; every included operation
  has a native thread ID and the exact admitted full-v40 opened-file identity.
  Other/unknown in-epoch database identities remain unqualified and are not
  silently filtered from the measurement.

Qualified outputs retain acquired-lock wait and observed unacquired wait
separately. Cancellation flags are not error classifications. A true empty
interval can yield zero only after all real fences and sequence checks pass.
Pending, missing or ambiguous evidence has no `metrics` object. Measurements
describe the instrumented Debug `fetch` serialization lock, not SQLite engine
busy wait, query duration, UI responsiveness or a performance SLA.

## Output and bounds

Under the original v40 output directory, `sqlite-fetch-wait/` contains:

- `admission.json` and `host-clock.json`.
- `captures/<UUID>/`: exact request/viewport/companion, pending receipt, original
  validation or baseline comparison, and qualified/rejected capture receipt.
- `epochs/<UUID>.json`: explicit coverage decision; absent end captures and
  aborted/missing epochs stay unqualified.
- `RESULT.json`: immutable input links, all successful/rejected capture
  references and per-epoch receipts. `full_performance_acceptance` is always
  false. A finalization failure sets the original host's `error` field and writes
  a separate failure receipt, so it cannot disappear as a daemon-thread error.

Limits are 160 captures, 192 MiB aggregate retained raw bytes, 1 MiB per native
companion, the original host's 32 KiB viewport bound, 2 KiB descriptor, and a
three-second optional baseline wait. Evidence paths must be regular canonical
files with no symlink ancestors; lengths, SHA-256 and stable read/path identities
are checked. Existing evidence is never overwritten.

## Capture budget from the actual current source

The bound is retained at **160**. The actual source at
`dc609b080b388966e2e6ade58127c2da6d123f46`,
`Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift`, SHA-256
`36e4b5bb0e244484cd152de8ae92823838772d5f90cc780aa85efbf7e6b4af66`,
implies the following conservative maximum. This is source accounting, not an
executed native schedule or proof that the baseline requests will succeed.

| Original workload | Post-source captures | Optional pre-begin baselines |
|---|---:|---:|
| 20 Reader opens and 20 before/after forced-restore proofs | 40 | 40, for 20 opens plus 20 overview interactions |
| 9 Inspector exploration visits and 3 scale visits | 24 | 15, for 12 opens plus 3 scale scrolls |
| Total | 64 | 55 |

This yields **119** possible captures and 41 spare entries. Unknown or unmounted
baselines reduce the actual count. Inspector `.observation.json` requests are
not SQLite viewport captures. The exact four source fragments and their hashes
are retained in `CAPTURE_BUDGET_SOURCE.json` and the archive. A changed natural-
target schedule or new workload must be recounted before execution.

## Verification performed

Final Linux source controls: **90/90**. Thirteen inputs are the exact retained
actual Apple component snapshots/companion from `0b445db8…`; their original
`TRANSFER.json` and original native `RESULT.json` bind the bytes. The active-bound
input remains explicitly synthetic recorder admission from that original run.
All 13 are parser-compatibility inputs only, never production or UI evidence.
The remaining controls use deliberately synthetic Python descriptor/epoch/hook
models and tiny temporary files, including the unchanged original source
comparator. They check stale identity, wrong length/hash/path, malformed current
evidence retention, loss/overflow/boundary semantics, legitimate away navigation,
and preservation of the original end ACK/error gate.

Attempt 1 recorded 80/81 because the test boundary supplied a relative output
path to the finalization-failure case; canonical evidence writing correctly
rejected it. Attempt 2 corrected that boundary to an absolute path and recorded
81/81. Attempts 3 and 4 added the fresh failure-retention and actual catalog
matching cases, recording 85/85 and 89/89 on their respective exact helper bytes.
Independent review then identified a genuine host admission defect: the initial
candidate allowed a nonzero prior drop count when unchanged at the end. A new
source-only counterexample models 64 completed tracked fetches plus a 65th
capacity-dropped fetch still running through the epoch. In the actual original
recorder, dropped `begin` returns no token and `finish(nil)` records no terminal
state. The old helper wrongly qualified an empty zero-wait epoch. Its retained
counterexample run is **89/90**, RESULT SHA-256
`f7eb10362fc96c1954d8bef8bc3f66289d51d171fd64356cd2e62a976aebe6ba`.

The correction requires zero prior aggregate, active-capacity, connection-
capacity and unmatched-completion drop counters. The same counterexample and
remaining controls then record **90/90**. This counterexample is a synthetic
source-state model of the actual recorder, not a real pending application fetch.
All prior receipts and exact input versions are retained, without relabeling.
The final RESULT SHA-256 is
`9f97ffb9156d77b5302f7ec2227912edc94951d40808594845ff15243517fc2f`.

The final helper SHA-256 is
`4e2421361013659285c67459601bc705c2d89a2b7abe2313a0a4974b0b34dcee`.
No application, Simulator, trace, packet-filter, production corpus, native clock,
SDK compile or full build was executed for this helper checkpoint. Full native
PERF qualification still needs the original integrated run and its independent
trace, epoch, corpus, correctness and resource evidence.
