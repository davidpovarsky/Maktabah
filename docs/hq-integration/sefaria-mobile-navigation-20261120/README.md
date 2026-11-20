# Original Sefaria-Mobile navigation input — source and portable evidence

Task: [Sefaria L10N 1219850068707719](https://app.asana.com/0/1219602719070493/1219850068707719).
Base checkout: `60a57972acb28739ec738565083bf17fb7503028`
(the immutable Native98 checkout, application source `87b783ac3f0257e8461762e0ea9dfa5248dd06e8`).
Pinned original Mobile source: `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`.

## Concrete problem and change

The active Embedded adapter obtained `navigation.textToc` through the original RPC
bridge, but its separate schema routine did not interpret the actual mobile
`content_counts` payload. The five untouched original endpoint payloads therefore
lost primary chapters/folios, nested Rashi sections, alternate structures, and
canonical named-section identity. Some RPC failures were converted to a successful
empty TOC. Calls for the default TOC also issued redundant original RPCs.

The adapter now calls that original RPC once and passes its actual index payload
to an explicit mobile-input entry in the existing shared Sefaria navigation
parser. The existing native Remote/Offline input path remains available with its
original default arguments. There is no replacement renderer, corpus, search
engine, package store, or network response in this production change.

The mobile input preserves absolute count positions, including the zero padding
before Berakhot/Eruvin 2a, sparse verse positions, numeric/nested offsets,
default-node parent identity, original named complex sections and the original
alternate `wholeRef` values. Display titles use the existing shared Hebrew/English
policy and original Hebrew daf formatter. The adapter retains exact work-title
binding, original session epoch/stability, and cancellation checks. Failed,
malformed or foreign-work responses throw instead of becoming loaded-empty.

The new primary input traversal has a 100,000-work-unit budget and nesting-depth guards, plus the adapter
payload byte limit. Peer review found that a named one-dimensional child skipped
the traversal decrement; the final source accounts for every child. The pinned
Mobile renderer's depth-one path explicitly constructs `Array(contentCounts)`.
Scalar counts are supported. A depth-one array is rejected explicitly instead of
inventing canonical references from JavaScript's ambiguous single-entry result.

The original React TOC's `exclude_structs`/default presentation choices are not a
replacement for the existing native structure selector. The native parser keeps
available canonical primary/alternate structures; it does not create another
React UI or mutate original index metadata.

## Exact original inputs

The fixture files are unmodified bytes fetched from the original Sefaria endpoint
used by pinned `api.js`, with `?with_content_counts=1`. The fetch receipt records
HTTP status, timestamp, URL, bytes and SHA-256. See
`Tests/HQ/sefaria-mobile-navigation/Fixtures/PROVENANCE.json`.

- Genesis: 50 primary chapters and the real Parasha ranges.
- Berakhot: 125 existing amudim, 2a through 64a; 12a/12b remain those exact refs.
- Eruvin: 207 existing amudim, 2a through 105a.
- Rashi on Genesis: 50 roots and 1,072 existing verse sections; the absent 1:3
  is not renumbered into a fabricated section.
- Pesach Haggadah: 14 named roots; Kadesh and Magid / The Four Sons retain their
  original canonical named-section references.

Original JS contract sources and their source hashes are retained as bounded
read-only provenance. Existing upstream/vendor sources and pins are unchanged.

## Actually executed

| Run | Exact scope | Result |
| --- | --- | --- |
| baseline-attempt1 | Fixture setup before execution | Compile failed on test-only Codable synthesis; **0 executed**, retained |
| baseline-attempt2 | 63 shared cases, 12 entire original production files at the base | **26 passed / 37 failed** |
| candidate-attempt1 | Same 63 cases plus 13 explicit he/en decoder controls | **76/76 passed** |
| bounds-baseline-attempt1 | Four controls against the SHA-verified candidate-attempt1 whole-source snapshot | **3 passed / 1 failed**, named-child budget |
| bounds-candidate-attempt1 | Same four controls against corrected source | **4/4 passed** |
| candidate-attempt2-peerfix | Entire corrected production inputs, unchanged 76-case inventory | **76/76 passed** |

The actual whole RPC bridge, DTOs, parser and adapter execute in these tests.
Only UIKit/Expo runtime startup and the JS transport are explicit fixture
boundaries. The original raw five index responses are supplied at that boundary.
Held requests, cancellation, late generation responses, explicit errors and retry
exercise the actual original RPC bridge. This is not a Hermes or UIKit run.

The 31 original language cases and the original 38-input, seven-JSON, six-stage
workflow regression also passed before the two localized mobile budget guards.
Those exact input hashes and timing are retained; they are not relabeled as a
later whole-tree, Apple or Native pass.

The standalone drivers use the observed Swift 6.3.3 Windows toolchain, `-j1`,
strict concurrency where applicable, finite compile/runtime limits, a previously
existing module cache, complete production files, exact case inventories, and
before/after input hashes. No user database or index is opened.

## Remaining acceptance

Apple SDK and Native execution for this change are **NOT_RUN**. Twelve separately
prepared Native declarations use the original Reader, catalog palette, TOC list,
localized structures and genuine Reader text/locator oracles. Eight cover the
Embedded online path in Hebrew/English on iPad/iPhone. Four cover a strictly
limited one-shot Remote URL Loading failure and the original Retry action. They
will be delivered in a separate reviewed source tranche; no selection manifest
or active frozen ref is changed here.

The Remote transport is `SefariaRemoteStore → SefariaHTTPClient`. Embedded is the
original Hermes `OfflineOnline.textToc → api.js` route and does not pass through
that HTTP client. A Remote fault is therefore not evidence of an Embedded
transport fault, installed-offline corpus availability, physical network
disconnection, spoken VoiceOver behavior, or successful Native execution.
Physical/online/offline/provider acceptance remains open until actually run.
