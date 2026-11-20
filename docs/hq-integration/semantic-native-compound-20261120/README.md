# Compound semantic journeys — original Native cases prepared

**All six new Native cases are NOT_RUN. Apple SDK typechecking is NOT_RUN.**
This tranche prepares original iPad/iPhone tests and opt-in DEBUG callers. It
does not convert the earlier Core/Host tests, individual primitive tests or a
declaration count into a compound Native PASS.

Source commit: `a4200ee4b08b3c2013284d7e128b7dc0c9c4ddc1`.
Branch: `codex/otzaria-semantic-native-20261120`.
Base: `3bc062fed639d0213dfb30c87cb35bd71ac80bcb`,
which includes final production journey source
`fb83df7f8bbbd5f0e6ae13113d45982af666779a` and its sealed
174-case Core / 60-case Host evidence. Root separately merged that production
work at `64d07e4219aa9035552f4b98e29de4c07e1cefee`.
No active frozen CI reference or manifest is edited here.

## Required new cases

| Class | Method | Required actual result |
|---|---|---|
| NativeRoutingAcceptanceTests | testSemanticCountThenOpenResultsKeepsExactWorkScopeOnPad | Complete the same scoped count and original Search presentation. |
| NativeRoutingAcceptanceTests | testSemanticCommentaryThenDraftPreservesLocatorAndBaseOnPad | Open the source-backed commentary, prepare the original unsaved draft, then cancel and restore the original base tab. |
| NativeRoutingAcceptanceTests | testSemanticCatalogChapterWithoutCommentaryStopsBeforeDraftOnPad | Resolve the actual catalog/TOC heading and stop on its absent commentary link. |
| NativeRoutingPhoneAcceptanceTests | testSemanticCountThenOpenResultsKeepsExactWorkScopeOnPhone | The same count/Search journey through the original phone UI. |
| NativeRoutingPhoneAcceptanceTests | testSemanticCommentaryThenDraftPreservesLocatorAndBaseOnPhone | The same commentary/draft journey through the original phone UI. |
| NativeRoutingPhoneAcceptanceTests | testSemanticCatalogChapterWithoutCommentaryStopsBeforeDraftOnPhone | The same strict catalog/heading refusal on phone. |

The original NativeRouting file has 50 declared methods; this source has 56.
Every original declaration and body is preserved. These are source inventory
counts, not execution counts. Root owns registration in the complete combined
manifest, Apple compilation, and the later immutable Native dispatch.

## Original paths exercised

### Scoped count → original results

The test launches the realUI miniTest10 reader, opens the independently sealed
book 1 / line 0 using the existing public Reader route, and warms Search only
by typing `אברהם` and pressing Return in the original Search field.
The DEBUG caller does not open/cache an engine or install data.

After returning to the exact original reader, the one-use trigger calls
production `countThenOpenSearchResults`. Its explicit disposable
read context has discovery/contentRead for one actual current Otzaria work,
`book:1`, and one Core action. It is not a production Hanlin grant.
The live authority checks the original scene/session, active tab, exact Reader
instance and request token, requested destination, loaded section, selected
segment, backend generation, mapping epoch, full mapping projection and locale.
It is re-observed after Search has actually replaced the visible reader.

The test requires separate completed Core requests for counting and results,
the same generation and exact original UTF-8 query/scope, and the original
count proof. The independent SQL/Zstandard oracle expects **109 token
occurrences in 98 source rows** for this work. The two quantities remain
separate. The original production coverage policy and cached-engine
Swift/C/Rust path must supply d5 provenance and complete 18,879-document
coverage; no registry or proof override is introduced.

The original Search owner must report the exact submitted query, exact mode,
preserved sort, book scope in both session/model, one new submission, clean
finished results and actual matching row locators. A visible original result
must match the observed rows and independent source metadata. Exactly one
original native Search receipt is required. Original workspace membership,
Reader owner and app PID remain unchanged. The test does not claim that the
Reader stays visible while Search is visible.

### Source commentary → original unsaved draft

The actual original link is:

- Link 6529212, COMMENTARY.
- Base book 28, line ID 6188105, lineIndex 2.
- Target book 3276, line ID 6609893, lineIndex 4.

The production compound API must return two separate actual Core results.
The acknowledged commentary locator, note result locator and original editor
draft locator must agree exactly with the sealed target. The test requires the
original editable text view, exact proposal, Save availability, no Delete
control for the unsaved draft, and an unchanged original annotation store.
Exactly two ordered native receipts are required: original Reader/newTab and
original note editor/sheet, in the same scene and backend generation with
increasing revisions.

A new DEBUG accessor only reads the existing exact Reader/editor owner.
Unknown ownership is distinct from an owned nil draft. The test taps the real
original Cancel button; completion requires the same owner UUID, nil draft,
inactive presentation, actual scene readiness, absent editor and unchanged
store. It then returns through the existing original iPad tab strip or phone
tab overview to the exact base tab UUID/source. No alternate editor, binding,
save hook, forced selection or synthetic native acknowledgement is added.

### Catalog/TOC refusal

