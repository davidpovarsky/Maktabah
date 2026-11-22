# Hanlin Live7 failure intake

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44993301949
Attempt: 1. Terminal outcome: FAILURE.
Immutable checkout: 77c7df82ef5f822bf0b1dd7e08ff2b4b98d425d2.
Application/UI source: 0ea7218331d1441d37d06d43333e579f267056e3.

## Actual execution

The original simulator application and UI runner build passed. The single declared
HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent
case executed once on iPad Pro 11-inch (M5), iOS 27.2 (24B8117). Its actual case
duration was 78.00888001918793 seconds: zero passed, one failed, zero skipped.

The initial reader/independent paragraph locator, title, endpoint/model checks,
one original consent-switch tap and ON assertion completed. XCTest then tapped
the actual identified Connect button at t=42.97s. The following 30-second wait for
otzaria-hanlin-end-book-access failed at HanlinConsumerAcceptanceTests.swift:551:
"The original native dismissal must issue the source-qualified read session".

The case stopped before composing or sending its live prompt. It completed zero
verified provider conversations. There is no provider-result, tool-execution,
return-navigation, consent-revocation, Native116 or Release114 acceptance claim.

The matrix additionally records a first simctl get_app_container verification
timeout at 45 seconds and a successful second installation attempt. That setup
delay must not be reported as the 78-second XCTest case duration.

## Artifact and source verification

The sole artifact14743563942 (87,598 bytes) was downloaded once. Its full ZIP
SHA256 exactly matches the GitHub API digest
13b8464d57769bce384436b68c5b5230248f7fbcde189f2d84d9f365942aed35.
All22 ZIP payloads were retained, including all21 files indexed by admission.json;
every indexed byte count and SHA256 matched. No raw failure was rewritten.

SOURCE_VERIFICATION.json independently verifies all281 execution paths against
exact77c7 Git blob IDs, byte counts and SHA256. The Source, Vendor, project and UI
trees equal app0ea. Source-before and source-after JSON are byte-identical.
Five original runner-recorded binary hashes are stable before/after; raw binaries
are not in the Live allowlist, so this is not independent local binary-byte
verification.

## Privacy and cleanup boundary

The original runner reports private input staged, consumed and removed; no key in
child environment or XCTest arguments; zero log redactions; original artifacts
restored; owned simulator cleanup PASS. The exact-key/base64 scanner admitted the
fixed file allowlist. Raw result bundles, AX/screenshots/video and the provider
input/application container were deliberately excluded.

Root separately owns and verified the GitHub secret lifecycle DELETE204/GET404
at 2026-11-22T06:54:36.558829Z. This intake did not access, recreate or change any
credential or secret and did not start another watcher or run.

## Source diagnosis and limit

The source was read at77c7:
- ChatSession.configure constructs the immutable request and synchronously asks
  its native Owner to capture consent and close/reopen when consent is ON.
- ChatOwner.requestReadConnection retains one exact continuation and calls its
  existing requestClose(preservingContinuation:true).
- closeHanlinHostSession clears only the exact live registration and preserves
  pending consent.
- The real didDismiss callback clears the old presentation before opening the
  exact carried conversation/configuration.
- Original source, workspace, read-scope and configuration checks remain strict.

The available artifact proves the absent end-access control after the native tap.
It does not prove whether the action callback was entered, whether configuration
or currentness failed, whether dismissal arrived, or which reopen step failed.
There is no measured tap coordinate or post-tap AX/console in the admitted output.

The bounded next proposal is a finite typed stage journal (fixed phase/reason
enums and booleans only) around those original boundaries, collected as one
strictly validated and credential-scanned JSON through the existing Live runner.
No guard, source equality, consent behavior or XCTest assertion will be weakened.
No new run, source apply, live key or acceptance publication is authorized by
this intake alone; root reviews the concrete proposed change next.
