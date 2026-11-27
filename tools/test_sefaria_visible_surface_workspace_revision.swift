// Verbatim original setter callback/revision methods are inserted below.
// Presentation/geometry are not simulated as source publications.
import Foundation
private struct RevisionFailure: Error { let message: String }
@MainActor private final class WorkspaceRevisionBoundary {
    enum Host { case profiles }
    enum OriginalChange { case presentation }
    struct OriginalHost { let token: UUID; let stateOwnerID: UUID }
    enum OwnedChange { case sidebar; case host(Host, UUID, OriginalChange) }
    final class OwnedSetterAllowance {
        private var available = true
        func consume(_ change: OwnedChange) -> Bool {
            guard available else { return false }; available = false; return true
        }
    }
    private(set) var originalStateRevision: UInt64? = 0
    private var hosts: [Host: OriginalHost] = [:]
    private var ownedChange: OwnedSetterAllowance?
    private var invalidations = 0
    private func invalidateRetainedSources() { invalidations += 1 }
__WORKSPACE_METHODS__
    private func sidebarObserver() -> () -> Void {
        { [weak self] in
__SIDEBAR_BODY__
        }
    }
    struct Result: Codable { let name: String; let passed: Bool; let detail: String? }
    static func run() -> [Result] {
        var results: [Result] = []
        func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
            if !value() { throw RevisionFailure(message: message) }
        }
        func test(_ name: String, _ operation: () throws -> Void) {
            do { try operation(); results.append(.init(name: name, passed: true, detail: nil)) }
            catch { results.append(.init(name: name, passed: false, detail: String(describing: error))) }
        }
        test("original State publication changes foreign-source revision without a Workspace grant") {
            let owner = WorkspaceRevisionBoundary(), state = UUID()
            owner.hosts[.profiles] = .init(token: UUID(), stateOwnerID: state)
            owner.originalStateWillChange(host: .profiles, stateOwnerID: state, change: .presentation)
            try expect(owner.originalStateRevision == 1 && owner.invalidations == 1, "foreign original publication was invisible")
        }
        test("one authorized original setter is still a publication to foreign retained routes") {
            let owner = WorkspaceRevisionBoundary(), state = UUID()
            owner.hosts[.profiles] = .init(token: UUID(), stateOwnerID: state)
            owner.ownedChange = .init()
            owner.originalStateWillChange(host: .profiles, stateOwnerID: state, change: .presentation)
            try expect(owner.originalStateRevision == 1 && owner.invalidations == 0, "owned setter hid its original publication")
        }
        test("equal and A-B-A original setter calls cannot collapse to one state") {
            let owner = WorkspaceRevisionBoundary(), state = UUID()
            owner.hosts[.profiles] = .init(token: UUID(), stateOwnerID: state)
            for _ in 0..<3 { owner.originalStateWillChange(host: .profiles, stateOwnerID: state, change: .presentation) }
            try expect(owner.originalStateRevision == 3, "equal original publications were coalesced")
        }
        test("stale original host setter still invalidates the foreign source") {
            let owner = WorkspaceRevisionBoundary()
            owner.originalStateWillChange(host: .profiles, stateOwnerID: UUID(), change: .presentation)
            try expect(owner.originalStateRevision == 1 && owner.invalidations == 1, "wrong-host publication was ignored")
        }
        test("owned Sidebar request publication remains visible to a foreign route") {
            let owner = WorkspaceRevisionBoundary(); owner.ownedChange = .init()
            owner.sidebarObserver()()
            try expect(owner.originalStateRevision == 1 && owner.invalidations == 0, "owned sidebar request hid its publication")
        }
        test("Sidebar request/isRequested publications each advance original revision") {
            let owner = WorkspaceRevisionBoundary(), callback = owner.sidebarObserver()
            callback(); callback()
            try expect(owner.originalStateRevision == 2 && owner.invalidations == 2, "sidebar publication cycle disappeared")
        }
        test("original revision exhausts permanently and never wraps") {
            let owner = WorkspaceRevisionBoundary()
            owner.originalStateRevision = .max
            owner.originalStateWillChange(host: .profiles, stateOwnerID: UUID(), change: .presentation)
            try expect(owner.originalStateRevision == nil, "original revision wrapped or remained available")
            owner.sidebarObserver()()
            try expect(owner.originalStateRevision == nil, "later source publication rearmed exhausted revision")
        }
        return results
    }
}
@main private struct WorkspaceRevisionControls {
    @MainActor static func main() throws {
        let results = WorkspaceRevisionBoundary.run(), failures = results.filter { !$0.passed }.count
        struct Output: Codable { let scope: String; let passed: Int; let failed: Int; let results: [WorkspaceRevisionBoundary.Result] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(Output(scope: "verbatim original Workspace setter revision controls; native NOT_RUN",
            passed: results.count - failures, failed: failures, results: results))
        print(String(decoding: bytes, as: UTF8.self)); exit(failures == 0 ? 0 : 1)
    }
}
