# Wave 3 release preflight — 27 November 2026

Observed on 26 November 2026, 22:25–22:36 UTC (27 November in Asia/Hebron). This evidence-only lane preserves live signing/Apple prerequisites and the historical Native116 failure inventory. It does **not** complete final product acceptance, sign an application, or upload a beta.

## Confirmed facts

- Integration source inspected: `29a731e273f9a757c743c49e182fece0e8047d46`.
- App Store Connect: ChavrusaText, app `6809559414`, bundle `com.davidpovarsky.chavrusatext`, team `NA6HPWARQ2`. At 22:30:35Z the latest build remained **1.0.0 (11201), VALID, not expired**, ID `78f4cf1f-d84a-4a57-aa1d-de472790916c`. No new upload was observed or performed.
- Existing internal group חברותא, ID `04958ecd-edac-4820-b277-8cc626e1ff64`, has access to all builds. This establishes the existing group configuration, not availability of a new candidate.
- Current App Store profile `4E665D33-3317-4924-85D5-7E786F6BBD07` / API ID `2498S5G3V2` is ACTIVE, IOS_APP_STORE, expires 7 September 2027. Installed entitlements contain exactly the three required App Groups and Associated Domains. All 84 linked profiles were enumerated; no further page remained.
- Existing m1 SSH keychain context reports one valid Apple Distribution identity `644940FCF25D1730DBD1BF7596AEBA7229E2B8FD`. Direct Sentinel daemon context reports zero; use the established pinned SSH route and existing signing helpers for actual signing, with no replacement credentials or trust changes.
- Internal export options remain `/Users/m1/builds/_preflight/chavrusatext-final-internal-export-20261126.OR7qIPNh/Otzaria-InternalTestFlight-ExportOptions.plist`, SHA-256 `8153f7871fe8c1d87dec6a7948bf4afb5928a8c4c524a5d25ca31892bc26b390`. The older B8A profile has the groups but lacks Associated Domains; it is not the final profile for these source entitlements.
- Mac free space was 43,313,436 KiB (44,352,958,464 bytes) at 22:26:20Z. Xcode 27.0 (27A266a), iOS 27.0 and 27.2 runtimes were installed. Another Hanlin build and unrelated simulators were present. No cleanup, simulator mutation, build, test, profile mutation or signing operation was performed by this lane.

## Historical test evidence

The original Native116 application source is `f2e3fecbd3e6f36d8a8b7edd7c95e6015acb48fb`, control checkout `ec14460748dc79818b1a7a3f269a54e3a1ddfaa9`. Original baseline SHA-256 is `0754ec183a78623bd2392a8250bb32e7e1e922d9c181584f0992da5090066c64`.

| Group | Passed | Failed | Skipped | Device |
| --- | ---: | ---: | ---: | --- |
| 11-index | 5 | 0 | 0 | iPad Pro 11-inch (M5) |
| 11-reader | 33 | 8 | 0 | iPad Pro 11-inch (M5) |
| 11-search | 19 | 3 | 0 | iPad Pro 11-inch (M5) |
| 11-sidebar | 5 | 0 | 0 | iPad Pro 11-inch (M5) |
| 11-window | 0 | 2 | 0 | iPad Pro 11-inch (M5) |
| 11 | 7 | 5 | 0 | iPad Pro 11-inch (M5) |
| phone | 13 | 16 | 0 | iPhone 18 Pro |

The 34 failures and original messages are preserved in the adjacent JSON/Markdown. Later focused fixes must be reconciled by the integration owner; this old baseline is not a new verdict on 29a731e2. The four larger XCResults remain archived on Windows as recorded in SOURCE_AND_ARTIFACTS.json.

## Reusable products and required runners

The preserved Release simulator app at `/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/actual-paired-production-release.Hguhbz1S/Maktabah/build/ReleaseDerivedData/Build/Products/Release-iphonesimulator/Maktabah.app` has executable SHA-256 `bec95d552569790f5f34e6a81c56f0ab3c2130585925c591e78ca0b7c9014fb1`, production profile, version 1.0.0 / build 195. The receipt binds app source 31b29f8f and prepared checkout a6497250. Comparison 31b29f8f→29a731e2 changes only six lines in NativeRoutingAcceptanceTests.swift; application and dependency trees are unchanged. The app may be reused for correctly attributed baseline investigations. Its old test runner is not a newly built final 29a test runner.

Native116: existing `.github/workflows/otzaria-final-native-push.yml`, `runtime27_final_push.py --mode ui --stage native` and `runtime27.py` with exact EXPECTED_CHECKOUT_SHA/RUNTIME27_MODE. Release114+2: `otzaria-final-release-push.yml` and `runtime27-release-stages.py` retain build/native/production handoffs. Manifest counts: 63+34+1+15 native UI and 1 production UI =114, plus two separate oracles. Neither is passed by this report.

The full-v40 driver `Scripts/CI/library-v40-focused-native.py` expects its qualified Debug app and source-bound receipt, owns its new simulator and reserves 24 GB plus a positive OS margin and observed concurrent growth. `hq-v32-prebuilt-native.py` separately qualifies v32. A Release app must not be silently substituted into either Debug receipt. The existing underlying bootstrap launcher accepts an explicit app path for a separately attributed baseline run; this does not replace final native gates.

Before shipping, the owner must select the actual final candidate, reconcile engine/study deliveries, run the authentic owner/signature gate and Native116/Release114+2 plus original production/integration gates, preserve provenance/license acceptance, and use the existing signed workflow's matching `ui_acceptance_run` gate. Then perform device Archive, SDK after-archive verification, manual export using the current profile, IPA entitlement/code-sign verification, Apple validation/upload, processing VALID and internal availability readback. Build 195 is a simulator build number. The workflow computes release numbers as GITHUB_RUN_NUMBER*100+GITHUB_RUN_ATTEMPT; the next upload must be unique and monotonic relative to 11201.

No current physical-device success is inferred. PHYSICAL_QA_AFTER_BETA.md preserves the post-beta sequence and adds the requested iPhone/UI/system-surface checks. Original core checklist source b6c300f7 is explicitly separate from the inspected 29a tree.

## Scope and verification

Only this documentation/evidence directory changes. No source, test, signature, policy, workflow, dependency, profile or keychain file is edited. Mechanical checks validate JSON, the 82/34/0 total, 34 unique failure IDs, scoped Git diff and SHA256SUMS. They are not application tests. Original source-bound acceptance gates remain unchanged.
