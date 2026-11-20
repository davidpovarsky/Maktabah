# Bounded semantic journeys over the original Core and native owners

Source commit: **`fb83df7f8bbbd5f0e6ae13113d45982af666779a`**, branch `codex/otzaria-semantic-compound-20261120`. It includes the initial implementation `c6986ae19b43827402cddab512fa42aee4be5f30` and the source-mapping correction described below. This tranche is isolated from the immutable application under current Native/iOS validation. Its base is `c6542e412fb5b052d182aacbea685c62bdf8440c`. It addresses the compound examples in ACTIONCORE `1219614315863536`, SEARCHAPI `1219614472017979`, SEMANTIC `1219614268854015`, and UI-03 `1220542361203468`.

## Implemented source boundary

`ActionSemanticJourneys` composes existing actions in three explicit sequences:

| Typed entry | Existing actions | Data carried to the next step |
| --- | --- | --- |
| Count and open results | `search.countOccurrences` → `search.openResults` | Original UTF-8 query, original work references and revisions, and the supported exact-query modes. Occurrences and matching-document counts stay separate. |
| Open commentary and prepare a draft | `reader.openCommentary` → `notes.prepareDraft` | Only the exact section/focus destination from the acknowledged original Reader receipt. |
| Resolve a source section and prepare a commentary draft | `catalog.resolveWork` → `catalog.resolveReference` → `reader.openCommentary` → `notes.prepareDraft` | Original catalog identity, actual TOC section identity, and actual commentary-link target. Ambiguity and absence stop the sequence. |

These are structured host APIs. They do not parse free-form natural language, invent aliases, infer a corpus grouping such as “Torah” from labels, add descriptor actions, or publish a new Hanlin/AppIntent/tool capability. The original Hanlin SDK, search engine, UI surfaces, persistence, and action registry remain unchanged.

The native entry points live in the existing `MaktabahNativeRoutingComposition`. They call the original search-results, commentary, and note-draft paths, retaining their scene ownership, source validation, admission grants, visibility checks, deadlines, cancellation, and receipts. Existing independent calls use their original context/request creation path.

## Authority and continuation

A count journey requires a live trusted read-authority closure from its caller. No default read grant is created. Core continues to enforce backend permission, content rights, explicit work restrictions, query support, managed-artifact coverage, deadline, and cancellation. This tranche does not connect that API to a model or introduce an external data transmission.

Navigation keeps its separate original context. The host retains the original scene/manager identity and complete source observation. A next action must match the expected backend generation, presentation, action, and canonical JSON bytes of the original request arguments. Canonically equivalent but different UTF-8 query strings cannot replace each other.

Only an exact acknowledged native transition may advance the retained observation. The next step still obtains its own original Core admission. A draft uses the existing selected segment/range and the existing unsaved editor. A section-only link with no actual selected segment cannot invent an annotation range. No save, annotation migration, exchange, or CloudKit action is added.

For the results transition, the source object, complete mapping epoch, full mapping projection, locale, and backend must remain equal. The original mapping projection includes profile/group identity and membership, active tab, and every tab's backend, book/work identity, and reader lifetime. It excludes the global Viewer/Search mode. Reader metadata may become unobservable after the actual Search transition; any non-nil reader/work/selection metadata must still equal the retained value. This exception does not renew the caller's independent read authorization, which is checked again before publishing a count.

Results preserve individual steps. A successfully opened Reader remains an observed effect if a later draft fails. Queued actions do not count as completed journeys. A revoked read must not leave a number in the returned result, including revocation during a later UI await; any already observed native effect is reported separately.

## Validation status

**Actual portable results: 174/174 Core tests and 60/60 extracted Host controls passed. Apple typechecking and Native compound execution are NOT_RUN.** The existing original 137 Core case names are preserved and all passed. The 37 added Core cases consist of four commentary continuation controls and 33 compound cases. The Core files did not change after their 174-case execution; the final source binding verifies them against the corrected commit. No test was skipped to obtain these results.

The initial original-Core baseline executes the existing 19 commentary cases plus four new continuation assertions. It completed 23 cases: 21 passed and two failed because the original commentary result did not expose its acknowledged destination/locator. The two refusal/independent-reader controls passed. This is a portable contract result, not a Native UI observation.

All preparation errors, partial executions, and source changes are retained:

