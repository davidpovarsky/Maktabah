# Paired original Anytype UI acceptance on genuine production storage

## Source ready; native acceptance remains open

This packet corrects the deferred two-full-app Swift selector so its five phases use the original full-v40 production launch, original Library/book controls, and actual production app stores. It does not run the app, install a corpus, authenticate an account, exchange a native object, or manufacture a production receipt.

Source commit: `2f71c9a2995ed1cf7d8d476df4f33919f06da97b`.
Base: `95a8e41c69da9add6e260d6b5afb20fe316fcfe4`.
Original Wave1 donor: `8c0e9b21cf7f87c18383aa4fc329c65bf974d441`, including the one-file changes from `87dfd8d0aa1cb06b418823a0c01587b9907be14d`.
The base test file is byte-identical to donor parent `50fca60f0a773f4e415d6729b9417ff3a27c8834`; there were no integrated test-file changes to overwrite.

The sole app-test file is `Maktabah-iOSUITests/ProductionAnnotationEditorAcceptanceTests.swift` (SHA-256 `0a7cd74eb830cd94296e0fac7584edb0d19560b0fd31bcba35d7d5b46298d9b1`). The other source is the isolated control driver `tools/test_paired_production_swift_source.py`. The root integrator owns the two Python production controllers separately. No application Source, SDK, pin, validator, signing, project-membership or shared test-base file changed.

## Concrete failure and correction

The donor's paired selector and its shared create-and-share helper inherited `.realUI`. The original base explicitly gives that tier `miniTest10`; the faithful reader helper also supplied `-smokeScenario readerDetail` and an isolated UUID Workspace. Changing only the tier would still leave the scenario and faithful UUID arguments.

The paired selector now retains a controller-supplied read-only production installation receipt, calls the unchanged original `launchWithTier(.production, scenario: nil, backend: "otzaria", language: "en", locale: "en_US")`, and validates the actual launch arguments and environment. It refuses inherited database/root, bootstrap, editor-qualification, viewport and annotation-fixture overrides, including nested runner/simctl aliases and empty values. The original `-smokeBackend otzaria` provider argument remains exactly as the production base emits it; no smoke scenario or bootstrap bypass is used.

It opens the original Library tab and its original palette, enters the actual SQL title for book 103, selects the unique visible result, and checks the actual TextKit reader and `otzaria|book:103|line:…` source identity. No title or line is synthesized. The controller's target contract therefore contains only the actual book ID and title.

Every paired note/history/export read resolves the same actual data container through a unique MCM owner inside the runner's actual Simulator UDID. The corpus must resolve through the original `group.com.davidpovarsky.itorah` MCM owner, or the genuine app-container fallback. Original Debug `AppConfig.appSupportDir` is `Library/Application Support/Maktabah-Debug`; the fallback corpus is its `Otzaria/seforim.db`. Release uses a different AppConfig directory and is not claimed by this Debug control route.

