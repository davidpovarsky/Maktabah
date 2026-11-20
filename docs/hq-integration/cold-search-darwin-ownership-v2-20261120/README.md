# Darwin ownership: first actual failure and isolated fixture correction

## Authentic first execution

[Run 44765987116](https://github.com/davidpovarsky/Maktabah/actions/runs/44765987116), attempt 1, checked out `3ef8f6c410074a633dda5c33121d429ccf543ef3` on the original owned ownership branch. Its job `136390606628` ran from **15:43:13 to 15:45:28 UTC on 20 November 2026** and ended in failure. Those are GitHub job timestamps, not watcher observation times.

The complete artifact `14646590409` is 1,203,409 bytes, SHA256 `8f3314fbd0e7be164d42aecc684c4baa6370bc74af2942808a5f79998c8c19a7`. All 239 ZIP members passed CRC verification. The retained input ZIP matches all fifteen manifested inputs, and the before/after source records match. Both actual Swift6 compilations exited 0 with empty diagnostic logs. The eight Python verifier controls also passed on that Apple host.

| Stage | Actual completed | Passed | Failed | Process exit | Qualified? |
|---|---:|---:|---:|---:|---|
| Unpublished pre-guard comparison | 1 | 0 | 1 | 1 | No: `candidate_handle_not_closed` was the wrong failure code |
| Candidate ownership checks | 32 | 18 | 14 | 1 | No |

This is an actual runtime failure, not a compile failure or a zero-case attempt. The pre-guard failure is **not** accepted as the intended RED. The complete individual outcomes, raw compiler/runtime logs, source records and GitHub provenance are sealed below. No real C/Rust engine or Native UI ran; the explicit constructor/metadata boundary remains unchanged.

## What the first evidence can establish

The first run passed the original-versus-new storage owner checks, throwing/recursive ownership, the actual separate-process Darwin `flock` exclusion, the nonblocking Bridge accessor, several contention cancellation/deadline controls, source revision/profile refusals, missing-index refusal and the legacy constructor directory behavior. It failed the intended positive existing-index path and several downstream constructor/configuration controls. `source_changed` was observed in the valid-cache and bridge/migration cases. The original case output did not record every earlier refusal reason or native counter; it cannot establish that a particular URL representation was the sole cause of all fourteen failures.

The test boundary constructed its expected Index URL before creating the directory, using Foundation's implicit directory handling. Its manager then constructed an Index URL after that directory existed. The complete original Repository requires exact manager URL identity. The candidate now obtains its admitted existing URL from the same explicit boundary manager after directory creation. It retains the pre-creation URL, the manager URL, both directory flags and their exact equality in actual runtime output. It additionally requires their standardized paths to be identical. **The product URL/source equality guard is unchanged.** The next actual Apple execution must establish the observed URL forms and whether this fixture correction resolves the downstream failures.

The cache ownership case sampled three storage owners during a 70 ms interval while another task repeatedly acquired and released them. A failure to observe every free interval is not proof that a lock survived suspension. The correction pauses the real existing `validateSource` callback on its second invocation. With the real repository cache lock held, the inner callback cannot execute: the second invocation is the next outer-loop callback, before another lock acquisition. The test can therefore inspect the three original owners at a precise boundary after the previous acquisition attempt unwound.

The test retains its original final assertions, cancellation-before-release, default 1500 ms preparation deadline, original cache holder and no-native-open/publication requirement. The semaphore handshake has a bounded one-second wait; its signal and cache release are also guaranteed by `defer`. It records the observed attempt and free owner names. This changes test scheduling, not production wait budgets, Native timeouts or a performance threshold. An additional assertion requires the second-attempt boundary to have actually been reached.

## Exact correction scope

Only two fixture Swift files change behavior:

- `OwnershipBoundary.swift`: use the same boundary manager's existing URL, require the same path, and retain the original versus manager URL forms.
- `OwnershipCases.swift`: deterministic second-attempt handshake and passive records of actual refusal tags/native-double counters. All 32 original case names and original acceptance assertions remain.

The complete product source, C double, Python execution/classification driver, pre-guard source archive, original toolchain selector and strict expected-failure code are byte-identical. The input manifest is updated for the two fixture changes. The existing workflow path is retained but targets a new immutable `codex/otzaria-cold-search-ownership-v2-20261120` branch, so the original run/ref remains untouched. The new workflow retains its read-only permissions, 25-minute limit, exact-source checkout, actual stage requirements and always-upload evidence.

At sealing, local source generation and inverse/binding checks passed. **Candidate v2 Swift/Darwin execution is NOT_RUN.** No Swift compiler exists in the local Linux environment; source generation is not a compile result. Root alone may activate the reviewed new ref. No app merge or final Native qualification follows from this fixture preparation.

The exact v2 invocation is:

```sh
python3 tools/hq-cold-search-ownership.py --repo . --output build/cold-search-ownership --expected-inputs-sha256 cdfae26afdc8854b8433a385ca3497d14c772db240529d0b4f43749f557dbfb9
```

## Retained evidence

`AUTHENTIC_FIRST_RUN_REVIEW.json` records independently verified outcomes and source bindings. `SOURCE_PRESERVATION.json` records the unchanged production/driver/C inputs, exact 32-case inventory and all original assertion strings. `ARTIFACTS.json` seals the documented evidence bytes. Raw GitHub run/jobs/artifact metadata, actual source ZIP, both stage reports and logs, generated input hashes, before/after source hashes and complete archive member inventory are retained as gzip files. The complete downloaded ZIP remains identified by its authenticated SHA above; the compressed evidence subset is not presented as that ZIP.

The separate corrected Core run reaching 194/194 is a distinct test suite and source result. It does not turn this first ownership run into a success. Full app compilation, canonical managed installation proof and real-engine/Native execution remain separate acceptance gates.
