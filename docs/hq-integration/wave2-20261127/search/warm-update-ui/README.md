# Same-process Search Data readiness around ordinary Settings Retry

Status: additive XCTest helper with actual Apple SDK source typecheck. No application build, Simulator run, Settings update or warm UI acceptance is claimed by this checkpoint.

The new internal `OriginalSearchDataUpdateReadiness` helper is appended to the existing registered GlobalSearch test source. The previous 184397 bytes are unchanged (SHA256 fa4cbfc31a73d0265efc572923b756d7e39aa092c70fbdee36e06f0804a66de9). It navigates the original Settings, root Search, More, Search Data, Close and root Library controls. It never submits a query, installs a package, repairs an index, changes a backend or opens another book.

## Settings owner integration

The sole owner of ProductionOtzariaAcceptanceTests adds these calls inside the existing selector:

`Maktabah-iOSUITests/ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState`

Immediately after the recovered old v40 Reader and manifest checks, before the final original Settings Retry:

```swift
let warmSearchData = OriginalSearchDataUpdateReadiness(app: app, test: self)
let readyBeforeFinalRetry = try warmSearchData.captureReadyBeforeFinalRetry()
```

After actual success and target manifest validation, before the separate cold final launch, with the actual updated regular database file size:

```swift
_ = try warmSearchData.captureMismatchAfterFinalRetry(
    previous: readyBeforeFinalRetry,
    updatedDatabaseBytes: actualUpdatedDatabaseBytes
)
```

No terminate/relaunch is eligible between these calls. Both return to the existing Library tab; the caller continues its existing user-state and cold-restoration checks. This helper checkpoint does not include or typecheck that caller; the Settings owner retains a separate whole-caller SDK receipt.

## Admission and visible assertions

The helper requires the ordinary production Otzaria English/en_US launch and forbids fixture/bootstrap/data-root overrides. It obtains the actual app PID from the public XCUIApplication.debugDescription Application field, retains each complete hierarchy and its digest, rejects the test-runner PID, and requires the same PID through both observations and their navigation. A missing or changed hierarchy PID fails; there is no substitute PID.

Before final Retry, the original Search Data view must show Books ready, Otzaria ready with 7925185 documents, and Zayit ready with v40-20261123094345. After success it must show Books ready with both old v40 indexes incompatible or unavailable. Zayit's exact expected size/release mismatch follows the actual source validation order and actual updated file size. The mismatch must remain stable for three seconds. Source runtime status strings are currently Hebrew even under en_US; this test explicitly does not claim R06 localization acceptance.

The final original Library Updates screen is dismissed by its original Settings back action when needed, then the existing settings-done-button. Root tab selection is scoped to the original tab bar.

## Retained attachment contract

- `settings-update-warm-search-ready-before-final-retry`
- `settings-update-warm-search-mismatch-after-final-retry`

Both JSON payloads have schemaVersion, sequenceID, processID, capturedAtUnix, applicationHierarchySHA256, statuses, phase, processIdentitySource, launchArguments and scope. The second additionally binds previousProcessID, previousCapturedAtUnix, previousApplicationHierarchySHA256 and actualUpdatedDatabaseBytes. Full original PID hierarchies and screenshots are separate retained attachments. These prove only what a later real passed case actually observes; no missing attachment is success.

## Actual compile evidence

Mac retained input directory:
`/Users/m1/builds/otzaria-wave2-search-20261127/warm-update-ui-typecheck/attempt1`.

Whole GlobalSearch parse exited 0. Exact existing Published/context/R08 source plus new warm helper and the complete actual MaktabahUITestBase typechecked with actual XCTest and the iPhoneSimulator27.0 SDK, Swift 6 strict concurrency, exit 0. Xcode 27.0 build27A266a, Apple Swift6.4. The compiler emitted existing isolation/unused-result warnings; raw diagnostics are retained, not treated as UI success.

`apple-inputs-and-logs.tar.gz` retains all exact source inputs, runner, metadata and raw logs, without normalizing their bytes. Readable RESULT/INPUT/COMPILE_RUN/LAUNCH copies and SOURCE_RECEIPTS bind them. There was no app compilation, Simulator launch, UI test execution or network mutation.
