# Explicit Debug production observation for original Groups100

This is a prerequisite for the separate full-v40 native Groups100 case. It is **not UI acceptance**, an actual group operation measurement, or a full-corpus performance result.

The actual original `StudyGroupSwitchPerformanceObservation.admittedNamespace` admitted only `miniTest10`. Running the new production case against that source would produce no original operation/`phys_footprint_bytes` records. The change adds a separate Debug-only production opt-in while preserving the existing mini admission and the complete original operation, timing, memory, sequence and serial logging implementation.

Production admission requires all of the original valid-UUID namespace and original performance flag/default checks, actual environment and registry profile both `production`, and the separate `-StudyGroupProductionPerformanceEnabled YES` argument/default. Ordinary production, missing or false flags, mixed profiles and missing/invalid namespaces remain rejected. The entire file remains inside `#if DEBUG`; this adds no Release observation.

## Actual Apple source controls

`apple-source-controls/RESULT.json` retains the exact commands, SDK, input and binary hashes, and real exits. The whole original source and candidate source were compiled and linked with Apple Swift 6.4, strict concurrency and the installed Xcode 27.0 macOS SDK. The harness supplies clearly marked compile-only boundaries for unrelated app dependency owners; these dependencies are never called. It executes only the actual admission function.

- Original source: compile exit 0; 18/19 checks pass, exit 1. Only the new explicit production opt-in is rejected, as expected from the original guard.
- Candidate source: compile exit 0; 19/19 checks pass, exit 0.
- Native UI cases executed: 0. No actual group timing, memory sample, installed corpus, app build or Simulator acceptance is inferred from these controls.

The native controller must still qualify the current combined app and test binaries, original complete v40 installation and catalog, then execute the separate Groups100 case. Its actual original operation samples and host Darwin RSS boundary snapshots are distinct metrics. No performance SLA is introduced.
