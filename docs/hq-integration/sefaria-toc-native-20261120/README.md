# Sefaria TOC: original Retry, localized controls, and Native acceptance declarations

Task: `1219850068707719` (Sefaria L10N / original TOC loading and empty states).
Parent source: `09e7ae372d005952e05422abcda9209aa15b2fae`, the separately tested
original mobile-input parser/adapter tranche. The active Native98 source
`60a57972acb28739ec738565083bf17fb7503028` is unchanged by this branch.

**Native12 and Apple55 are NOT_RUN.** The actual Windows transport experiment
failed and is retained below. The separately executed rejected-start lifecycle
regression passed after its reproduced failure. Syntax parsing is not Apple SDK
typechecking or evidence that a SwiftUI control mounted.

## Product changes

The existing `iOSTOCView` receives an optional original-owner Retry callback.
Its failure view presents that action through a native SwiftUI Button. All three
current Reader callers supply their existing `ReaderViewModel.loadTOC(book:)`
operation: the Reader workspace, original iPad layout, and compact bottom toolbar.
The original view model, loading/error state machine, selection closures, Reader
resolver, persistence, original network retry policy, and engines are retained.

The existing loading label and Retry action now have Hebrew translations.
The original icon-only TOC disclosure gains a localized Expand/Collapse label
that includes the actual node title, plus a stable identifier using that same
original node ID. Its original action, layout and expansion binding are unchanged.
The four added localization keys are `Retry`, `Loading Table of Contents...`,
`Expand %@`, and `Collapse %@`. Every previous catalog entry is deep-equal.

Identifiers for the original segmented selector, list, loading, failure, empty,
and Retry controls allow acceptance to inspect actual original UI. No list,
renderer, canonical reference generator, or success response is introduced here.

## Twelve new Native declarations

`EXTRA_SELECTION.json` contains six iPad and six iPhone identifiers. All four
previous Sefaria test declarations and their entire original file prefix are
byte-identical after Git LF normalization. No canonical R27/Release manifest is
changed; Root must review and register the twelve methods on a new immutable
source before dispatch.

The eight Embedded cases cover Hebrew and English on both device types. They use
the original catalog palette, actual Reader, native TOC and original list actions:
Berakhot/Eruvin 12a and 12b, the genuine Berakhot chapter structure, Genesis
chapter 2, Rashi's real nested section, and Haggadah's original named section.
Canonical backend/work/reference locators and the existing Reader TextKit/glyph/
frame/title checks remain required. Hebrew disclosure placement and localized
accessibility labels are inspected. Rashi's existing Reader resolver presents a
bounded chapter; this case makes no claim of exact segment focus.

The four Remote cases exercise an actual held request, a real URL Loading
failure, the original visible loading/error state, and an original user Retry.
They require the original Reader locator/title to remain stable through the
fault and require real nonempty TOC content and canonical navigation afterwards.

## Exact transport boundary and ownership

The Remote path is the original `BookTOCViewModel` child Task through
`BackendCoordinator.navigationStructures` / its original `perform` child Task,
`SefariaHybridNavigationStore`, `SefariaRemoteStore`, and `SefariaHTTPClient`.
The active Embedded route is the original Hermes `OfflineOnline.textToc` and
pinned `api.js`; it does not call that HTTP client. The four fault cases therefore
test the Remote boundary only.

The hook is compiled only for a DEBUG Simulator or the explicit Foundation
acceptance build. Actual app admission requires miniTest10, the real bundle ID,
an explicit launch flag, the Remote backend, and a UUID workspace namespace in
the owned Simulator application's Documents directory. The command/release files
have closed schemas and bounded regular-file reads. The test pins the original
container metadata bytes and canonical application UUID root before every write.
Only its nonce-specific command/release files are written.

A mounted, loaded original Genesis TOC owner invokes its existing reload
callback synchronously within a TaskLocal context. The real child Task must
carry that context to the exact GET for
`https://www.sefaria.org/api/v2/raw/index/Genesis`. A process-local URLProtocol
property identifies that one request; no token header is added. The gate admits
one tag and one claim. The protocol supplies no response bytes. It holds for at
most 25 seconds and, when released, supplies `URLError.dataNotAllowed`; the
unchanged client maps this to its real offline error without an automatic retry.
The user's subsequent Retry runs outside that TaskLocal context and uses the
original transport. Native acceptance requires matching owner/nonce evidence
and actual visible loading/error/content; a diagnostic file alone is insufficient.

The worker retains a locked lifetime object, not a Sendable claim about
`URLProtocol`. A recursive lock orders begin, claim completion, callback and
stop, including a reentrant stop from URL Loading. Late installation is cancelled.
Rejected admission uses the same completion path. The held observation is
recorded under the same lifetime guard. The weak protocol owner and cleared
worker avoid an unbounded retain cycle.

The non-DEBUG HTTPClient body reconstructs to the exact original Git source
after removing the two guarded hook sites and appended support. `SOURCE_PRESERVATION`
records this check. `APP_MEMBERSHIP.json` verifies that all six modified app Swift
files already belong to their original project source phases; no app Swift file
or project membership was added.

## Executed evidence and retained failures

