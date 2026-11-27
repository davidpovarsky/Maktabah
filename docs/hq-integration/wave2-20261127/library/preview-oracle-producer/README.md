# Actual first-page preview oracle producer

This checkpoint adds only `Scripts/CI/prepare-production-search-preview-oracle.py` and its evidence. It fills the host step between the original `preview-hit` and `preview-reader` phases. It does not edit the study controller, the registered UI cases, the application, the catalog program, a provider, a decoder or a renderer.

## Exact API

The integration owner must first include the new script in `production-study-v40-ui.py`'s `FILES` execution closure and freeze the final source/build inputs. The current ordinary first-page case must then actually pass on the originally installed, explicitly retained v40 Simulator.

```sh
python3 Scripts/CI/prepare-production-search-preview-oracle.py source-check
```

This operation needs the committed source closure, but no installed corpus, passed UI case or Simulator. It reports `SOURCE_CHECK_ONLY_NOT_NATIVE_OR_CORPUS_EXECUTION`. Optional `--output` retains that source inventory in a fresh directory under this checkout's `build/artifacts`. With `--compile --output <fresh-directory>` on the Mac, it additionally compiles the unchanged original Swift catalog and whole production service/presentation closure. It never executes the resulting binary against a corpus. An explicit `--module-cache <owned-absolute-path>` may reuse the integration owner's inactive cache; otherwise the compilation owns a new cache in its output directory.

After the genuine `preview-hit` phase:

```sh
python3 Scripts/CI/prepare-production-search-preview-oracle.py execute \
  --preview-phase-result /absolute/path/to/preview-hit/RESULT.json \
  --owned-simulator ACTUAL_RETAINED_UPPERCASE_UDID \
  --installation-result /absolute/path/to/original-installer/RESULT.json \
  --reserved-other-bytes ACTUAL_COORDINATED_RESERVATION \
  --output /absolute/checkout/build/artifacts/preview-oracle-NEW
```

The existing `EXPECTED_CHECKOUT_SHA` and `FAITHFUL_RUNTIME27_IDENTIFIER` execution environment remains required by the original source/build and retained-owner admission. `--hit-index N` may select exactly one actual first-page index, from 0 through 99. It does not provide an invented book or line and does not fall back to another index. Without it, the script examines the actual native provider's order until an eligible original source unit is found. Every inspected index and explicit rejection is retained.

Success writes `runner-inputs.json` containing **exactly**:

| Key | Value |
| --- | --- |
| `PRODUCTION_SEARCH_PREVIEW_ORACLE` | Actual generated `candidates/NNN/preview-targets.json` path |
| `PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256` | Digest of that complete file |
| `PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256` | Whole original `OtzariaReadingUnitService.swift` digest |
| `PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256` | Whole original `LibraryBackendModels.swift` digest |
| `PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256` | Actual retained `compile-inputs.json` digest |

The existing study controller consumes this file with `--runner-inputs`. The producer's success literal is `ACTUAL_PASSED_PAGE_ORIGINAL_SOURCE_ORACLE_READY_NOT_PREVIEW_UI_ACCEPTANCE`. Neither that status nor the source catalog's existing status claims that the following full-context preview/Reader cases executed.

## Original native input and source admission

The producer reuses the original study controller's `verified_phase`, the prerequisite helper's `Evidence.study_phase`, and the Settings receipt helper's original exported-attachment selection and zero-skip verification. It requires the current exact checkout, product/test trees, frozen execution bytes, qualified actual app/test/SDK build and the original retained installer owner. Source or build changes require a new genuine first-page execution at the qualified source; a historical first-page receipt is not silently relabeled.

The sole accepted selector is:

`Maktabah-iOSUITests/PublishedProductionSearchDataTests/testPublishedV40NafshiFirstPageForIndependentFullContextOracle`

The exact original exported attachment stem is:

`published-v40-nafshi-source-selection-for-independent-context-oracle`

Its provider/publication/SQL arrays must all contain 100 entries. The script validates the exact SHA256 of query `נפשי`, first-page offset 0 and limit 100, engine/profile, namespace, session, PID, submission revision, stable result ID, canonical book/line/locator/title/reference and unique source identity. It independently executes the original native case's read-only SQL identity query for **all 100 rows**, not only the selected hit. The original raw attachment is copied byte-for-byte to the owned evidence directory, with its original export and case witnesses retained.

The database remains the actual retained Mac app's full-v40 database, read in place. No second corpus download, copy, subset or injected app path is allowed. A single fresh full-file SHA256 with device/inode/size/mtime/ctime before and after binds the current 4,355,063,808 bytes to `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`. The 8,259/7,925,185/7,001,824 corpus counts are reused only from the original genuine admission for those exact bytes; the producer does not claim a new full count scan. The native installed manifest, MCM ownership, installed app/runner image closure and immutable historical installer receipts remain bound. The Simulator must start and remain shut down; the producer launches no app or Simulator.

## Unchanged source and eligibility

