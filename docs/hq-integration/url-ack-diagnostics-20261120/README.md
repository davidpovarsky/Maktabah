# System URL transport failure diagnostics

## Change

The only changed executable source is the acknowledgement block inside
`NativeRoutingAcceptanceTests.openInExistingProcess`. A successful host ACK
still requires the exact original five-key schema and `delivered=true`.
Both success and recognized failure paths require the exact request nonce,
simulator UDID, transport identifier, and absence of the private token from
the complete received bytes.

A recognized failure requires the exact six-key schema (the five original
keys plus `error`), `delivered=false`, a finite numeric timestamp, and one
of these literal messages verified in the unchanged original host source:

- `System URL transport timed out`
- `System URL transport could not start`
- `System URL transport failed`

The failure attachment is serialized anew from validated public fields.
It never copies the arbitrary received error text, URL, token, argv or
subprocess output. The test records that fixed failure and throws immediately.
Malformed acknowledgements also throw. No failure can continue into the
successful transport or UI/receipt assertions.

The host's dynamic nonzero-exit message and any rejection without the exact
request nonce remain rejected as unrecognized acknowledgements. They are
not newly accepted failure envelopes.

There is no retry, timeout increase, host dispatch change, production source
change, new route, altered acceptance oracle, or accepted failed transport.
The original twelve-second subprocess timeout, twenty-second ACK wait and
one-use nonce handling are unchanged.

## Evidence for the diagnostic defect

Native run [44633736259](https://github.com/davidpovarsky/Maktabah/actions/runs/44633736259)
failed
`NativeRoutingAcceptanceTests/testHistoryURLAfterBackgroundRequiresActualVisibleReceipt`
at the former ACK schema guard.

The original host record at
`runtime27/url-delivery-11-reader.jsonl:5` reports a transport timeout at
`2026-11-20T00:43:18.844151Z`, with `delivered=false` and the fixed
message above. The previous consumer permitted only the success schema;
the legitimate failure envelope's extra `error` key therefore produced
the misleading generic credential-free-schema error.

The retained host JSONL contains 34 records, of which one has
`delivered=false`. Its SHA256 is
`d4c002665c59ac46404f47e7cacf261d72a1c095f3b825f052f820d9915569e5`.
The app log shows that the app was foreground before this request and contains
no corresponding URL event or receipt before the next test. This does not
establish why simctl exceeded its deadline or prove that no system effect
could have started.

The historical case remains **FAIL**. This change improves the failure
classification; it does not fix or excuse the original transport timeout.

## Validation and boundaries

`VERIFICATION.json` records the exact base and source hashes. Replacing
only the new ACK block with `ORIGINAL_ACK_BLOCK.swift.txt` reconstructs
the entire baseline Swift file exactly after LF normalization. All test
methods, original source-text/workspace oracles, receipt assertions,
successful transport attachment and downstream UI checks are unchanged.
The complete host source matches the baseline.

The complete Swift file passed Windows syntax parsing with exit 0.
The two emitted warnings explicitly identify the Windows sysroot/iPhone
target mismatch and unavailable SDK settings; they are retained in
`WINDOWS_PARSE.log`. This is **syntax only**, not Apple framework
typechecking. No runtime decoder fixture, app build or Native case was run
for this change. **Native executed: 0; candidate Native: NOT_RUN.**

An independent read-only review found no concrete blocker in the strict
identity/schema checks, filtered failure attachment or terminal failure path.
It is recorded in `PEER_REVIEW.json` and is not runtime evidence.