| Attempt | Source and boundary | Actual result |
| --- | --- | --- |
| transport-attempt1 | Entire HTTPClient plus same-file test access | DEBUG initializer shadow compile failure; **0 executed** |
| transport-attempt2 | Initializer corrected | Swift 6 rejected sending URLProtocol self; **0 executed** |
| transport-attempt3 | Locked lifetime instead of a self capture | Strict Swift 6 compile succeeded; **52 executed, 29 passed / 23 failed** |
| transport-lifetime-red | Exact SHA-verified whole HTTPClient prefix from attempt3, same three controls | **0 passed / 3 failed** |
| transport-lifetime-green | Final source with guarded rejected-start and held observation | **3/3 passed** |
| toc-native-syntax | Seven actual modified Swift source/test files | Seven parse commands exited zero, no warnings; **no typecheck/runtime claim** |

The three lifecycle cases directly call the original URLProtocol subclass with a
declared URLProtocolClient double: stop before a rejected start, exactly one
declined-start completion, and reentrant stop preventing a late callback. They
execute the complete production class rather than a rewritten state-machine
fragment. Final GREEN finished at 12:34:14 UTC; the seven syntax commands finished
at 12:34:15 UTC. Before/after source hashes, commands, timings and raw output are
retained. No compiler cache or corpus was duplicated.

The 52-case whole-client experiment uses the real production client, TaskLocal,
one-shot admission and URLProtocol. Its explicit boundaries are an owned temporary
directory, the original owner's child-Task shape, and a canned successful retry
payload. It does not execute the UI or Hermes and does not contact the provider.
The exact case inventory must remain complete and unique.

### Windows FoundationNetworking property-copy failure

The first failed assertion in each process is preservation of the local property
through `NSMutableURLRequest` to `URLRequest`. Consequently, the failure protocol
does not claim the request and the successful-response fixture is called too
early; the remaining negative oracles correctly fail. The 23 failures are not
converted into passes, skipped, or removed.

The observed PATH has one `FoundationNetworking.dll` from Swift runtime 6.3.3
(SHA-256 `2526b5b278644974aa9f01eb01e9152b509ea2264e01e39bc29411ad73c15c9f`).
The official release tag `swift-6.3.3-RELEASE` resolves to
`6da8413b9a088eb59badcf0665aa73116db51edf`. Its
[NSURLRequest mutable copy implementation](https://github.com/swiftlang/swift-corelibs-foundation/blob/6da8413b9a088eb59badcf0665aa73116db51edf/Sources/FoundationNetworking/NSURLRequest.swift)
does not copy `protocolProperties`; the
[URLRequest bridge](https://github.com/swiftlang/swift-corelibs-foundation/blob/6da8413b9a088eb59badcf0665aa73116db51edf/Sources/FoundationNetworking/URLRequest.swift)
uses that mutable copy. The captured newer main commit
`f8e09f2abbd31afebf9fda438c2a958834e24573` explicitly copies those properties.
This source difference agrees with the observed Windows failure. A reproducible
build equality between the installed DLL and that source commit is not claimed.

Apple documents the same
[protocol-property API](https://developer.apple.com/documentation/foundation/urlprotocol/setproperty(_:forkey:in:)).
Apple behavior must be executed before the Native fault cases. Neither the
official documentation nor this Windows investigation is an Apple pass.

## Required Apple gate

From the selected original Xcode toolchain on macOS, use an existing writable,
owned module cache and a fresh output directory:

```sh
python3 tools/hq-sefaria-toc-transport.py --output build/sefaria-toc-apple55 --module-cache build/ci-module-cache
```

The module-cache directory must already exist. The driver uses the actual
selected `swiftc`, `-j1`, Swift 6 complete concurrency checking, DEBUG and the
explicit acceptance define. It copies eight entire production files and the
same-file test appendix without source stripping. It allows 180 seconds for
compilation and 20 seconds for each separate process.

The default gate runs all **52 original transport controls plus the three
separate lifecycle controls**. It requires exact ordered case inventories, zero
failed cases, zero process failure and unchanged input hashes. There is no
Windows exclusion, property override, token header or success fallback.
`--lifetime-only` is solely the clearly labeled three-case regression mode used
above; it must not be used as the Apple55 gate.

The full 55-case gate and all twelve Native methods remain **NOT_RUN** at this
commit. A passing Foundation gate would still leave the original VM/TaskLocal
inheritance, real UI, original provider retry, Hebrew/English rendering and
native accessibility behavior for Native acceptance. Installed-offline content,
physical disconnection, physical devices and spoken VoiceOver remain distinct
unverified acceptance requirements.

## Evidence verification

`ARTIFACTS.json` has uniform gzip records under `artifacts` and a separate
`sourceInputs` array. For each artifact, read the committed Git blob, check its
`artifactSHA256`, decompress it, and check `rawBytes` and `rawSHA256`. Compare
each committed source Git blob with `canonicalLFSHA256`. Retained preparation
snapshots describe their historical intermediate source; the final source
inventory and GREEN input manifest identify the delivered source.

The index records 132 compressed artifacts (250,826 bytes) and ten source/test
inputs. Executables, libraries and module caches are not committed. No failed
attempt or original acceptance oracle is removed.

The complete staged ten-file source diff is retained losslessly as
SOURCE_DELTA.patch.gz. The preliminary tracked-only diff is retained separately.
Compression avoids treating context-only patch spaces as newly introduced code
whitespace; no production source line was changed for that documentation check.