The compiler recipe comes from the original `prepare_catalog` in `reader-full-v32-ui-observation.py`, with the current v40 profile's `catalog_compiled_sources`. It compiles the entire unchanged `FullV40ObservationCatalog.swift` and whole production service/SQLite/Zstd/presentation files. The existing catalog's explicit telemetry/logger and unused Zstd boundary declarations retain their original source-control scope; they are not substituted app implementations. The original native source binary is run only after genuine UI/source/owner admission.

The input uses the catalog's existing `previewTargets` path for `line`, `paragraph`, and `chapter` of the same actual provider tuple, plus `readerNavigationOracle: true`. Original `sourceService` and `presentationSource` hashes are tied to that exact compiler command and retained compiler-input receipt. Raw source, preview `readerPlainText` and original backend `LibraryReaderRenderModel` output remain separate complete fields. No host-side rendering, normalization, search computation or decoding is added.

Eligibility follows existing registered UI contracts:

- Nonzero actual source line; one line, a paragraph with more than one row, and a strictly larger complete chapter.
- A nonempty single-line focused preview anchor and a complete original line Reader body of at most 2,048 UTF16 units.
- Actual previous/next line neighbors, previous paragraph and chapter units, and a different previous-chapter canonical TOC anchor.
- A complete oracle no larger than the existing controller's 2,000,000-byte runner-input bound. Oversized output is retained and rejected; it is not shortened.

A compilation failure, source mismatch, broken SQL identity, original Swift error, timeout or incomplete output fails the whole producer. These failures are never disguised as eligibility skips. Successful original source executions that fail the explicit eligibility criteria retain their full output and rejection reason. `--hit-index` failures never silently select a different hit.

Execution is bounded by 100 actual first-page candidates, a 1,200-second orchestration budget, 120 seconds per original source invocation, and a 1 GiB retained output budget plus the declared reservation. Each child output file is capped at 64 MiB; a cap violation is an actual failed execution, never a truncated passing unit. No failed or earlier candidate is deleted. The final original source files and complete compiler inputs/log/binary witnesses stay available for review.

Three conditions remain **native runtime assertions**, not source-oracle claims: absence of the target book from the next case's actually imported workspace tabs, absence of an existing rendered annotation for the genuine selection case, and actual viewport/control/selection/navigation behavior. The producer never clears tabs or annotations. Later navigation/continuous-pull cases do not require the target to remain annotation-free; the genuine highlight remains ordinary user data. A rerun of the selection case on the same annotated line may intentionally require another actual eligible provider row.

## Verification and scope

The retained source-only admission controls use tiny, explicitly synthetic parser/SQLite fixtures. They exercise wrong query/page/profile/PID/session/revision, partial arrays, unstable IDs, SQL mismatch in the last row, foreign source/compile hashes, source-path escape/symlinks, altered complete/preview/Reader bodies, UTF16 mismatch, wrong focused SQL identity, missing TOC, and eligibility rejection without source truncation. They create no genuine preview oracle and run no provider, app, Simulator or production corpus. The whole order gate is not replaced by a synthetic passing phase.

The Apple compile uses exact original files from root commit `1fc951485216935abfe0977f37376a5d3f155476`:

| Original file | SHA256 |
| --- | --- |
| `FullV40ObservationCatalog.swift` | `1e1ec453615432f7ec933e6468c01887726bcd2a6528e6bbb8c8cdce203c9992` |
| `OtzariaReadingUnitService.swift` | `867665cb0a4c10b51b688eb73ef880b1e32d65ccaf33a0aadd21e6114ad35902` |
| `LibraryBackendModels.swift` | `b05a2e40eca5577441992d6fa1648ec7ae9ef617a23d52ef8a7f1e46e2c9d14d` |

Actual attempt 1 failed immediately because the first host draft resolved `swiftc` to `swift-frontend` for invocation, changing argument semantics. Its complete original inputs/log/result are retained. The corrected host keeps the `xcrun` driver path in the actual compiler command and records a separate digest of the resolved executable.

Actual attempt 2 ran from `/Users/m1/builds/otzaria-wave2-library-controls-20261127/preview-oracle-source-attempt-2` on 2026-11-27, 05:23:55–05:24:10 UTC. Whole-source compilation passed with exit 0 and an empty compiler log. The 1,112,072-byte original source-catalog binary has SHA256 `52b032a352589f5490b36a5fbf7a3bc00ed30399214883d80d73e7cb45c5b46f`. `compile-inputs.json` SHA256 is `dc51a2d9049fa13e640f2ef5049e4820fe5e9258a468fe9f9c132c262a67da7e`; actual `RESULT.json` SHA256 is `6b0665b9b501b5f1b860b2c7cb2d041145d8827dd66c9dd420b84c05888208be`.

**The compiled binary was not executed. No production corpus was read, no real provider hit has yet been admitted, and no full-context UI acceptance is claimed.** Genuine source-oracle generation remains dependent on the integration owner's actual passed original first-page phase and final qualified source/build. The evidence archive preserves the exact current source compile and the prior failed attempt separately.
