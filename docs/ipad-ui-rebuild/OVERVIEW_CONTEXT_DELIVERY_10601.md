# Overview context replacement — experimental delivery10601

`[נועם | DEV] [MAIN_SESSION]` / `[רוני | QA] [MAIN_SESSION]`, NORMAL; same primary session, no independent subagent review, Asana writes or main merge.

**Delivered:** ChavrusaText **1.0.0 (10601)**, Apple processing **VALID**, observed **2026-11-09T08:31:17.612731+00:00**. This is the corrected experimental build;10401 contains the rejected overview sheet, and10501 was cancelled before upload.

App/source commit `70810eec46ad1fec6f30d983bf31e5f922dacb61`, pushed branch `experiment/ipad-ui-faithful-from-9401`. The later documentation commit does not change the delivered application. [Signed delivery run](https://github.com/davidpovarsky/Maktabah/actions/runs/42581923971) succeeded through archive/export, strict signing/entitlement checks, Apple validation, upload and processing. [App Store Connect TestFlight](https://appstoreconnect.apple.com/apps/6809559414/testflight). Tester assignment/installability was not independently checked; no App Store review/public release was submitted.

## Result and source contract

The tab overview replaces the existing reader context using the pinned browser's native `.overCurrentContext` contract. The original reader stays mounted; opening/closing neither rehosts it nor writes/restores its offset. Selecting its active card closes without navigating again. The presentation is owned by the actual parent reader controller, outside the transparent SwiftUI representable subtree; its previous definesPresentationContext value is restored on close/teardown. The closed wrapper passes touches through. Existing profile-management sheets are separate flows.

Reference: DuckDuckGo apple-browsers `f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32`, [MainViewController+Segues.swift lines241/290/293/297](https://github.com/duckduckgo/apple-browsers/blob/f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32/iOS/DuckDuckGo/Main/MainViewController%2BSegues.swift#L241). [Apple's current-context retention contract](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle/overcurrentcontext). The WebKit snapshot transition is not invented for the reader; presentation changes the full context without that browser-specific animation. Source Grid/List/group controls remain; missing previews are truthfully labeled.

## Actual verification and limits

[Native70810 run](https://github.com/davidpovarsky/Maktabah/actions/runs/42571097678) built/installed/launched the actual app. Its overall result is **FAIL**, retained as such: landscape and phone methods are **EXECUTED_PASS**, portrait fails an initial nonzero-position precondition **before opening the overview**. No assertion was removed or relabeled.

| Actual layout | Runtime | Verified returns | Evidence |
|---|---|---:|---|
| iPad Pro11-inch (M5), landscape | iPadOS27.2 /24B8117 |3|48pt nonzero: Done + active card; original19pt: Done; real Grid/List/full-context controls |
| iPhone18 Pro | iOS27.2 /24B8117 |3|Same real nonzero/normal-font checks and return paths |
| iPad portrait | Not verified |0|Mixed run stopped at source0/rawY0 before overview; real setup pans advanced to Mitzvah103 through original pull navigation |

All **six** executed returns preserve the identical actual TextKit instance, canonical book/locator, first visible source character, reader frame and source-pixel/raw-native offset. All observed pixel/raw differences are **zero**. The48pt preference is only a test launch argument; the normal19pt sequence is also captured, and release defaults are unchanged. No replacement text or offset assignment is used. The read-only DEBUG observer is absent from the release binary.

Manual full-display review covered four before/Grid/List/after sequences. Only explicitly passed cases are shown in the review gallery; failed workflow/device statuses remain in its provenance. Raw PNG copies are byte-identical; contact sheets resize full frames without cropping, masking or UI synthesis.

Review folder: `C:\Users\DAVID\Code\ChavrusaText-rebuild-package-20261104\evidence\overview-replacement-review-70810eec`. See `index.html`, `execution-provenance.json`, `viewport-measurements.json`, `visual-review.json` and `inventory.json` with original/copy image hashes. Native raw evidence: `C:\Users\DAVID\Code\ChavrusaText-rebuild-package-20261104\evidence\overview-replacement-70810eec`.

[Open the real full-frame gallery](C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/overview-replacement-review-70810eec/index.html) · [Exact measured returns](C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/overview-replacement-review-70810eec/viewport-measurements.json).

[Portrait-only run42577170165](https://github.com/davidpovarsky/Maktabah/actions/runs/42577170165) used the same app/test commit and unchanged strict method. Attempt1 did **not** execute the app case: original-prototype installation/CoreSimulator service hung. Attempt2 did **not** execute it: Sparkle2.9.1 binary download returned HTTP504 during package resolution. These attempts are infrastructure failures, not portrait presentation/retention acceptance. Portrait,13-inch, physical-device and the broader full-matrix/Production quality gate remain open. Earlier unrelated Native failures remain recorded in STATUS/history.

Real Xcode27.1 SDK/object-code checks passed. The actual Simulator component step passed **45 UIKit tests**, including four real presentation/binding/hit-routing/context-restoration tests, plus **4 chrome** and **45 Palette** Swift Testing tests. Portable checks passed **379/379 assertions** and **61 workspace persistence/migration/rollback/scene/semantic-location checks**. These do not substitute for unexecuted app layouts.

## Owner-authorized experimental scope

The current chat explicitly requests corrected TestFlight after actual Simulator review. The owner's pasted request, lines252–260, expressly permits experimental TestFlight despite failing Native checks, requires successful build/sign/upload and honest limits, and prohibits calling it full quality approval or merging to main. Six real returns and full-frame review were complete before this upload was dispatched. An earlier agent-added requirement to wait for all three layouts was stricter than that owner instruction; it was corrected without weakening any test or changing a result. Portrait work continued in parallel and its limits are reported above. This release is **experimental**, not Production quality approval.

## Signed artifact and identity

| Field | Verified value |
|---|---|
| Display / version / build | ChavrusaText /1.0.0 /10601 |
| Team | NA6HPWARQ2 |
| Bundle | com.davidpovarsky.chavrusatext |
| App Groups | group.com.davidpovarsky.chavrusatext; group.com.davidpovarsky.itorah |
| iCloud | iCloud.com.davidpovarsky.chavrusatext; CloudDocuments + CloudKit |
| Push / debugging | production APNs; get-task-allow=false |
| Extensions created/shipped | None / none in exported IPA |
| Apple app/build IDs |6809559414 /97bff7e2-0fe6-457a-9db0-bf32794e88c2 |
| IPA SHA256 |`47224199ae3a97ac2890eee0c9c9e1183bfc2a3e7a56aaca7fdf7f7e88346fa7` |

Existing identity/certificate/capabilities were reused; no credential or identity change. Real macOS codesign/profile/entitlement/archive/export verification and Apple validation passed. Local downloaded IPA checksum matched the CI manifest, and ZIP/Info.plist inspection independently verified bundle/display/version/build. Windows is not presented as a codesign authority.

Release evidence: `C:\Users\DAVID\Code\ChavrusaText-rebuild-package-20261104\evidence\testflight-overview-70810eec`; signed IPA, checksum, non-secret logs, Apple processing JSON and `local-artifact-verification.json`. Artifact ID13659795589, `ChavrusaText-production-signed-ipa-10601`.

[Downloaded IPA](C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/testflight-overview-70810eec/export/ChavrusaText-production-10601.ipa) · [Independent local checksum/plist verification](C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/testflight-overview-70810eec/local-artifact-verification.json).

## Changed implementation files and boundaries

Correction baseline: `e95e4269f3bd48a95fcbdb3a9f630c48f55650cc`. Production Swift changes are downstream only:

- `Source/ChavrusaText/ReaderHost/ReaderOverviewPresentation.swift` — new public UIKit context adapter.
- `Source/ChavrusaText/ReaderHost/ChavrusaReaderHost.swift` — iPad overview connection/lifetime.
- `Source/ChavrusaText/ReaderHost/CompactStudyWorkspaceHostModifier.swift` — enabled-phone connection/lifetime.
- `Source/ChavrusaText/StudyWorkspace/UI/StudyGroupsOverview.swift` — explicit close/active-card behavior and existing themeTint.
- `Source/ChavrusaText/Testing/ReaderViewportAcceptanceObserver.swift` — DEBUG-only real viewport/native facts.

Tests: `MaktabahTests/ReaderOverviewPresentationTests.swift`, `Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift`. CI: `Scripts/CI/typecheck-faithful-ui-tests.py`, `test-faithful-tabs-in-app.py`, `verify-otzaria-xcode-project.py`, `run-faithful-ipad-matrix.py`, `prepare-pinned-sharp-libvips.py`; `.github/workflows/sefaria-embedded-validation.yml`, `.github/workflows/ios-testflight.yml`.

The protected project file has exactly four additive iOS registration entries for the new adapter; authorization and exact delta are in OWNERSHIP_AND_AUTHORIZATION.md /PROTECTED_HUNKS.diff. Original reader/library/search/notes/navigation source, package pins and signing settings are unchanged by this correction. Inspector remains pinned to19d1b35397af4f10ae70cfb3f444c9de87383b53. Existing source audit records33 comparisons/14 normalized identical ports.

The fork-owned workflow edits only add a guarded pre-npm cache step. The same original Sharp0.32.6/libvips8.14.5 and NAPI7 archives come through their original GitHub release API; normal npm/prebuild-install integrity/extraction/loading remains. Locked versions/npm integrity and cache algorithms are guarded. libvips uses its original publisher SHA512; addon SHA256 pins are explicitly observed from original assets, whose publisher digest is absent. No vendor/source/pin upgrade, mirror, skip/force flag, trigger/signing/acceptance change. A single bounded repeat of a reported native fixture HTTP502/503/504 failure retains the first report and every original profile/book-count/SHA gate.

Detailed chronological pre-delivery diagnostics remain in [the immutable70810 report](https://github.com/davidpovarsky/Maktabah/blob/70810eec46ad1fec6f30d983bf31e5f922dacb61/docs/ipad-ui-rebuild/OVERVIEW_CONTEXT_REPLACEMENT.md). Earlier10401/10501 or failed/pre-app captures are not proof of this delivered correction.