The same source-backed catalog resolves `תהילים` and section
`פרק א`. Original TOC entry 600 maps to line ID 15827,
**lineIndex 1**, the chapter heading. The original adapter maps the TOC's
resolved line index to `legacyLine`; it does not substitute verse
lineIndex 2.

Actual read-only queries found no outgoing, incoming or link-coverage row for
heading 15827. The test therefore requires two completed catalog actions,
followed by reader.openCommentary **failed/not_found**, no note action, no
editor, no native receipt, and unchanged source/workspace/store/PID. This is
a correct partial/refusal journey, not a fabricated four-step success.

The broader source-backed resolver remains implemented. A positive
catalog→reference→commentary→draft Native case needs an actual original
catalog/TOC/link identity with an unambiguous linked section. This mini fixture
does not provide one through the inspected heading mapping; no alias or
invented verse substitution was added.

## Authority and lifecycle boundaries

The callers reuse the existing Reader DEBUG task and the original acceptance
probe. Admission requires DEBUG, active miniTest10, a UUID workspace namespace,
explicit matching kind and UUID token arguments, and exact one-use trigger
bytes. Results are written once by the existing atomic file path.

Original production Core/Host methods, source resolver, native admission,
surface geometry/visibility, receipts and draft persistence are unchanged by
this tranche. The only existing-line changes add three explicit kind strings
to the acceptance allowlists. The original Hanlin SDK, production tool
discovery, grants, models and all other source are unchanged. There is no Send
action, consumer activation or external-request fixture.

The new note accessor is read-only and DEBUG-only. It cannot grant an owner,
publish a visibility witness, certify an unknown nil binding, or release a
presentation. The compound tasks use the original Composition-owned pattern
so that disappearance of the source view does not silently cancel an already
admitted native continuation.

## Verification actually executed

| Check | Observed result and limit |
|---|---|
| Whole source inverse | All three complete original Git file byte streams reconstructed exactly after removing the declared additions/allowlist strings. |
| Existing Native inventory | All 50 original methods preserved; six unique additions. |
| Release/source boundary | Composition insertions lie inside original os(iOS)+DEBUG guards; the new SceneSession observation has its own DEBUG guard. |
| Original mini SQLite identity | Full SHA256 before and after read-only/query_only queries remained d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef; 15,470,592 bytes. No database writes. |
| Source-backed relationship queries | Exact commentary link, TOC heading, titles and absence of heading links observed from original SQLite. |
| Syntax attempt 1 | Three successful Windows frontend parses without DEBUG; retained as that narrower attempt. |
| Syntax attempt 2 | Three successful frontend parses with `-D DEBUG -target arm64-apple-ios27.0-simulator`, finished 11:38:33.915 UTC. Two Windows/iPhone SDK warnings per file, all retained. Syntax only. |
| Independent source review | C read all three diffs and found no concrete blocker. It did not execute the DB or Native cases. |
| Apple typecheck / six Native cases | NOT_RUN. |
| Earlier Core174 / Host60 | Existing sealed results retained; no redundant rerun and no new Native credit. |

The independent mini numeric oracle is the existing immutable Git file at
`docs/hq-integration/occurrence-app-20261120/whole-app-acceptance/unqualified/INDEPENDENT_MINI_SQL_ORACLE.json`.
Its Git-LF SHA256 is
`5193a01adb3b63762ffc790be4b42e432a75438a5a0f67ac795ac06d2543411b`.
The earlier raw Windows oracle hash in its original evidence is a different
newline representation; this record explicitly identifies the Git bytes.
The existing qualified whole-app 32-case evidence independently exercised
actual production counting on Windows. Neither record is a compound Native
execution.

## Evidence and remaining acceptance

`FINAL_SOURCE_INVERSE.json`, `FINAL_SQL_SOURCE_IDENTITY.json`,
`SOURCE_BRIDGE_MAP.json` and the syntax result/log directories record
actual inputs and observations. Earlier source checks are retained as
historical intermediate records and are superseded by the final source hash.
`source-snapshot/` stores exact committed source bytes as gzip.
`ADDITIVE_MATERIAL.json` makes the inverse repeatable.

Run `python docs/hq-integration/semantic-native-compound-20261120/verify-source.py`
from a checkout containing the base/source Git objects. It verifies sealed
artifacts, source identities, the complete inverse, declaration preservation,
the recorded parse commands and observed SQL identity. It does not launch a
simulator, re-run SQLite, count occurrences, or grant a Native PASS.

Remaining gates are actual combined Apple compilation and six original
iPad/iPhone executions, with original logs/xcresults/receipts/sidecars/captures
collected and attributed to that exact source. Original full Native/Release
scope must remain registered. Physical-device, full-corpus compound behavior,
new production consumers and a positive four-step catalog journey remain
separate uncompleted scopes.

Five intermediate Windows JSON records originally used CRLF. The first Git
whitespace check rejected those carriage returns; its full failure and prior
35-file verifier result are retained under raw/packaging-attempt1. Exact bytes
are preserved in raw/original-crlf, with readable LF views and both hashes in
NEWLINE_PROVENANCE.json. No source, SQL result, parse input or assertion changed.
