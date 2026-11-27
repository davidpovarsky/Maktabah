# Native full-v40 Reader execution contract

The integration owner executes these cases serially on the already owned, originally installed full-v40 Simulator. No external database override, bootstrap bypass, replacement state file, or additional corpus download is admitted. The original installation report remains attributed to the source that produced it; the current installed app and test images must independently qualify against the current checkout and actual SDK.

## Runner environment

The cases use the existing F08 runner contract, without new runner environment keys:

| Key | Meaning |
| --- | --- |
| `SIMULATOR_UDID` | Explicitly owned actual Simulator |
| `PRODUCTION_SEARCH_CONTAINER_PARENT` | Actual same-Simulator `data/Containers/Data/Application` parent; the case discovers actual app and group containers from original metadata |
| `PRODUCTION_SEARCH_PREVIEW_ORACLE` and `PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256` | Exact separately generated full-v40 preview oracle and file digest |
| `PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256` | Exact original reading-unit service source digest |
| `PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256` | Exact original backend presentation source digest |
| `PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256` | Exact actual catalog compile-input receipt digest |

The cases generate their own workspace and actual search trace namespaces. They enable only the original passive viewport/source observation and the explicitly authorized DEBUG native-selection observation. They do not pass a fixed `-otzaria_reader_unit_mode`, a scenario or `-smokeBypassBootstrap`.

## Real target admission

Generate the existing three-mode preview oracle for one actual original-provider hit from query `נפשי`, using the final qualified source. Set the additional catalog input **`readerNavigationOracle: true`**. With it absent or false, the original preview/default full-v40 catalog body is unchanged.

The target must already meet all F08 admission rules, including the actual stable provider/publication tuple, canonical SQL book and line metadata, a nonzero source line, distinct line/paragraph/chapter context sizes, original Reader presentation, real neighbors and a book outside imported tabs. Additional requirements are:

- The complete line's original backend Reader source is at most 2,048 UTF16 units and its complete visible source anchor is one independently identifiable native text descendant.
- The target has no pre-existing rendered highlight. Preserve all existing user annotations and choose an eligible actual provider row; do not clear user data to satisfy the test.
- Both paragraph and chapter have an actual previous source unit. The chapter's previous unit has a different canonical TOC anchor, so selected-node synchronization must visibly change before returning.
- Both full-v40 database hashes/counts and the actual installed manifest are admitted. The expected corpus remains 4,355,063,808 bytes, SHA256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`, 8,259 books, 7,925,185 lines and 7,001,824 links, release 455390662 / `v40-20261123094345`.

The optional `tocSelection` per target and neighbor contains `schema`, `canonicalLocator`, `sourceLineIndex`, actual SQL `headings` (entry ID, parent ID, level, raw title and original plain title), `allTOCRowsChecked` and `tocSQLRowsSHA256`. All actual book TOC rows must form the original reachable tree. The current unit's canonical selected TOC anchor is the latest original heading source line at or before its start. Multiple headings sharing the same canonical locator remain separate actual SQL rows; their real UI surrogate is resolved from the original registry at runtime.

## Phase ordering and retained artifacts

Run the selection/backends case with ordinary network connectivity for the original Sefaria backend, before the explicit offline phase or after network restoration. It creates one genuine highlight through the native original menu. Run it **before Books Updates** so the Settings preservation snapshot also contains that actual user row. Do not delete that row after the case.

Both cases use the original iPad landscape viewport and explicit English locale for the real selection menu and structural controls. The pull case requires a real text viewport taller than 360 points, the original edge position and observed overscroll. A missing control, missing target or unsupported viewport is a failure, not a skip or synthetic substitute.

Retain genuine xcresult attachments with these stems:

- `reader-v40-original-selection-to-persisted-UTF16`: actual request/probe, original stored row, actual native color action, canonical source digest and document identity.
- `reader-v40-exact-original-annotation-render-ranges`: actual original attributed-text range/color diagnostics.
- `reader-v40-original-settings-backend-*` and `reader-v40-original-backend-*`: original Settings state, current document/canonical Reader and bounded actual source.
- `reader-v40-original-selected-toc-*`: actual SQL digest, genuine registry surrogate and selected original UI rows.
- `reader-v40-original-held-pull-*`: gesture start/end, direction, observed native overscroll and fresh original samples. Scope explicitly distinguishes sub-threshold cancellation from unproved continuous-touch retreat.
- Existing F08 source/provider/workspace attachments and screenshots are retained as generated by the unchanged helpers.

No time or memory SLA is introduced. These selectors add correctness observations; full-v40 PERF01–03 and the 100-switch original Groups measurement remain their own separately qualified native gates.
