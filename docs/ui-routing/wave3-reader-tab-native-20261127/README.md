# Original Reader-tab system acceptance selectors

## Delivered scope and status

Source commit: **f5428b47eddac14da929c38ff2e308109607084f**.
Base: **aa5092cd9452c242a21b49442398e4c645a0d757**.
Branch: codex/otzaria-wave3-reader-tab-native-20261127.

This packet adds six actual-system XCTest selectors for the already integrated
OpenReaderTabIntent. It changes only the new
Maktabah-iOSUITests/NativeReaderTabAcceptanceTests.swift and an appended helper
extension in NativeRoutingAcceptanceTests.swift.

**Native execution: NOT_RUN. Apple SDK typecheck and App Intents metadata
validation: NOT_RUN.** The native tests require the final qualified original
app/XCTest build and the original real-UI simulator fixture. No simulator,
device, product process, app build, or native acceptance run was performed for
this packet. These are additive selectors, not six passing native results.

## Actual system and original-UI contract

The helper launches the existing canonical Reader fixture and verifies its
sealed original SQL/text oracle. It queries Apple's out-of-process
IntentDefinitions for a real NativeReaderTabEntity while the initial tab is
the sole original Reader. It retains that returned entity, creates a second
original Reader through the existing public-v2 newTab system setup, and checks
the setup's own independent original receipt.

Both live tabs then take their original ordinary UI selection and persistence
path. On iPad this is the UUID-labelled original native document strip. On
iPhone it is the existing title button, original Overview and UUID-labelled
Grid/List cell. These ordinary setup actions must not emit canonical native
receipts. Their persisted source/location state is captured before the
measured action.

The tested action is exclusively the real system
OpenReaderTabIntent.makeIntent(tab: cachedTab).run().

There is no generated entity reference, direct perform, app service import,
private URL for the target action, synthetic marker, substitute database,
injected workspace, or fabricated receipt.

Positive completion requires the same actual app PID, original scene,
profile/group, original tab UUID, unchanged tab identities/count, original SQL
locator and rendered TextKit text, unchanged persisted document source/location
semantics, and exactly one new canonical native.reader.tab/currentTab
receipt. The duplicate-book case keeps two actual distinct UUIDs while using
the initially queried entity.

Both negative cases first execute that same cached entity successfully and
require its actual positive receipt. The original UI then either closes the
tab through its existing UIKit context menu, or creates/selects an empty group
through the original All Tabs / Tab Groups / New empty group / Save controls.
The latter retains the old tab in the previous group's actual store, so it
tests foreign-group authority rather than deletion. Actual discovery must no
longer advertise the old entity.

The cached system invocation must now throw. The test compares the actual
receipt set and complete persisted workspace JSON except its monotonically
increasing bookkeeping revision. It observes the full original five-second
request bound for a late mutation or ACK, then verifies the actual surviving
Reader or original empty Reader and the same process. The observation does not
retry, renew permission, manufacture readiness, or infer success from a delay.

## Six explicit selectors

The exact class/method list and individual expected behavior are in
NATIVE_SELECTORS.json. Four selectors extend the original iPad test class;
two extend the existing phone class. No historical Native116, Release114+2,
controller selection list, existing assertion or existing timeout was edited.

These selectors use the original **miniTest10 v6 real-UI source fixture**.
They do not constitute production-v40 corpus acceptance, physical-device
acceptance, Siri voice delivery, or a TestFlight result. Production and final
aggregate gates remain owned by integration.

## Verification actually performed

- The original first **221,244 bytes** of NativeRoutingAcceptanceTests.swift
  remain byte-exact, SHA-256
  84032054d2c3e10ae91f7703e13d305866810bdbda516064d7cd1f49730724b0.
- All other **30 existing files** under Maktabah-iOSUITests remain byte-exact.
- Both changed Swift files passed swiftc -frontend -parse -target
  arm64-apple-ios27.0 using Oracle's Linux Swift 6.4.3. This checks syntax only;
  it does not resolve Apple SDK types or execute XCTest/App Intents.
- git diff --check passed.
- Source commit was pushed only to its explicit branch and independently read
  back with ls-remote.

The original command, stdout, stderr, complete old-file inventory, source pins
and result are preserved under evidence/attempt-1. The RESULT hash is
4bd86431a6d02181b4f863246a74fa882986acab3f1f0623df6c4e8265c3a664.
No prior failure, native receipt, package cache or app build was overwritten.

## Provenance and integration

Live upstream bismillah-100/Maktabah HEAD/main was checked read-only at
4203de5fd77beb119e5826e039be1a61325f7be0; merge base with this packet's base is
a0ed0df908a6cb38bc459d4baaeb400f447b2fc4. Neither changed test path exists in
that upstream tree. The existing native test file was introduced downstream in
d337c60896c6ef24af277697e6012ae1595c0335.

Both paths are downstream acceptance code. The same-file appended extension
uses existing private source/UI/receipt helpers without widening their
visibility or rewriting their implementation. The original UI, stores,
navigation owners, Core, protocols, SDK bytes, pins, source gates, owner
signatures, and Release assertions are unchanged.

Root must add the one new test file to the **Maktabah-iOSUITests Sources phase**.
No product-target membership, resource, catalog, entitlement or package change
is required. MEMBERSHIP.json records that exact requirement.

An independent read-only review was requested from release_preflight against
the immutable source commit. Its final findings are not implied by this
packet's source checks. Root retains integration and native-run ownership.

## Remaining risks and next proof

A qualified Apple build must establish actual XCTest/AppIntentsTesting API
typechecking and metadata discovery. The six exact selectors must then execute
through the original focused system/native wrapper with genuine fixture,
device, process, source and xctestrun identity. The original context-menu and
Overview accessibility hierarchy and persisted workspace timing remain native
observations to verify, not assumed successes.

The first implementation remains current Viewer-root, current profile/group
and current committed backend with already loaded live Readers. Global-page
parent continuation and typed Profile/Group switching are separate source
work; these tests do not claim those open paths implemented.

To revert only this test packet, revert its source commit. Existing test
prefixes and all product code remain unchanged.

### Exact state and receipt comparisons

The positive document comparison reuses the byte-unchanged
actualSiriReaderDocuments helper. It retains each document's outer backend and
these session fields: id, bookId, bookTitle, backendLocator, locator, contentId,
page, part, searchText, searchModeRaw, nearDistance and highlightTerms. It
excludes viewport/restoration bookkeeping: scrollPosition, selectedRange,
expandedNodeIDs, sidebarScrollPosition and isSidebarCollapsed. The enclosing
workspace revision is not part of that document projection. Separate native
checks retain the actual scene, profile/group, selected UUID and full tab
order/count. Ordinary original UI selection/checkpoint setup precedes capture.

The refusal comparison is deliberately separate: it compares the complete
actual workspace JSON, removing only its revision field. All original
document and viewport fields remain compared after the cached entity is
refused.

The unchanged requireNewSystemIntentReceipt computes the actual after-minus-
before receipt set, requires all original lines retained and exactly one
added line, then validates the exact eight fields, request UUID, backend,
epoch, increasing revision, destination, presentation and actual scene
membership. The new helper additionally binds that line to the initial actual
scene. It does not infer completion merely from the selected UUID or title.

Raw operational logs are stored as deterministic gzip transport, preserving
all original bytes and failures. The manifest pins compressed and original
uncompressed size/SHA separately. The source validation logs stay exact.
