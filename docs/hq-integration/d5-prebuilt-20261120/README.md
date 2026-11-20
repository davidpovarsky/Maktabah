# Exact d5 Apple prebuilt binding — 2026-11-20

This change makes the focused Apple build consume the verified frameworks built
at `99f7927e4da72f2463417f5c2de2c4d20c6aa168`. The old
`41c278ac67f0c03e19270ed65b891b242a1a3f2e` producer and its original 265 engine
cannot qualify as the d5 engine. No application, original engine, SDK, Xcode
project, package lock, or resource source is modified by this change.

Implementation base: `c6467f29cc23de8f5125ded220063750611e84e5`.
The narrow gates and regression suite actually ran on Windows. **No Apple
compiler, application link, simulator, Native case, or device run was performed
for this change.** No workflow was dispatched from this branch.

## Producer and archive identities

Both frameworks belong to [run 44661774024, attempt 1](https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024/attempts/1),
whose overall conclusion is **failure**. The successful individual framework
jobs are the qualification boundary; the failed workflow is never reported as a
successful application build.

| Framework | Successful producer job | Artifact ID | ZIP bytes | ZIP SHA-256 |
| --- | --- | --- | --- | --- |
| Otzaria | [136041463727](https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024/job/136041463727) | 14596463166 | 201330360 | `efc73de90d74fdd380ffecfa334fe9dcece38519832b89cf3fb2a5741dcc25ad` |
| Zayit | [136041463406](https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024/job/136041463406) | 14595389912 | 123727544 | `64f4ba7b8d6cfced525732699fd1958ca0cc5ec836369dcf839d91df855914d7` |

The existing whole producer-tree check remains. Otzaria producer tree
`5a6c6501c021ffadcde31254239617f10cd1a362` has **43 prior entries**, all identical
in the current tree `424e157913f36db2b5cc4c6204056f56c3194dd9`. Its only additions
are **78 regular files** under `Vendor/OtzariaSearchEngine/Tests/OccurrenceSwift/`.
The explicit manifest pins every path, mode, type and Git blob. Modified,
deleted, executable, symlink, submodule, undeclared and out-of-folder additions
are refused. There is no blanket exclusion for a directory named `Tests`.

`Vendor/ZayitSearchPort` is wholly identical to the producer, tree
`a121537e72fb10ce7c710ad55f7d084a0427cf2d`. The Rust and Upstream subtree checks
also remain, and `rebuild_zayit_framework` is now `false`: the selected new
producer already contains the actual matching source.

The report explicitly attributes the binary to the **producer whole tree**.
The later application Vendor tree is a separate freeze; test-only additions do
not turn the old producer into a build of the future whole tree.

## Why the added test package is outside the app/framework build

The reviewed project references the Otzaria XCFramework and the two original
JSON resources. Its only filesystem-synchronized roots are `MaktabahTests` and
`Maktabah-iOSUITests`; neither includes the added Vendor test package. The
framework script runs three explicit Cargo release targets from `ios_bridge`.
Its Cargo manifest names the original static library and pinned upstream Rust
path. `build.rs` reads the original upstream commit/resource manifests and emits
build metadata; it does not enumerate or compile the added Swift package.

The manifest also pins the exact reviewed project, framework script, Cargo
manifest and `build.rs` blobs. Changing project membership or any of those
inputs requires another explicit exclusion review. This protects against a
later build change silently making a previously excluded file an app input.
The complete application `Source`, `Vendor` and Xcode-project tree checks are
retained unchanged in preflight. These are committed Git identities: the
original workflow's clean checkout and later actual-source byte verification
remain required. The added complete Zayit-tree check intentionally refuses a
future overlay even if someone switches the old rebuild option back on; that
would need another reviewed producer/source qualification.
The manifest digest covers complete UTF-8
text with LF line endings so Git's Windows CRLF checkout does not alter the
meaning of the pin; no JSON reserialization is used by this check.

## Restore-time metadata checks

Before downloading either framework archive, the actual restore path fetches
its artifact, exact run-attempt and individual job metadata. It validates:

