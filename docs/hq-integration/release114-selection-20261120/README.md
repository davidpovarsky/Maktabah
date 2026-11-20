# Release selection: 114 original-interface UI executions plus two prototype oracles

## Outcome and scope

This tranche appends the same 18 new Core/Sefaria methods already declared in the prepared Native116 inventory to the existing full Release selection. It preserves all 96 original UI execution rows, two separate prototype oracles, five configurations, original order within each configuration, three stages, source/tree/pin guards, original HID requirement, and the 600-second individual test budget.

The source base is 3b1bd069ac12bb95b0f3667cc625602ae5c517aa. This is **selection preparation, not a final application-source freeze or an Apple/Native execution result**. The final application M remains pending the coordinator's AppIntent and count-setup integration. Historical source/evidence fields are retained with their historical meaning. Existing immutable runs and refs were not changed.

| Configuration | UI before | UI after | Prototype oracles |
|---|---:|---:|---:|
| 11-inch iPad Debug, miniTest10 | 54 | 63 | 1 |
| 13-inch iPad Debug, miniTest10 | 34 | 34 | 1 |
| 13-inch iPad largest text, miniTest10 | 1 | 1 | 0 |
| iPhone Debug, miniTest10 | 6 | 15 | 0 |
| 13-inch iPad production Release | 1 | 1 | 0 |
| Total | 96 | 114 | 2 |

Nine Pad methods are appended only to the 11-inch configuration and nine Phone methods only to iPhone. There is no additional 13-inch duplication. Counts refer to configuration/case executions, not globally unique method names.

## Exact preservation

Only three files change: the Release manifest and the two count-expectation fixtures. Removing the new metadata block and appended per-configuration IDs reconstructs the complete original manifest object, including every prior configuration, oracle, historical pin, and evidence record. Reversing the seven documented numeric substitutions reconstructs both original Python fixture files byte for byte in canonical Git LF. SOURCE.patch.gz is the exact three-file Git diff. raw/SOURCE_PRESERVATION.json.gz records the identities, counts, and reversible changes.

The production Release runners, handoff implementation and tests, gate implementation and tests, workflows, original app source, Swift cases, Native manifest, and timeouts do not change in this commit. The original current-source load_manifest function verifies actual compiled-target declarations and its existing exact Sidebar11201 source SHA. The original matrix supplies Native URL transport and the real mini fixture oracle for selected NativeRouting cases. The existing three-stage Release/HID topology remains intact.

A source review separately found two existing count setup helpers requesting currentTab for book1 while the canonical bootstrap Reader is book3891/line523. The coordinator assigned the exact newTab setup correction to the current NativeRouting owner. This selection commit does not modify those helpers or claim their Native result.

## Actual validation and preserved failures

The initial direct Windows producer run executed 13 tests: 12 passed and one errored because the original prepared-source guard detected the working copy's CRLF bytes instead of the canonical Git LF Sidebar11201 SHA. The exact guard and expected SHA were preserved.

The follow-up uses complete original files in a small canonical Git LF projection. Every unchanged file is first compared to the exact base Git blob. No functions, guards, methods, expected hashes or original source prefixes are stripped. The only changed inputs are the manifest and seven expected-count numbers. Complete before and final after hashes are retained, and every file was checked unchanged against the working source after execution.

| Original fixture | Executed | Passed | Failures | Errors | Skipped |
|---|---:|---:|---:|---:|---:|
| Release producer | 13 | 13 | 0 | 0 | 0 |
| Release stages | 24 | 24 | 0 | 0 | 0 |
| Release handoff on Windows | 29 | 26 | 2 | 1 | 0 |
| Release gate | 23 | 23 | 0 | 0 | 0 |
| Canonical projection total | 89 | 86 | 2 | 1 | 0 |

This is **not a full-suite PASS**. The unchanged handoff fixture retains three actual Windows failures:

- test_changed_extra_or_permission_modified_products_are_rejected: changing POSIX mode does not produce the expected mode distinction on this host.
- test_roundtrip_retains_every_byte_mode_and_original_plist: observed mode 438 (0o666) differs from expected 493 (0o755).
- test_internal_versioned_framework_aliases_roundtrip: reading the reconstructed versioned-framework alias raises Windows OSError: [Errno 22] Invalid argument.

The handoff file and implementation are exact unchanged base blobs. No failing test is skipped, renamed, weakened or counted as passed. The attempted local executor lookup returned "No usable execution environment is available" at validation time; no OS changes or installation were attempted. These POSIX contracts still require actual compatible-host execution. The independent original gate fixture ran after the handoff attempt and passed all 23 controls; it does not convert the earlier failures to PASS.

All commands, full stdout/stderr, timings, validation source, input inventories, and failures are sealed under raw. The source-only manifest load and declaration checks passed. Apple SDK, Native UI, physical device, transport, Release application execution and production corpus acceptance remain **NOT_RUN** for this tranche.

## Evidence verification

ARTIFACTS.json binds each retained gzip to both its compressed bytes and its exact uncompressed raw content. It also lists canonical Git LF hashes for the three source/config files. Verify each artifact with SHA-256, decompress it, and verify the declared raw SHA and length. For source files compare git show of the committed path; Windows working-copy CRLF hashes are a different representation and must not replace the canonical records.

The artifacts preserve both failed attempts and the final independent gate run. SUMMARY.json states the exact executed scope, actual counts, pending source pin and platform limits.
