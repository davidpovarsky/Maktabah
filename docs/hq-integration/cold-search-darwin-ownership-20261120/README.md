# Cold search: Darwin ownership boundary acceptance

## Status and source

This is a separately prepared, unactivated Apple fixture. It does not change the nine reviewed production files or any of the sixteen frozen Core payloads published as `a826e66ab2710f1d3c05342da5b39b79e8c30c44`. Its starting product source is that exact commit, whose original baseline is `19b68b8b0085a3e44e519835194398486273aaa4`.

At preparation, **zero Swift ownership cases, zero Darwin cases, zero real C/Rust engine requests and zero Native UI tests have executed**. Local Linux checks generated the complete fixture source, ran eight Python evidence-classifier controls, and compiled the explicit C double with `cc -std=c11 -Wall -Wextra -Werror`. The first local C compile rejected misleading indentation; that original attempt is retained, and the fixture-only formatting correction passed the second attempt. Neither compilation is an execution of the original native search engine.

A subsequent independent source review identified the Apple `DispatchSemaphore.wait` async-context restriction in one scheduling assertion. The candidate routes that same wait through an explicit synchronous helper, retaining the exact semaphore, one-second deadline and assertion. This is a pre-execution fixture correction, not an observed Apple failure or pass. The earlier generated sources remain retained separately.

The separate Core Apple run [44762582027](https://github.com/davidpovarsky/Maktabah/actions/runs/44762582027) executed the expected twenty-case baseline (11 passed, 9 failed) and the complete 194-case candidate (193 passed, 1 failed, no skips). All twenty new cold-execution controls passed. The remaining failure is the original note UTF-16 selection test and is being investigated independently. These results do not qualify this Darwin fixture or the complete application.

## What is compiled

The driver copies seven complete, hash-bound original Swift files: `OtzariaTantivySearchRepository`, `OtzariaSearchEngineBridge`, the search models/mode/snippet renderer, and the exact-occurrence models/operation. It also compiles the complete original `ITorahStorageLock` enum, including the unchanged `LockMap` and `withLock`, and the exact original blocking generation accessor plus the new nonblocking accessor from `OtzariaAppContainer`. The source manifest records each whole input and each extracted body. The generation probe supplies explicit scheduling methods around the same `NSRecursiveLock`; it does not replace the accessor bodies.

Foundation, filesystem operations, `NSLock`, `NSRecursiveLock` and Darwin `flock` are real. One case starts a separate Python process holding the actual lock file. The repository retains its real cache and publication checks. Explicit metadata boundaries supply isolated temporary database/index files and fixed profile/index-manager observations; those files are not a valid SQLite database or Tantivy index.

`NativeConstructorDouble.c` implements only construction, compatibility, dictionary configuration, document count, free and fixture counters. The generator appends abort-only definitions for every other original native symbol. A call to any search, occurrence, install, recovery or other unimplemented engine API terminates the test rather than manufacturing a result. The whole original Swift bridge still performs its normal encoding, decoding, queue and handle management against this declared boundary.

The fixture does not compile the complete `ActionLiveBackendBridge`, Facade, app container or installer, and does not establish actual manifest validation, SQLite admission, dictionary semantics, original Rust constructor behavior or full app integration. Those retain separate Core, app-SDK and Native gates. The product's original native constructor remains writer-capable; no global read-only or external-writer exclusion claim is made.

## Required execution and observations

The first stage uses one retained **unpublished candidate** Repository from immediately before the post-constructor source/deadline guard. It is not historical Native or released product source. Its sole required runtime failure is `constructor_generation_switch_stops_further_native_work`, specifically `stale_constructor_performed_more_native_work`. Ordinary process exit 1 and that exact completed failure record are required. A compile failure, zero cases, timeout, signal or different failure cannot qualify the comparison.

The candidate stage requires all 32 unique declared cases to complete successfully with process exit 0. They cover original-versus-new lock exclusion, throwing/recursive acquisition, cross-process `flock`, cancellation/deadline under migration/database/search/cache contention, releasing all outer locks before retry, the original bridge-to-migration cycle, source generation/profile/repository ABA, missing or incompatible existing index metadata, recovery/build/install markers, dictionary digests, constructor failure, stale/cancelled/late constructor completion, configuration/count refusal, original cache reuse, and the unchanged legacy constructor directory behavior. The exact ordered case inventory is in `Tests/HQ/cold-search-ownership/OWNERSHIP_INPUTS.json`.

The constructor-generation case verifies that a source change during the constructor closes the obtained handle before dictionary configuration, count, or publication. Cancellation and deadline controls similarly reject further work after a synchronous constructor returns. They do not prove preemption or a hard elapsed-time bound inside original synchronous native/cryptographic work.

## Controlled Apple route

The proposed workflow is `.github/workflows/otzaria-cold-search-ownership-validation.yml`, triggered only by a push to `codex/otzaria-cold-search-ownership-apple-20261120` in the original repository. Root alone reviews and activates it. It checks out the actual GitHub SHA, verifies the exact reviewed driver/manifest/selector, uses the unchanged original `select-runtime27-toolchain.py` on `xcode-27`, and has read-only permissions, one job, a 25-minute ceiling and no cancellation of an existing run. It downloads no SDK, corpus, index or package dependency.

The exact command is:

```sh
python3 tools/hq-cold-search-ownership.py --repo . --output build/cold-search-ownership --expected-inputs-sha256 85d72a500037ff914fe47b2cc33094a104df8d13cbddcfac9294236dbe0bbdb2
```

The driver retains original source hashes before/after, generated source and extraction hashes, a complete input ZIP, exact compiler commands and raw logs, both executable bundles, each completed runtime record and the final result. It kills only its own process group on its finite timeout. The always-upload artifact is `cold-search-darwin-ownership`; failure reports remain failures. The workflow makes no UI, Siri, Core receipt, real-engine, corpus or physical-device claim.

## Remaining acceptance

Actual Apple compilation and all 32 Darwin cases are pending. A real original-engine cold open under the complete app's canonical managed-source/manifest authority, both fresh and revoked operation through Core, and the original failing Native search case remain separate requirements. The orphaned Windows job `job_ed394b183ed4` remains unknown and has not been relabeled or rerun.
