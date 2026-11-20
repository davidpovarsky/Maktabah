# iOS Build: original Hanlin SDK preparation

## Demonstrated failure

Original run [44661774024](https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024), source `99f7927e4da72f2463417f5c2de2c4d20c6aa168`, built both the Otzaria and Zayit frameworks successfully. The Swift package job `136041463763` then exited **74** because `Vendor/HanlinSDK/Packages/HanlinAgentSDK` was absent. The simulator and unsigned device build jobs were skipped by their failed dependency; they did not pass. Full original resolve log and job metadata are retained in `evidence/`.

## Narrow repair

The isolated branch starts at integrated source `e90feda1ed411b98ebc4a55f1d6df0b089a6f305`. `.github/workflows/ios-build.yml` is the only operational file changed: each fresh checkout for `swiftpm`, `simulator-build`, and `device-build` materializes the original SDK through the existing `Scripts/CI/prepare-hanlin-sdk.py`, before any package graph or app build work. Every preparation first requires the tracked gitlink to equal immutable original SDK `e00498e33f106cc43be0476ffa2e09329c8ca300`. The helper verifies the original package layout and actual Git blob bytes; an occupied or dirty checkout is rejected. The source witness is written to `build/logs/hanlin-sdk-source.json` on each runner.

The original SDK, original preparer, package dependencies, signing, project settings, engines, workflow inputs, job dependencies, conditions, and acceptance steps are preserved. Rust-only framework jobs and the already-built-app bootstrap job do not require another SDK checkout. This is a shared CI integration seam authorized by the owner's 2026-11-19 standing instruction and current completion request. No upstream application source is changed.

## Validation and boundaries

`evidence/static-validation.json` records a parsed comparison against the exact base workflow: the only changes are the fixed SDK environment value and those three mandatory preparation steps, immediately after the original checkout. This is configuration validation, not a build result. A new actual normal-input workflow dispatch is required; its source and final job outcomes will be recorded separately. The original heavy bootstrap/corpus/live Sefaria options remain available and retain their original gates; this focused rerun uses their default false values.

No Apple build, Native scenario, provider request, device installation, or unsigned IPA success is claimed before actual execution. The older failing run is preserved as baseline, not relabeled by this repair.

## Actual rerun 44669016128

[Run 44669016128](https://github.com/davidpovarsky/Maktabah/actions/runs/44669016128)
executed source `a741f464b12b884d23577e15b255101b82c8f7db` and finished
**FAILURE**, not an app or Native pass. Original Hanlin materialization
verified all 424 files in each of the three package/app jobs. Swift package
resolution and both original Rust framework jobs passed.

The next two concrete failures are preserved before repair:

- Simulator job 136071503389: the original Inspector backend fixture
  compile omitted the original `ChavrusaTextLocalizationResolver.swift`
  and `TalmudHebrewAddressFormatter.swift` dependencies. Zero fixture
  cases executed; simulator app build and iPad acceptance were skipped.
- Device job 136071503412: `EquatableMacros` from the existing pinned
  Equatable package required target/revision authorization. Dependency
  graph construction failed before actual app compilation.

The selected toolchain was Xcode26.6/iOS SDK26.5. These logs do not yet
prove an API-availability failure. The normal optional heavy/bootstrap,
corpus and live-Sefaria inputs remained false, exactly as in the original
run; their non-execution is not presented as success.

The sole watcher reached its 600-second Sentinel timeout. Its exact owned
process was confirmed gone, then completed run/job/artifact metadata was
read once. The workflow was not dispatched twice. Raw console logs,
SHA-verified small artifacts, metadata and watcher history are in
`evidence/run-44669016128.zip`; its digest and exact job results are in
`evidence/run-44669016128.json`.

## Narrow follow-up for the demonstrated gates

The Inspector backend compile now includes the same two original
localization source files already used by the existing TestFlight fixture.
Its original cases, flags and executable remain unchanged.

Both actual app-build jobs now invoke
`Scripts/CI/prepare-ios-macro-authorization.py` after restoring package
inputs. This adapter verifies the committed and resolved Equatable entry
(`https://github.com/ordo-one/equatable`, revision
`597c2bb34af0c51331eb3b5e705f942d8ee20daa`), verifies the actual standalone
checkout has that HEAD and is pristine, then invokes the existing
`authorize_pinned_equatable_macro` implementation. The original helper
adds only that package/target/revision fingerprint, preserves existing
authorizations and retains normal Xcode validation. No global macro
validation switch or package revision changed.

The existing four filesystem tests of that authorizer actually passed on
Windows. They cover idempotence/preservation, mismatched or unverified
source, malformed existing data and a read failure. The new wrapper syntax
parsed. YAML structural comparison proves no other original steps, inputs
or gates changed in this follow-up. This does not yet claim that Xcode
accepted the macro or that either app target built; the next real workflow
run is required.
