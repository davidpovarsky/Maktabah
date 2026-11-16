"""Extract the complete app waiter into the established explicit native shell."""
import hashlib,json,pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[1]
source_path='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift'
before='--before' in sys.argv
raw=subprocess.check_output(['git','-C',str(root),'show','41cb39e3df7ee8e8d942d2f12d961efad83a41b7:'+source_path]) if before else (root/source_path).read_bytes()
source=raw.decode().replace('\r\n','\n')
def declaration(start):
    at=source.index(start); end=source.index('\n    }',at)+len('\n    }');return source[at:end]
method=declaration('    private func waitForMount(')
waiter=declaration('    private struct MountWaiter {')
templates=root/'docs/hq-native-binding-integration/mount-wait-owner'
boundary=(templates/'N_MOUNT_WAIT_NATIVE_BOUNDARY_20261115.swift').read_text()
boundary=boundary.replace('NMountWaitBoundary','Phase1MountWaitBoundary')
boundary=boundary.replace('    struct Session { let sceneID: UIStableID }','    @MainActor final class Session {\n        let sceneID: UIStableID; var foreground: Bool\n        init(sceneID: UIStableID, foreground: Bool) { self.sceneID = sceneID; self.foreground = foreground }\n    }')
boundary=boundary.replace('func existing(_ manager: ObjectIdentifier, scene: String)', 'func existing(_ manager: ObjectIdentifier, scene: String, foreground: Bool = true)')
boundary=boundary.replace('session: .init(sceneID: sceneID)', 'session: .init(sceneID: sceneID, foreground: foreground)')
boundary=boundary.replace('func mount(_ manager: ObjectIdentifier, scene: String) {\n        existing(manager, scene: scene)\n        mountWaiters.removeValue', 'func mount(_ manager: ObjectIdentifier, scene: String, foreground: Bool = true) {\n        existing(manager, scene: scene, foreground: foreground)\n        if foreground { activate(manager) }\n    }\n    func activate(_ manager: ObjectIdentifier) {\n        guard let entry = registrations.values.first(where: { $0.managerID == manager }) else { return }\n        entry.session.foreground = true\n        let scene = entry.session.sceneID.rawValue\n        mountWaiters.removeValue')
boundary=boundary.replace('    // EXACT_WAITER_TYPE',waiter).replace('    // EXACT_WAIT_FOR_MOUNT_METHOD',method)
tests=(templates/'N_MOUNT_WAIT_TESTS_20261115.swift').read_text().replace('NMountWaitBoundary','Phase1MountWaitBoundary').replace('NMountWaitTests','Phase1ForegroundMountTests').replace('NWaitTaskHolder','Phase1WaitTaskHolder')
tests+='''
extension Phase1ForegroundMountTests {
    func testAlreadyMountedInactiveOwnerWaitsForItsOwnActivation() async throws {
        let owner = NSObject(), other = NSObject(), b = Phase1MountWaitBoundary()
        let id = ObjectIdentifier(owner)
        b.existing(id, scene: "inactive-exact", foreground: false)
        b.existing(ObjectIdentifier(other), scene: "active-other")
        let task = Task { @MainActor in try await b.run(id) }
        try await b.untilCount(1)
        XCTAssertTrue(b.queued(id), "An external URL must await the exact scene's activation, not fail before system foreground delivery")
        b.activate(ObjectIdentifier(other))
        XCTAssertTrue(b.queued(id), "Another foreground scene cannot consume this request")
        b.activate(id)
        let actual = try await task.value
        XCTAssertEqual(actual.rawValue, "inactive-exact")
        XCTAssertEqual(b.waiterCount, 0)
    }
    func testInactiveSceneWaitRemainsCancellableAndDoesNotRetarget() async throws {
        let owner = NSObject(), b = Phase1MountWaitBoundary(), id = ObjectIdentifier(owner)
        b.existing(id, scene: "inactive", foreground: false)
        let task = Task { @MainActor in try await b.run(id) }
        try await b.untilCount(1)
        task.cancel()
        do { _ = try await task.value; XCTFail("Inactive wait ignored cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(b.waiterCount, 0)
        b.activate(id)
        XCTAssertEqual(b.waiterCount, 0)
    }
}
'''
target=root/'Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests'
(target/'Phase1ForegroundMountBoundary.swift').write_text(boundary,encoding='utf-8',newline='\n')
(target/'Phase1ForegroundMountTests.swift').write_text(tests,encoding='utf-8',newline='\n')
report={'mode':'BEFORE_41cb' if before else 'AFTER_WORKING_SOURCE','source':source_path,'sourceSHA256':hashlib.sha256(raw).hexdigest(),'completeMethodSHA256':hashlib.sha256(method.encode()).hexdigest(),'testsSHA256':hashlib.sha256(tests.encode()).hexdigest(),'boundary':'Real Foundation Tasks/continuations/MainActor; native registration/foreground delivery explicit shell. No Apple/UIKit claim.'}
(root/'docs/phase1'/('MOUNT_WAIT_RED_INPUT.json' if before else 'MOUNT_WAIT_GREEN_INPUT.json')).write_text(json.dumps(report,indent=2)+'\n')
print(report['mode'])
