# Full Native98 and Release96+2 refreeze after the Foundation fix

## Exact prepared source

Application/test source M is **87b783ac3f0257e8461762e0ea9dfa5248dd06e8**. This is Root's reviewed integration of the three-label Foundation repair 59a0e0aacaa454f2947ea7672e4bd0cf1653d9cd and Sefaria language repair 48ec98784f28a08fc7f4f0811f6dd7784148de77. Subsequent compound Core and Anytype work is excluded.

The failed previous Native98 checkout e9050ad8998a070c92c73a881b0d7deb6e216e88 remains immutable. Its run 44716092729 executed no UI tests; all 98 are NOT_RUN. Full failure evidence is retained under docs/hq-integration/native98-foundation-signature-20261120. Nothing in this refreeze transfers prior UI passes or labels that failure as a corrected run.

## Preserved execution scope

The complete Native selection is unchanged: **98 unique required cases, 78 iPad and 20 iPhone**. Every original catalog row, oracle, case order, selected ID, group assignment, requirement and per-case time limit is preserved.

| Owned simulator group | Cases | HID comparison |
| --- | ---: | --- |
| 11 | 9 | false |
| 11-search | 22 | false |
| 11-index | 5 | false |
| 11-reader | 35 | false |
| 11-sidebar | 5 | false |
| 11-window | 2 | true |
| phone | 20 | false |

The original maximum remains **600 seconds per XCTest**, with no pass-seeking retry. Every group still owns a fresh disposable simulator. The five Search Data cases retain their real miniature corpus, installation ownership, backup, permission, recovery and retry requirements.

Release remains **96 actual UI executions plus 2 separate prototype oracles**: iPad11 54+1, iPad13 34+1, largest text 1, phone 6, and full-corpus production Release 1. All five configurations and their original fields are byte/value preserved. The same original three-stage build/native/production workflow, same-run artifact handoffs, source checks, actual HID admission and acceptance gates remain unchanged. Native and Release must be dispatched on separate immutable branch names because their workflow concurrency key is ref-bound.

## Exact preparation changes

Only four active pin files change:

1. The focused Apple input manifest points application_source_sha and its three application trees to M.
2. R27_CASES updates only its three top-level active source pointers and appends this dated freeze record.
3. The Release manifest appends the same dated record. Existing configuration and historical records remain intact.
4. The full-v32 driver updates only its literal APP_SOURCE to M.

No product source, XCTest source, fixture data, engine/resource/SDK pin, runner, workflow or timeout is modified by preparation. The previous dated records retain their historical source identifiers. SOURCE_FREEZE.json records all 18 canonical test source hashes, app/test/Vendor/project trees, the unchanged runner/workflow hashes and the exact source deltas from the previous candidate. PIN_DELTA_PROOF.json includes deep inverse comparisons of both manifests and hashes of every changed pin file.

## Actual preflight evidence

The following original validators ran successfully from the isolated checkout with the exact candidate configuration:

- hq-stage2-focused-apple.py --preflight-only: PASS, retaining engine producer, framework artifact, test-only addition, SDK, Sefaria resource and pinned package checks.
- verify-faithful-xctest.py validate_selections: DECLARATIONS_MATCH for all 98 required cases.
- runtime27.py execution_groups: returned the original exact seven-group partition.
- runtime27-release.py load_manifest: all 96+2 declared selections, five configurations and prepared-source hashes passed.

The recorded precommit interval is **10:55:28.719847–10:55:42.385795 UTC**. At that point HEAD was M and the candidate pin files were working changes; their exact hashes are retained. The commit preserves those exact tested pin and application inputs. A final immutable-HEAD source preflight is run after commit and retained in the owned build evidence for Root's dispatch review, avoiding a recursive commit-hash claim inside this record.

These are source/declaration/preparation checks. **Apple compilation and Native/Release execution on the new candidate are NOT_RUN.** No simulator, SDK, corpus, compiler cache or user data was created or mutated. The sparse checkout used a command-local LF setting without changing global Git configuration.

## Delivery and review boundary

ARTIFACTS.json seals exact Git representations; raw command output, driver and proposed pin diff are compressed losslessly with original hashes. Root reviews the resulting commit and separately decides immutable refs and workflow dispatch. This preparation performed no dispatch, rerun, watcher, cancellation, Asana update or task closure.
