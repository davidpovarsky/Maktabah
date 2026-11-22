# Live7 connection-stage diagnostic proposal

## Actual failure and immutable input

The failed Native case is Live run44993301949, attempt1, checkout77c7df82ef5f822bf0b1dd7e08ff2b4b98d425d2 and application/UI source0ea7218331d1441d37d06d43333e579f267056e3. The case failed at HanlinConsumerAcceptanceTests.swift:551 after the consent ON assertion and a real Connect tap. No Send/provider conversation completed.

The complete failure packet is separate and frozen:
C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-artifact-20261122.
Its FILE_INDEX.json SHA is96b582b77ecee01b05cfd0c79d542c1ca4379c9953674899df17dd7f8a14e662.
Root exclusively owns its repository publication.

This proposal applies to the exact five source preimages common to77c7 and d14f845f2b0760ce8d3bf186ca656db57f435f9f. All originals can be recovered byte-for-byte by the recorded inverse replacements. No checkout was edited and no parse, test, build, Native/Live run or credential action was performed.

## Recorder binding and payload

The existing original one-use private-input consumer calls beginOwnedLiveInput only after its validation, removal and original field assignments. It passes the already owned run nonce. The recorder requires the exact environment nonce and a canonical UUID, starts one new file with an inputConsumed event, refuses to overwrite any existing journal, and remains bound through the original dismiss/reopen. It cannot be enabled by ordinary app use; it is inactive outside DEBUG Simulator Live qualification.

The journal contains schemaVersion1, an overflow boolean and a contiguous event array. Each event has a sequence number, fixed stage, fixed reason and up to9 boolean flags from a fixed enum. There are29 allowed stages,9 reasons,29 flag names and at most96 events. Overflow is explicit. There are no free-form values, model/endpoint/source strings, credentials, text, URLs, timestamps, account IDs, conversation/session IDs or native object identities.

The fixed output filename uses the already owned nonce only for private correlation. The admitted JSON contains no nonce. Diagnostic I/O is nonthrowing to the business action. Existing guards, exact source comparisons, connection requests, consent lifetime, dismissal/reopen and XCTest assertions remain unchanged.

## Existing evidence contract and the added seam

runtime27-hanlin-live.py currently:
- validates exact application/UI trees and the original immutable build before execution;
- removes the step key from child environment and stages exactly one mode0600 provider input on the exact owned Simulator;
- requires precisely the one Live selector;
- calls LiveAcceptance.capture after XCTest and before owned-device cleanup;
- requires a completed original Native witness for success;
- preserves raw private evidence outside the upload directory;
- copies only a fixed upload allowlist, scanning each byte stream for the real credential and its base64 form (and the fixture token);
- removes the entire partial upload directory on scan/admission failure;
- independently removes private input, restores prior evidence and cleans the owned Simulator.

The proposal uses that existing capture callback. It collects the typed journal BEFORE the existing final-witness requirement, allowing the actual failure path to retain stages. The existing witness and success checks are unchanged.

Before staging input the driver asserts no journal with this fresh nonce exists anywhere under the owned device's application roots. Capture permits at most one exact filename, a regular nonsymlink mode0600 file within the owned root, and at most65,536 bytes. The exact-secret scanner runs before JSON admission. Strict decoding rejects duplicate keys, non-finite values, any unknown top/event keys, wrong primitive kinds, unknown enums/flags, more than9 flags, empty/over96 events, noncontiguous sequence, absent/repeated inputConsumed, and nonboolean overflow. The initial event must equal the exact inputConsumed record.

A valid journal is copied unchanged to the private work directory, then added by one fixed name to the existing scan/allowlist. A missing journal is reported NOT_OBSERVED. A full journal reports OBSERVED; a bounded journal that overflowed reports OVERFLOW. None of those statuses declares Native or provider success. No AX, raw application console or new container data is published.

## How the new evidence narrows the next repair

| Last observed sequence | Meaning supported by the proposed evidence |
| --- | --- |
| inputConsumed, no connectEntered | The original input was consumed, but this record has no Connect callback entry. Inspect actual control dispatch/view replacement next; do not infer a tap coordinate. |
| connectEntered followed by connectFailed/invalidArguments | Actual input presence and local request validation become distinguishable, without publishing the key. |
| consentCaptured and closeRequested, without dismissAccepted | Distinguishes absent/ignored real dismissal from an attempted source-qualified reopen. |
| sourceComparisonRejected | The eight boolean comparisons identify which original source facets differ; the original whole-value equality still rejects. |
| readReopenEntered/consentConsumeEntered followed by openFailed | Locates failure in actual reopened-session qualification, without weakening the one-use witness. |
| openIssued with read scope, then mount/configuration failure | Distinguishes original presentation mount, engine construction and configuration activation. |
| configurationCompleted but XCTest still cannot find End book access | Connection/lifecycle completion is observed; subsequent UI/AX presentation remains the failing boundary. |

The diagnostic is deliberately not a speculative product repair. It does not force the end-access action, grant scope, invent state, relax equality, extend timeouts or replace the real controls.

## Next validation scope, after root review

The next meaningful local controls should exercise ONLY this new strict journal boundary: valid real-format JSON and fixed enums; unknown/free-form credential-bearing values; duplicate keys; wrong bool/integer kinds; event/flag/byte bounds; required single input lifecycle; and retention before a missing final witness. Full syntax parsing of the four actual Swift source files and Python AST is also appropriate. Existing previously passed Native/component suites are excluded.

A future actual Apple build and the failed one-case Live route remain required. The existing REVIEWED_SOURCE still points to0ea intentionally; the root coordinator must bind the final actual reviewed source before any dispatch. The key remains absent.
