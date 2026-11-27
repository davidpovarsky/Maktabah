# Native Reader identity guard correction

This follow-up changes only the two newly added UITextView identity comparisons in `Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift`, based on donor `a1e12fd377c0909df535c96d1a61f54bef5001a7`.

Each site now obtains both identities with `XCTUnwrap(... as? Int)` before comparing nonoptional integers. The real producer uses `ObjectIdentifier(textView).hashValue` and an integer viewport object field; negative and zero values remain valid. No product source, existing original selector, request/process/TextKit check, UI action, corpus oracle or admission gate changed.

## Focused result

The actual baseline and candidate assertion blocks, together with the original `demand` function, were extracted verbatim and compiled with Swift 6.4.3 and real XCTest/Corelibs on Oracle Linux. Two XCTest methods exercise the two distinct assertion sites for each JSON fixture.

| Fixture | Baseline at both sites | Candidate at both sites |
| --- | --- | --- |
| Matching positive integer | Accepted | Accepted |
| Matching negative integer | Accepted | Accepted |
| Matching zero integer | Accepted | Accepted |
| Both identity fields missing | Incorrectly accepted | XCTUnwrap fails |
| Both fields are strings | Incorrectly accepted | XCTUnwrap fails |
| Selection identity missing | Rejected | XCTUnwrap fails |
| Viewport identity missing | Rejected | XCTUnwrap fails |
| Different integers | Rejected | Rejected |

Candidate: 3 valid payloads × 2 sites accepted; 5 invalid payloads × 2 sites rejected. Baseline incorrectly accepted 2 invalid payloads × 2 sites. The raw failing XCTest logs are deliberately retained. They are expected rejection controls, not hidden failures or native application test results.

The wrong-type fixture specifically uses strings. This small control is scoped to missing values, string casts, integer equality and signed integer preservation; it is not a general JSON schema or Foundation bridging audit.

## Source and evidence

Before SHA256: `aa7077b3ba994c3d35aa25c71e8f9986057b140f748774c866af426074da3bf2`.

After SHA256: `74d27daf2acf14b3a8fac14eb80f41bb93833b4beaf17eadad4b0a43da043392`.

The exact reverse patch recovers the donor file byte for byte. Both compile commands exited 0 without warnings. `validation/attempt-1/RESULT.json` binds the source, verbatim blocks, compiled harnesses, commands, fixtures, outcomes and logs. `SOURCE_AND_ACCEPTANCE.json` records the complete artifact hashes.

No app SDK build, full test-target compilation, simulator UI run, production corpus run or physical-device test was performed for this follow-up. The donor's recorded iPhoneSimulator27 typecheck predates these eight added binding lines and remains attributed to its own exact source. The final integrated candidate still requires its real SDK and native acceptance.

## Intake

Cherry-pick the original donor `a1e12fd377c0909df535c96d1a61f54bef5001a7` and then only this narrow follow-up commit. Do not merge the donor's whole laboratory ancestry. The separate Settings test chain remains `11efcc05486cab36119476fc5d7051ccb392ebde` then `f75eb8f16a4c826e829ebe613c88de9788b3291f`.
