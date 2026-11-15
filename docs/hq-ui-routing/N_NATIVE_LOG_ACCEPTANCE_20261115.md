# Actual native receipt acceptance and shared log retention

The five NativeRoutingAcceptanceTests remain NOT_RUN until the manager's native candidate is built/executed. They now reuse **FaithfulReaderUIBase's existing UUID-scoped workspace/actual-container oracle**. There is no new test application, synthetic receipt exporter, smoke bypass or hidden completion element.

Positive URL acceptance requires all of the following in the same real test:

1. Actual Library mounted and History absent before the system URL; before screenshot/hierarchy retained.
2. A fresh generated request UUID, exact requested backend, mode and test workspace namespace retained in a JSON XCTest attachment.
3. The system `XCUIApplication.open` entry invokes the actual existing onOpenURL path; actual History navigation bar appears and no link error is present.
4. The test locates the current app data container through the already-existing exact workspace-namespace sidecar oracle. It waits for the real `Documents/OtzariaLogs/otzaria-reader.log`, not an in-memory/result echo.
5. Exactly one actual producer line matches request/backend/native.history/currentTab, contains an exact UInt64 generation and required Embedded epoch, increasing exact UInt64 scene revisions, and a scene key present in this actual namespace's workspace sidecar. UIKit scene IDs remain opaque strings, never UUID conversions.
6. The full raw actual reader log, matching canonical receipt, actual workspace JSON and after screenshot/hierarchy are attached with keepAlways. A visible screen without its canonical receipt fails the test; a receipt without the actual visible History screen also fails.

Cold entry first records Library/History absence, terminates the process, then opens the generated URL. Invalid version records its exact request/backend and must show the real error while History remains absent. Settings' system Intent/Siri journey remains separately NOT_RUN; package/type compilation is not that acceptance.

The production witness now uses a transparent child UIViewController's **viewDidAppear completion**, real layout/foreground/window/modal ancestry, effective opacity and almost-full window intersection. SwiftUI onAppear, pre-animation layout, a requested model or AX presence alone cannot acknowledge completion. It adds no controls or altered visual layout.

## Manager-owned helper proposal

`N_PROPOSED_NATIVE_LOG_RETENTION.diff` is unapplied and changes only the existing `Scripts/CI/run-faithful-ipad-matrix.py` collector. It is generated with the other registration proposals. When the actual selected suite is NativeRoutingAcceptanceTests, it:

* Resolves the exact owned simulator UDID/app bundle's **post-XCTest** data container via simctl, rather than reusing the pre-install container hint or scanning other apps' logs.
* Copies the real reader log into `build/artifacts/native-routing-logs-<label>/otzaria-reader.log`.
* Records actual UDID/container, collection time, byte count, SHA256 and artifact path in collection.json and the existing device report.
* Records MISSING/COLLECTION_ERROR honestly; it fabricates no empty log or success. Such missing evidence cannot close UI03/05 even if another test reports pass.

The runner remains manager-owned and was not edited by N. Existing XCTest attachment export is retained, so per-test raw logs/receipt attachments survive even if later tests reinstall/relocate the app container. Apply the proposal with the reviewed native package/hooks in the next coherent source/binary batch; there is no workflow trigger or release-gate change.

The exact source also consumes P945b483f0b01fe6722c0bd0dd864d8fe249cd973. N's borrowed reader context survives the entire Core action, and own actual-Core/sink tests cover success plus revocation during Core's final shared backend await on all three synthetic backends. This is contract evidence, not advertisement of a production reader route (the concrete driver still only supports History/Settings roots).
