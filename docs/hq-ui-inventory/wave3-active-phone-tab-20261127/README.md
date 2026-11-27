# Original already-active phone Reader presentation

Product source: `81ea1a360f027993362a9fa690e15fd2b38a4c52`.
Exact integrated parent: `ec5385e863a478e368c7de47264474a440fd0734`.

## Problem and original source

The original `iOSNavigationManager.selectTab(id:)` returns immediately when the requested tab is already active. On iPhone, the original Library Back button can hide that Reader while leaving the actual tab, book, Reader and workspace selection alive. The previous typed Reader-tab catalog and binding excluded that state because the original selection action could not present it.

Calling the original `presentReader(book)` would be incorrect for this operation: that larger action publishes a mode again and finds existing tabs by book ID. Two original tabs can hold the same book and still have different UUIDs and Reader identities.

This packet changes exactly two existing files. It uses the original tab-presentation operation and the already integrated Core, scene, Viewer-parent and workspace reservation path.

## Product change

The five existing presentation assignments in `selectTab` are factored into a private Manager helper in their original order. The ordinary action keeps its existing active-tab early return, outgoing Reader save/inspector behavior, active-tab setter, lookup and persistence call. Its helper callback is explicitly nonthrowing and empty. `FINAL_ORDINARY_MANAGER_INVERSE.json` verifies that removing this narrow addition restores the complete original Manager bytes, not just a similar method. The initial draft inverse remains separately preserved in the evidence archive.

For the already-active, nil-hidden phone case, the original Manager issues an opaque presentation owner to the retained Reader-tab binding. It captures the exact request, tab UUID, book object and Reader object before foreground or parent awaits. It grants no effect. Its apply is called only within the same existing Core-authorized workspace reservation operation, after the original Viewer parent is ready.

The real `selectedBook.willSet` consumes the single permitted publication before existing Group and Observation callbacks. The real `didSet` confirms the exact book, mode and revision after the original Group callback. Reentrant, equal or second setters retire the source. These passive hooks never prevent an ordinary UI setter from completing. A weak registration plus exact owner comparison prevents an old released owner from clearing or borrowing a replacement.

The Manager owner calls the shared original presentation helper and original `persistCurrentSession`. It checks the retained binding between the original assignments and around persistence. Source revocation stops subsequent effects; an already executed partial effect does not become acknowledgement. There is no book hydration, tab replacement, new mode assignment, new Core grant, timer, new deadline or fallback UI.

The binding advertises and admits only the additional already-active phone state with a nil original presentation. It requires exactly one actual book publication for that case. Already-visible active tabs and all ordinary tab-switch cases keep their existing paths. Final success still requires the existing original Reader/TextKit surface and Core completion checks.

## Source verification and preserved failures

The original counter-only experiment compiled the real original selectedBook/Observation setter bodies. Three ordinary behavior controls passed, while the negative ABA control failed: three original setter calls could leave the counter apparently advanced by only one. This demonstrates why final counter equality alone cannot authorize the new presentation.

The corrected actual Manager/setter/helper/owner bodies passed **26 source controls**. They cover exact duplicate-book tab identity, nil-hidden admission, original ordinary selection behavior, one-use publication, reentrant release/replacement, setter ABA, replay, source revocation, cancellation and partial effects. Both complete changed product files also passed Apple-target syntax parsing.

These controls use explicit app-domain, Group callback and persistence boundaries. They do not execute the complete real `persistCurrentSession`/`saveCurrentState`, Store/Adapter/Core/SwiftUI stack, UIKit presentation, system App Intents, production corpus or physical devices. The full Reader-tab binding received source review and syntax parsing; this packet does not claim an Apple SDK typecheck or app/native acceptance.

Two genuine candidate compilation failures remain preserved. The first exposed that an optional callback is escaping; the second exposed Swift's throwing default-callback rule. The final helper has a nonescaping callback and the ordinary caller passes an explicit nonthrowing no-op. No control expectation was weakened or removed.

The independent release-preflight reviewer read the two source files and existing Adapter apply path, then confirmed the final nonescaping callback change. Its review was read-only and made no execution/native claim.

## Integration and evidence

No Session, Composition, Adapter, Core, test, PBX, catalog, dependency or upstream pin is changed. Both product files already have target membership. Root owns integration, current source admission, authentic owner approval and final native qualification.

`EVIDENCE.zip` contains exact input snapshots, extraction manifests, compiler/stdout/stderr logs, actual controller commands, all three attempt results, ordinary inverse proof and source diff. `EVIDENCE_MANIFEST.json` records each member's size and SHA-256. Archive members are byte-verified; no significant whitespace is normalized. Executables and the private module cache remain at the original retained paths listed in `RETAINED_ARTIFACTS.json`.

`NATIVE_ACCEPTANCE_PROPOSAL.md` describes the separate original-system selectors still needed. No selector or shared test helper was edited by this packet. Native and physical results remain **NOT_RUN**.
