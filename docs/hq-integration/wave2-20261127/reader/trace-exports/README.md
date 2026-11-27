# PERF-03 trace export preparation

This is a source-only checkpoint for a new additive host helper,
`Scripts/CI/study-ui-trace-exports.py`. It does not change application Source,
`AppleTraceCapture`, the common/v32 driver, the existing v40 wrapper, the nine
per-book/mode cases or the pending-SQL/offline controllers. It has not run an
Apple tool, recorded a trace, executed a native case or queried the corpus.

## Original requirement and remaining gap

The original [PERF-03 task](https://app.asana.com/1/1219597879016953/project/1219602719070493/task/1219613651433098)
requires the original UIKit/TextKit Reader to render complete large units with
correct selection, annotations, search highlights, footnotes, niqqud and RTL,
without hangs or viewport/scroll resets. It requests Instruments evidence,
p50/p95, CPU and the longest main-thread slice. It allows pure preprocessing
off main while keeping UIKit/TextKit on main. The task specifies no numerical
main-thread, FPS, latency or MainActor-percentage acceptance threshold.
`ORIGINAL_REQUIREMENT.json` retains the fresh original task text and identity.
Physical-device follow-ups remain separate; this helper does not redefine
PERF-04 or close an original UI requirement.

Existing source-qualified resource epochs and route receipts can retain
observed CPU, sampled RSS and explicit visibility/interaction upper bounds.
The per-book/mode source checkpoint declares six cold/warm pairs per cell,
with empirical nearest-rank p95 equal to the maximum for n=6. None of these
observations alone establishes continuous main-thread execution, MainActor
execution time, layout hitch coverage or every displayed frame.

Three exact installed Apple schema-declaration snapshots were read from the
root-owned `xctrace-schema-inspection` packet and checked against its actual
path/size/SHA metadata. These are declarations, not exported trace rows:

| Actual declaration | Relevant observed fields | Qualification still needed |
|---|---|---|
| SystemTrace `thread-state`, `context-switch` | Process/thread, state, start/duration, running and waiting time | The actual row/reference structure, interval state meaning, exact app/main-thread identity, complete coverage and trace clock mapping. A main thread's running interval does not equal a Swift MainActor job or all UI blocking. |
| Runloop `runloop-events`, `runloop-intervals` | `is-main`, process/thread, interval type, start/duration, nesting and end reason | Actual interval types and nesting semantics. An inclusive run-loop interval can include waiting; its maximum cannot automatically become the longest active main slice. |
| Hitches summary/lifetime/CA/render tables | Hitch/frame/context identifiers and durations; process/thread in some related tables | Genuine process/context/frame joins and event/drop coverage. Summary rows have no direct process column in the retained declaration. Hitch events do not enumerate every presented frame and cannot alone yield FPS. |
| Swift Tasks/Actors/Executors | No corresponding exported table schema is present in the retained three inputs | Inspect the actual TOC and raw rows before writing any decoder. Instrument names or Time Profiler stacks do not establish actor execution intervals. |

The retained host-only Python schema attempt is explicitly disqualified from
Maktabah evidence. Its driver failed with exit 1, its result file is absent,
and the numeric recorder exit code remains unknown despite the saved trace
and record log. The later TOC attempts stopped before exporting. The root's
failure packet, original integer clocks and raw files remain unchanged. This
helper cannot admit that packet as an original v40 capture.

## Admission and API

`plan(request_path, repository=actual_checkout)` reads a fresh request with
schema `otzaria.original-trace-export-request/1`. The request is an input
selection, never an approval or performance receipt. It contains:

- `producer`: exactly `full-v40` or `per-book-mode-cell`.
- `original_result`: the actual original full-corpus `result.json` or original
  per-book cell `RESULT.json`, as an immutable `{path, bytes, sha256}` witness.
- `capture_start` and `capture_result`: the original files at that result's
  exact `traces/capture-start.json` and `traces/capture-result.json` paths.
- `instrument_inventory`: the original `actual-apple-instrument-capabilities.json`.
  For a mode cell this is in its parent matrix directory, matching that producer.
- `epochs`: every original file in that result's `resource-epochs` directory,
  with its actual immutable witness. No selected subset can hide a failed epoch.
- `tables`: a list of full `run_attributes` and `table_attributes` objects from
  the actual TOC. An empty list allows inventory only and cannot execute exports.
- Optional `installed_schema_snapshots`: witnessed original `schemas.xml`
  snapshots, retained as declarations only. They never prove capture coverage.

The planner calls the existing frozen source-context validator and checks the
current committed helper/common/cleanup source. It requires the original
result's source/image/corpus post-verification and producer cleanup, binds the
exact actual continuous-capture object, and checks its genuine ready/start,
stop, TOC exit and owned recorder-group receipt. A numeric recorder exit is
not invented: the existing capture producer's `GONE_CHECKED` group receipt is
the actual stopped-recorder authority. An absent or failed host-toy result is
not accepted as a substitute.

Every original trace member must still exist with its exact size/SHA and no
additional files, aliases or ambiguous paths. Stable file identity comparisons
exclude atime because a read can change it. Exact original app PID/executable
and recorded installed image identity bind every epoch; original monotonic
and integer wall-clock anchors and all sample files remain referenced. No
conversion from trace-relative time is calculated. The separately retained
SQLite collector's Mach brackets remain its own evidence and are not relabeled
as a trace clock calibration.

The planner inventories only actual `trace-toc/run/data/table` nodes. Full
observed attributes, escaped as literal XPath values, select one exact stream.
The selector also requires the exact number of attributes, so a table whose
attributes are a strict superset cannot be silently combined with another.
Missing, duplicate or ambiguous streams are refused. No hardcoded run 1 or
guessed Swift schema is substituted.

## Later explicit export, still without metric acceptance

`execute(request_path, repository=..., output=..., output_budget=...,
free_reserve=..., child_seconds=..., total_seconds=...)` is a separate explicit
Darwin operation. It creates only a fresh export directory, reads actual tool
identity/version, compares it with the recording's original tool inventory,
and invokes `xcrun xctrace export` for the exact selected XPath. It cannot
record, launch an app, manipulate a Simulator or alter network policy.

The caller must explicitly supply storage, free-space and time reservations.
These are host resource bounds, not performance SLAs. One exact created
subprocess group is owned at a time. A crossed deadline/cap stops only that
owned group, records its actual original cleanup and observed exit, and
retains complete or partial raw outputs. A session already out of time cannot
start another child. No failed trace/XML is trimmed, replaced or converted
into an empty successful metric. Finalization and cleanup evidence may grow
beyond a crossed output cap; those bytes are preserved.

Raw XML is inspected in a bounded streaming pass for structural inventory
only. A count of XML elements named `row` is labeled as that exact observation;
zero elements is not asserted to mean zero events, hitches or frames. Namespace
or schema interpretation, reference resolution, loss/drop coverage, app/main
thread attribution and clocks still require real exported data and a separately
reviewed adapter. The result always contains an empty `metrics` map and
`performance_acceptance: false`. The best successful export status is
`RAW_EXPORTS_RETAINED_METRICS_UNQUALIFIED`.

All original source/receipt/trace/epoch inputs are reread after exports, and
the actual exporter binary/location is rechecked. Raw outputs, commands,
actual return codes, original owned-group cleanup, clock witnesses and final
failure status remain available for review. An original UI failure remains
visible in `original_result_status`; exporting its valid stopped trace does
not turn that native result into a pass.

## Checks actually performed

Local Python parsing passed. `CONTROLS_01.json` retains the first 47 source
controls. After strengthening integer tool-exit admission, preserving an
aborted exporter's observed return code and testing exact XPath attribute
matching in the local lxml interpreter, `CONTROLS_02.json` passed 49/49.
Both receipts are source-only. The latter includes the original 47 boundaries
and two actual local XPath-interpreter checks; it is not evidence that Apple's
exporter has executed or accepted this selector on a recorded trace.

Controls cover capture/ready/recorder identities, missing and ambiguous tables,
run selection, literal XPath quoting, duplicate/nonfinite JSON, typed clocks,
PID/executable and epoch bounds, exact tiny local file membership/aliases,
malformed/partial XML, preserved output on a synthetic byte-cap failure, and
no child launch after an expired deadline. Popen/cleanup in those lifetime
controls are explicit deterministic doubles. Only tiny local scratch files
and the already retained installed schema snapshots were read or written.

There were zero Apple tool invocations, zero native cases, zero production
corpus queries and zero actual exported trace tables. Full PERF-03 remains
open until the qualified original UI workloads, actual trace data and their
correct metric interpretation exist.

## Follow-up: direct-child cleanup ownership

Root's review identified two concrete gaps in the first checkpoint
`4f3b3e21305cb7bab1e629378dd720c143c28c22`. After `Popen.poll()` or `wait()`
reaped a child, the original group helper sent its first signal without
checking whether that PID had been reused. Also, an interruption inside
`Popen` before assignment was incorrectly labeled as no child created.
The original helper and all common/v32 sources remain unchanged.

The new exporter retains the exact launch argv and parent before attempting
creation. It records the created child's actual parent, start time, command
and process group with a bounded original Darwin `ps` query and an unreaped
direct `Popen`. Normal `xcrun` to tool `exec` transitions may change the command;
the observed commands are retained while PID, parent, start and group stay
bound. Before **each** original group probe or signal, a guarded callback
checks those same identities again. A later live process at a reaped PID is
refused, even if it resembles the launch command.

When the original leader has already disappeared, only signal 0 may check
group absence. A remaining group without a verifiable original live leader
cannot be adopted or signaled: cleanup stays unverified. This deliberately
does not infer that surviving descendants or a recycled group belong to us.
An interrupted start without a returned handle also stays unverified and
does not authorize any PID search or later cleanup. A failure before the
start attempt is separately recorded as `SPAWN_NOT_ATTEMPTED`.

`CONTROLS_03.json` retains the 49 general source checks on the updated helper.
`OWNERSHIP_CONTROLS_01.json` adds 20 targeted synthetic checks: changed
PID/parent/start/group, a replacement appearing between signal and probe,
leaderless groups, permitted same-process `exec`, initial identity-read
failure, expired admission, interrupted spawn, and bounded `ps` parsing.
The same two original defect scenarios reject the original helper from
`4f3b3e` and pass against the candidate. All `Popen`, kernel inventory and
signals in these controls are deterministic doubles. No process was
actually started or signaled, and no Apple tool or native case was run.

To reproduce the before/after comparison, extract the original helper from
that exact commit into a separate file, then supply it as `--baseline` to
`ownership-controls.py`; supply the candidate as `--helper` and a fresh
receipt path as `--output`. The original baseline bytes/SHA remain in Git
and in the comparison receipt, without replacing either historical source
control report.