The full-v40 receipt must retain 4,355,063,808 bytes and SHA-256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`, with 8,259 books, 7,925,185 lines and 7,001,824 links. Swift checks the exact receipt hash, bounded original MCM/install/manifest witnesses, live corpus size and unchanged installed manifest, then reads the target title through SQLite READONLY. The root controller is responsible for the actual full database hashes and original corpus/schema inspection before and after the phases; Swift does not rehash 4.35 GB during every note read.

The paired Workspace is the original `Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json`. No UUID test sidecar is created or borrowed. Cold reopening terminates and relaunches the same app configuration, reveals its restored original Library document, and compares the actual profile, group and document identity. It does not reopen a new book to manufacture a restoration result.

The original six nonpaired test bodies are byte-exact. Their shared legacy helper branches still use the previous namespace/read paths. The paired branch retains all original exchange, original Files import/export, canonical row/CAS, rich-body, readback and cold-reopen assertions.

## Controller contract

The root controller supplies only these runner inputs:

- `OTZARIA_ORDINARY_PRODUCTION_RECEIPT`
- `OTZARIA_ORDINARY_PRODUCTION_RECEIPT_SHA256`
- The actual XCTest `SIMULATOR_UDID`, compared with the receipt.

The receipt schema is `otzaria.original.two-full-apps.production.v1`. Required fields are `udid`, `bundle_id`, `profile`, `release_id`, `data_container`, `documents_directory`, `data_container_metadata`, `corpus_owner_container`, `corpus_owner_metadata`, `installed_database`, `corpus.counts`, `installation_manifest`, `install_receipt`, and `target_book`. Every witness has `path`, `bytes` and `sha256`. The corpus owner is the actual MCM container root, not its Application Support subtree. Root retains official metadata and schema evidence in the full controller receipt.

The paired controller must omit `FAITHFUL_VIEWPORT_DIRECTORY` and `OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE`, including runner aliases. They remain valid only for the unchanged older local journeys.

The original phase-result schema is preserved. Added actual observations are:

- `dataProfile: "production"` and `productionReceiptSHA256`.
- `productionWorkspace`: actual original path, profile UUID, group UUID, document UUID and workKey.
- `actualSavedNoteSource`: the dictionary decoded directly from original `annotations.backendLocator` TEXT using SQLite READONLY. It is not the raw TEXT string; the controller can decode its independent row and compare dictionaries exactly.
- `targetBookID: 103`.

No synthetic app PID is supplied by XCTest. The root controller owns the actual app/runner/image/process/UDID proof, the current qualified Debug build and xctestrun bindings, original installer invocation, full corpus admission and final cleanup.

## Executed controls and their boundary

At 2026-11-27 09:11:58 UTC, Swift 6.4.3 on Oracle completed:

| Check | Actual result | Scope |
| --- | --- | --- |
| Original donor call through unchanged original base/faithful launch bodies | 0 passed / 4 failed | Reproduces miniTest10, smoke scenario and UUID namespace |
| Corrected call and exact new receipt/launch policy | 49 passed / 0 failed | Actual source with explicit XCUIApplication boundary double |
| Complete changed Swift file frontend syntax parse | Exit 0 | Syntax only; no Apple SDK typecheck |
| Original six native test bodies | Byte-exact | Per-method bytes and hashes retained |
| Independent UI-agent source review | No source blocker found | Source only, no rerun or native claim |

The source harness extracts the exact tier enum, original base and faithful launch method bodies, actual donor/candidate call expressions, and actual paired receipt policy. It replaces XCUIApplication/platform rendering with a named boundary double. It does not execute MCM resolution, SQLite against production, UIKit, the simulator, the installer, the original Anytype SDK or network transport.

The compiler emitted one retained unused-result warning because the extracted original launch body does not include its surrounding `@discardableResult` attribute. No product attribute or source behavior was changed. The compiler exited 0; the raw warning remains in evidence.

The controls reject wrong schema/bundle/UDID/profile/release, incomplete corpus counts, different database size/hash, missing owner/installer witnesses, wrong book identity, invalid witness shape, storage overrides and aliases, mini profiles, extra fixture arguments and app-inherited test network flags. They preserve all six original case bodies and verify that paired code uses the original production/Library entry and has no direct database, user-default or Workspace injection.

Actual MCM ownership, production palette navigation, persistence timing, five-phase exchange, reader source restoration and final cleanup remain **NOT_RUN** until the root's qualified original app build and paired controller execute. No owner signature or native PASS is inferred from these controls.

## Preservation and integration

Raw original inputs, both expected baseline failures and corrected control logs, compiler commands, first source draft, final pins and the source-only peer review are retained. Large raw Swift inputs/diffs with original whitespace are stored losslessly with gzip; their original and stored hashes are in `LOSSLESS_INPUTS.json`. No source normalization, weakened whitespace check or original evidence deletion was used.

The Foundation module cache was reused under a short exclusive lease and retained unchanged outside normal compiler use. The lease ended after the controls. Own new work stayed below the 100 MiB budget; no Mac/native/build work ran.

The first publication request had a Sentinel connection timeout. A fresh readback found the original base HEAD, unchanged source files and no new receipt/commit or remote ref. Only then was the same scoped publication performed successfully; no command was blindly replayed after an uncertain mutation.

Intake this Swift packet together with the separately reviewed root controller packet. The existing Swift file is already in the UI test target; no new PBX membership is needed. Rebuild and validate the original app/test bundle and regenerate honest source admission before native acceptance. Rollback is a scoped revert of this source commit; all earlier donor and failed-run evidence remains.
