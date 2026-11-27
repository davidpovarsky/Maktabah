# Independent root integration source review

Reviewer: `/root/reader_perf`. This is a bounded independent read-only source
review and a mechanical structural comparison. No controller was executed or
imported. No test suite, child-process lifetime exercise, Apple tool, native
UI case, Simulator action, network window or corpus query was run. The only
new files created by this documentation task are this file and
`ROOT_PRESERVATION.json`; existing source and documentation remain unchanged.

## Exact reviewed integration source

| File | Final reviewed SHA-256 |
|---|---|
| `production-study-v40-ui.py` | `887196e04b721491e629afba55ed239533d78b1f5e3da7004e9c6cf21a5f3755` |
| `study-ui-pending-execution.py` | `92815771c88138601ba2feed379d7a665c5f00a14c6f27478e14c55319045340` |
| `study-ui-prerequisites.py` | `7922abf4c56a0729c5dbe6ede6e627ac3644082a2a4f9e75ee212a7bbeedc2a6` |

The pending execution helper was first reviewed at
`2b17086b5093e622869f3a7747d4e3ee9c0e97293d039173b149256ab834b14b`.
The final `92815771` correction was then read independently: the existing
observer/collector receives the fresh original core, while source compilation,
native test/export commands and original URL transport use the owned runner.
This keeps metadata queries under the joined original observer/writer lifetime
and outside the finite 128-entry native/compiler/export command inventory.

## Review scope and finding

The review followed the Settings prerequisite before simulator lifecycle/image
installation; immutable current source/build/runtime/installation joins; the
original file-based native verifier; pending host/capture/attachment/cleanup
joins within one phase directory; and failure cleanup before simulator
retention. It inspected pre-spawn attempt rows, retained actual handles,
once-only cleanup attempts, unknown-spawn failure states, original kernel
identity checks before process-group probes/signals, and observer/writer exit
proof. An absent or reaped original leader does not authorize signaling an
uncertain remaining group. A failed or unavailable receipt cannot authorize
simulator handoff.

**The sole new concrete finding was a historical manifest path dependency.**
In the reviewed pending producer/validator, initially read at
`d394bdde2f3dfabce33a0ad3ecdc2efc393992eb1be79d249391e651f33d5236`,
`RetainedPendingEvidence.admit()` reread `admission["installationManifest"]`
from its original live Simulator data-container path. A later legitimate
XCTest container relocation could make that historical prerequisite fail even
though the original source/native/capture evidence remains intact.

Library confirmed the finding and owns its correction: retain an immutable
copy of the verified manifest bytes during the actual producer run, bind the
copy's complete size/SHA to the original admission witness, and read the copy
when reconstructing historical evidence. Current live owner/manifest admission
remains separate. **The correction remains pending final source/receipt
readback in this review.** This document does not approve an unreviewed final
helper or assert any actual relocation, native execution or runtime success.

No additional concrete blocker was found in the reviewed source paths.
That observation is limited to this source review. PERF01–03 still has no
admitted complete producer contract in the prerequisite helper; pending-fetch
correctness, raw host receipts or claimed status cannot satisfy that gate.

## Mechanical preservation against the actual original controller

The original local controller is
`reader-perf01-matrix/original/Scripts/CI/production-study-v40-ui.py`,
45,455 bytes, SHA-256
`ce7a88497818eb828592c205be2ca8500522ef1e97d8b3da8dadbca77d69e248`.
The compared final controller is 61,274 bytes with SHA `887196e0` above.
`ROOT_PRESERVATION.json` retains the full original/final file witnesses,
per-phase values, source fragments and comparison results.

Python `ast.parse`, source-byte slicing and a narrow literal-only AST evaluator
were used; neither file was imported. All eleven original `PHASES` entries
remain equal, including exact ordered selectors, XCTest allowances, runner
input sets and payload budgets. Their relative order is unchanged. The only
new entries are `offline-zayit`, `offline-otzaria` and `reader-pending-sql`.
Every original pre-Settings study phase remains required. Pending SQL is added
to that map, while the two offline phases use the separate complete offline
suite prerequisite.

The complete original verifier tail, from its zero-skip argv through the
original result write/return, is byte-identical and AST-identical after its
move to `verify_original_case`. The exact xcodebuild argv is AST-identical.
The ordinary host timeout remains `allowance + 600`; only the explicitly
coordinated offline call may use a smaller remaining host window. The original
XCTest allowances are not changed by that outer resource bound.

Fourteen original definitions are byte-identical. `source_context`,
`run_original_case`, `execute` and `main` are correctly reported as changed;
this packet does not repeat an older claim that all fifteen helper definitions
remain unchanged. The source-context adjustment preserves the original
validator and binds its enriched pending-phase context before and after.

The original `load_core` definition is byte-identical, and this scoped root
candidate contains no common/v32 replacement. The JSON identifies the retained
original common/v32 snapshots without executing them. It also confirms that
the two original full-v40 selectors and the original Reader workload values
are unchanged in the supplied before/after v40 input files. This is local
structural nonmodification evidence, not a new whole-repository Git diff,
qualified build, source-freeze completion or native acceptance claim.
