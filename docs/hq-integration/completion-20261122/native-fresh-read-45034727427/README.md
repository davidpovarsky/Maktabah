# Original fresh-read Native run 45034727427

The actual run is FAILURE: **0 PASS / 1 FAIL / 0 SKIP / 0 NOT_RUN**, one selected XCTest on immutable head `81039998e66bba1d7310455d80a3c50e59785699`, attempt 1. The selected case executed for 213.80960595607758 seconds and failed at HanlinConsumerAcceptanceTests.swift:361 while waiting for the original End book access button identifier. App/UI builds, exact Host48 result reuse, cache saving and owned simulator cleanup passed. This is not a whole-Native qualification.

The two original GitHub archives were downloaded once by job_041c7b413891 and verified by SHA256 and ZIP CRC. Their original bytes were not regenerated. Evidence artifact 14761420336 is 10,898,591 bytes, SHA256 `25c24bcdf22efb89313fca1e0824f78d650071b8f55314739e6f440ca3f791c2`, with64 payload members. Its complete bytes are [original-evidence.zip](original-evidence.zip). Captures artifact14761187084 is130,386,192bytes, SHA256 `dc2aa8d14000c55be8b0a4e12c3b6e40bdcc5b4bc3faa5ef80a6caaf8648f936`, with1460members; the complete archive remains at the exact owned Sentinel path in INTAKE.json. Its full member inventory and selected unmodified raw captures are retained here. Every selected capture was compared byte for byte with its original archive member before Git retention. Publication caused zero additional GitHub artifact downloads.

## Actual finding

The consent drag worked: both the containing row and native child switch reported value1, with sibling endpoint/model unchanged. The original Connect action completed and the original chat sheet reopened for ספר החינוך. The final AX hierarchy exposes the real End book access button with the inherited parent identifier `otzaria-hanlin-book-access`, rather than its explicit child identifier `otzaria-hanlin-end-book-access`. The original text disclosure, composer and disabled Send button are present. The root reviewer inspected the actual after-reopen PNG as well as the complete AX hierarchy. These bytes prove the observed connection state and identifier collision; they do not turn the failed XCTest into PASS.

| Capture | Raw file |
|---|---|
| After consent drag AX | [7AD49B7F-9783-4B88-A0B0-BC8B69FB7FD2.txt](captures/7AD49B7F-9783-4B88-A0B0-BC8B69FB7FD2.txt) |
| Before original Connect AX | [343121AD-918C-439E-9238-CB99207053FA.txt](captures/343121AD-918C-439E-9238-CB99207053FA.txt) |
| After original dismiss/reopen AX | [BD3887AE-1379-4B12-8E44-504B7EFF34EA.txt](captures/BD3887AE-1379-4B12-8E44-504B7EFF34EA.txt) |
| After original dismiss/reopen screenshot | [B1F44DD3-678D-4E7A-8D93-8F4AFC6EF496.png](captures/B1F44DD3-678D-4E7A-8D93-8F4AFC6EF496.png) |

## Exact correction and next run

The reviewed source commit `3b4345bd0ae33b83c2ff4ae7697164343f0792b8` adds only `.accessibilityElement(children: .contain)` before the access section's parent identifier. All acceptance test files are unchanged from this failed run. Bound head `6591bba49d2b5a28d02b763c4360406843fce4cf` changes only exact source bindings and preparation evidence. [The next original case,45041601629](https://github.com/davidpovarsky/Maktabah/actions/runs/45041601629), attempt1, was activated by one expected-head fast-forward; sole finite observer is job_2f400520baa8. Its result was pending when this evidence was retained. No Live key or Send was used in either focused Native case.

Observer job_7dbb19c2f56b ended on a transport TLS timeout; its receipt is preserved. Only after it was terminal did successor job_ffe0441b6683 observe the actual run completion. Both receipts are included. Their failures/status never replaced the actual XCTest result.
