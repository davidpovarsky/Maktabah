# iOS Build: original Hanlin SDK preparation

## Demonstrated failure

Original run [44661774024](https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024), source `99f7927e4da72f2463417f5c2de2c4d20c6aa168`, built both the Otzaria and Zayit frameworks successfully. The Swift package job `136041463763` then exited **74** because `Vendor/HanlinSDK/Packages/HanlinAgentSDK` was absent. The simulator and unsigned device build jobs were skipped by their failed dependency; they did not pass. Full original resolve log and job metadata are retained in `evidence/`.

## Narrow repair

The isolated branch starts at integrated source `e90feda1ed411b98ebc4a55f1d6df0b089a6f305`. `.github/workflows/ios-build.yml` is the only operational file changed: each fresh checkout for `swiftpm`, `simulator-build`, and `device-build` materializes the original SDK through the existing `Scripts/CI/prepare-hanlin-sdk.py`, before any package graph or app build work. Every preparation first requires the tracked gitlink to equal immutable original SDK `e00498e33f106cc43be0476ffa2e09329c8ca300`. The helper verifies the original package layout and actual Git blob bytes; an occupied or dirty checkout is rejected. The source witness is written to `build/logs/hanlin-sdk-source.json` on each runner.

The original SDK, original preparer, package dependencies, signing, project settings, engines, workflow inputs, job dependencies, conditions, and acceptance steps are preserved. Rust-only framework jobs and the already-built-app bootstrap job do not require another SDK checkout. This is a shared CI integration seam authorized by the owner's 2026-11-19 standing instruction and current completion request. No upstream application source is changed.

## Validation and boundaries

`evidence/static-validation.json` records a parsed comparison against the exact base workflow: the only changes are the fixed SDK environment value and those three mandatory preparation steps, immediately after the original checkout. This is configuration validation, not a build result. A new actual normal-input workflow dispatch is required; its source and final job outcomes will be recorded separately. The original heavy bootstrap/corpus/live Sefaria options remain available and retain their original gates; this focused rerun uses their default false values.

No Apple build, Native scenario, provider request, device installation, or unsigned IPA success is claimed before actual execution. The older failing run is preserved as baseline, not relabeled by this repair.