| Attempt | Actual executed outcome | Meaning |
| --- | --- | --- |
| Original commentary baseline | 23 completed: 21 pass, 2 fail | Missing acknowledged destination/locator metadata. All original 19 commentary cases passed. |
| Candidate 1 | 0 executed | Swift failed to diagnose a conditional optional actor closure in the new test fixture. Replaced by an explicit typed `if` assignment. |
| Candidate 2 | 142 completed: 141 pass, 1 fail; then a new case crashed | A tracked embedded-handler fixture was missing from the sparse working tree. Separately, a forced unwrap after a failed new assertion terminated the process. Thirty-one declared cases did not complete. The original data file was restored byte-for-byte; the assertion became `XCTUnwrap`. |
| Candidate 3 | 173 completed: 166 pass, 7 fail | Five new happy/receipt cases incorrectly assumed the original UI accepted non-nil catalog revisions. The two publication-lifetime cases also failed. No product refusal was removed. |
| Candidate 4, clean lifetime RED | 174 completed: 172 pass, 2 fail | The supported revisionless scope reached the original Core UI port. Revoking read authority or changing the source during that await left a count in the aggregate result. |
| Candidate 5, final Core GREEN | **174 completed: 174 pass, 0 fail** | Final publication rechecks the live read authority and removes the count on revocation, while preserving the separate native action result. Finished 2026-11-20 10:47:37 UTC, zero warnings. |
| Initial Host members | **40 completed: 40 pass, 0 fail** | Seven whole composition members, actual compiled Core contracts, explicit portable UI boundaries; exact ordered case inventory. Finished 10:48:47 UTC. This intermediate fixture used simplified projection values and did not cover same-source-object mapping changes. |
| Full original mapping types, RED | **60 completed: 42 pass, 18 fail** | Unchanged product source `c6986ae1`; all previous 40 cases and two valid transitions passed. Changes of epoch, profile/group/tab/target ownership, locale, or remaining visible metadata were incorrectly adopted. Finished 11:02:01 UTC. |
| Full original mapping types, GREEN | **60 completed: 60 pass, 0 fail** | The same fixture and actual Core objects, with only the new source guard. The complete original epoch/target/projection declarations are extracted verbatim. Finished 11:03:00 UTC, zero compiler warnings. |
| Whole composition parses | Exit 0 before and after the mapping correction | Syntax only on Windows targeting an Apple triple. Two cross-target SDK warnings in each are retained; this is not Apple typechecking. |

The revision-bound case now explicitly verifies a partial outcome: count may complete with its exact revision, while the original results UI refuses `scope_revision_not_supported`. The request retains that revision; it is never stripped to manufacture UI support. The original `ActionSearchSemantics`, scope mapper, and native binding retain their existing refusals.

The host fixture extracts complete original composition members and links the actual compiled Core contracts. Its final version also extracts the original `StudyWorkspaceMappingEpoch`, `StudyWorkspaceMappingTarget`, and `StudyWorkspaceMappingProjection`, using their real synthesized equality. UIKit, scene-directory observations, the app backend enum boundary, and live workspace/reader observations remain explicit doubles. It checks host guard behavior; it does not prove real view visibility, SwiftUI lifecycle, Apple typechecking, or Native receipt timing.

The initial source review and 40-case pass were not treated as complete coverage: a follow-up review identified that object identity alone could accept a changed group/document in the same owner. The additional 20 cases made that gap executable before the guard was changed. The reviewer then checked the actual final guard and original mode/projection boundary without finding another blocker in that delta. These are source reviews, separate from the executed Core and Host evidence.

The single existing Core cache was reused with `--jobs 1 --disable-swift-testing`; the tests are XCTest cases. The Host executables link those same verified Core objects and reuse that module cache. No SDK, database, or corpus copy was created for this tranche. Raw logs, full input hashes, exact commands, the failing candidate source snapshots, generated Host source, and executable hashes are attached under `raw/` and indexed by `EVIDENCE.json` and `SHA256SUMS.json`. `verify-evidence.py` checks the durable bytes and actual case inventories without rerunning Swift. Its first packaging attempt rejected Windows CRLF case lines; the verifier now matches the original driver's universal-newline read while retaining and verifying every raw byte. That packaging failure is preserved separately from the Swift results.

Reproduce the final Core execution from this source with:

```text
swift test --package-path Source/Otzaria/Actions --scratch-path build/semantic-compound-20261120/core-cache --jobs 1 --disable-swift-testing
```

The existing tracked `docs/hq-actions-bridge/embedded-handler-fixtures.json` must be materialized when using a sparse checkout. The exact Windows commands and toolchain paths are in the retained launcher/input files. All artifacts in this report concern this isolated source, not the simultaneously running normal iOS workflow on `e9050ad8998a070c92c73a881b0d7deb6e216e88`.

## Remaining acceptance gates

The combined application needs Apple compilation and actual Native compound runs. Separate successful primitive tests are not proof that a whole journey completes. Required compound observations include the same query and work scope in the original results UI, exact commentary section/focus followed by the original unsaved editor, unchanged base-reader/tab identity, cancellation/source-change refusal, and no unintended persistence or model send.

Production consumer exposure remains a separate gate. A future caller must supply a real trusted read authority and preserve its lifetime; this source does not make a new blanket corpus grant or convert catalog metadata into content authorization. Unsupported count units, query modes, missing complete-artifact coverage, ambiguous catalog/link targets, and unavailable exact selections remain explicit refusals.