- Exact artifact ID, name, byte count, SHA-256 digest and unexpired state.
- Exact repository and head repository, run, attempt, commit and workflow path.
- Exact successful, completed producer job and the required build, verification
  and upload steps; skipped/failed/missing/duplicate steps are refused.
- Artifact creation during the successful job's single upload step.
- The downloaded ZIP's exact SHA-256 before opening or extracting it.

GitHub artifact metadata does not contain a producer job ID. The gate combines
the independently pinned archive digest/identity with matching run/head,
successful named job, and upload interval. It does not claim a job-to-artifact
attestation that GitHub did not provide. Overall run failure remains in the
returned proof. Original SourcePackages, Embedded JS/resource identities,
Sefaria and Hanlin pins are unchanged.

## Executed verification

At 04:31:52–04:31:54 UTC, SentinelX job `job_c8584015acae` executed
**36/36 unittest methods**, with **52 successful named subcases** inside those
methods, zero failures/errors/skips. The original macro trust suite separately
executed **4/4 methods**. The source hashes before and after were identical.
The subcases are not counted as 52 additional test methods.

After removing final blank lines, the exact final source was verified again
at 04:37:55–04:38:00 UTC by `job_c8e0605dec32`: **36/36 methods and 4/4 original
macro methods passed**, including all 52 subcases. Before/after hashes also
cover all five metadata fixture files. The preceding collection attempt,
`job_d9254de827cd`, selected a JSON fixture as its test module after extending
the evidence inventory and stopped before discovery: **0 tests executed**.
That runner setup failure, its source inventory, and the corrected exact runner
are retained. No production assertion or test oracle changed. The validator's
AST before/after whitespace normalization is recorded as identical.

Positive tests read the real Git producer/current trees and retained actual
GitHub metadata. Negative tests modify explicit copies of those inputs: Rust,
header, Cargo/build script, dictionary, upstream pin, removed/replaced inputs,
test manifest entries, project membership, old 265 producer, artifact identity,
digest, job, run, attempt, repository and upload interval. Explicit transport
doubles prove refusal before download or extraction; they do not simulate a
successful Apple build.

At 04:34:03–04:34:07 UTC, `job_806e63560b8f` exercised the production metadata
fetch/validation helper against GitHub: **5 actual metadata requests**, both
producer jobs accepted with overall workflow failure retained, **0 binary
downloads**. It also verified the real source exception and unchanged unrelated
pins. Complete responses and the targeted proof are retained with this report.

```sh
python3 Tests/CI/test_stage2_prebuilt_bindings.py
python3 Scripts/CI/test_hq_stage2_macro_trust.py
```

Evidence is under `evidence/`: method/subcase results, raw test logs, source
hashes, exact runner, real source proof and actual GitHub metadata responses.
The metadata regression fixtures are under
`Tests/CI/fixtures/d5-prebuilt-20261120/`. Their positive data comes from the
actual producer, not an invented successful job.

The separate archive, symbols, Mach-O platform and complete source-parity
evidence is retained in
[commit 6067a6c6](https://github.com/davidpovarsky/Maktabah/blob/6067a6c6d10dbb7fc50562df133b5e0cf270265a/docs/hq-integration/occurrence-apple-framework-44661774024-20261120/README.md).
It covers 28 Otzaria exports and five Zayit exports in all three architectures;
those static results are distinct from executing or linking an Apple app.

## Remaining integration gate

The complete focused preflight was called and correctly refused the still-old
application Source freeze with `Application tree drift: Source`. Root owns the
final `application_source_sha` and Source/project tree update after the pending
app integration. Current Vendor is pinned to
`a9bf10318cfc44c87885c3dcfba48cbaced67788`. Current project blob
`2741615644741d39b0b19c6146f9c459323dabab` is already included in the reviewed
test-exclusion manifest; if it changes, that exclusion must be reviewed again.

After that freeze, the original Apple build, full source verification, and
required Native/device gates must run on the combined immutable source. The
36+4 Python results and static framework provenance do not satisfy those
application/runtime acceptance criteria.
