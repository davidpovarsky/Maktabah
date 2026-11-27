// The runner inserts VERBATIM methods from the production scene binding below.
// UIKit/source-owner collaborators are reduced to boundary fixtures; the runtime
// token and its synchronous lock are the real production bridge implementation.
// These controls do not claim a compiled iOS host or native acceptance.
import Foundation

fileprivate extension SefariaRPCSessionEpoch {
    func membershipControlReady() {
        update { $0.ready = true; $0.listeners = true; $0.transport = true }
    }
}
private struct UIRouteError: Error {
    enum Code { case unavailable, staleState }
    let code: Code
    let detail: String
    init(_ code: Code, _ detail: String) { self.code = code; self.detail = detail }
}
private struct MembershipFailure: Error { let message: String }

@MainActor private final class MembershipBoundary {
    private final class OriginalSourceProof {
        let runtime: SefariaEmbeddedSurfaceRuntimeToken
        private var valid = true
        init() throws {
            let authority = SefariaRPCSessionEpoch(); authority.membershipControlReady()
            runtime = try authority.retainSurface()
        }
        func invalidate() { valid = false }
        func validate() throws {
            try runtime.validate()
            guard valid else { throw UIRouteError(.staleState, "fixture original source invalidated") }
        }
    }
    @MainActor private final class SourceEntry {
        let original: OriginalSourceProof
        init() throws { original = try .init() }
    }
    private struct Pending {
        let token = UUID()
        let requestID: UUID
        let validate: @MainActor () throws -> Void
        var applied = false
        var openedNewSurface = false
    }
    private struct RetainedRequest: Sendable {
        let requestID: UUID
        let pendingToken: UUID
        let source: SourceEntry
    }
    private struct Observed { let source: SourceEntry }
    private struct Completed { let observed: Observed }
    private var sources: [UUID: SourceEntry] = [:]
    private var pending: Pending?
    private var completed: Completed?
    private var finishes = 0

    private func validate(_ source: SourceEntry) throws { try source.original.validate() }
    private func validateSource(requestID: UUID) throws {
        guard let entry = sources[requestID] else { throw UIRouteError(.staleState, "missing source") }
        try validate(entry)
    }
    private func finish(requestID: UUID, completed: Bool) {
        guard pending?.requestID == requestID else { return }
        finishes += 1; pending = nil
    }

    // BEGIN_VERBATIM_PRODUCTION_METHODS
__SOURCE_METHODS__
    // END_VERBATIM_PRODUCTION_METHODS

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw MembershipFailure(message: message) }
    }
    private static func rejects(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    private static func setup(_ admission: @escaping @MainActor (MembershipBoundary, UUID) throws -> Void = { _, _ in }) throws
        -> (MembershipBoundary, UUID, SourceEntry) {
        let owner = MembershipBoundary(), requestID = UUID(), entry = try SourceEntry()
        owner.sources[requestID] = entry
        owner.pending = .init(requestID: requestID, validate: { try admission(owner, requestID) })
        return (owner, requestID, entry)
    }
    struct Result: Codable { let name: String; let passed: Bool; let detail: String? }
    static func run() -> [Result] {
        var results: [Result] = []
        func test(_ name: String, _ operation: () throws -> Void) {
            do { try operation(); results.append(.init(name: name, passed: true, detail: nil)) }
            catch { results.append(.init(name: name, passed: false, detail: String(describing: error))) }
        }
        test("exact active original source publishes once") {
            var validations = 0, publications = 0
            let (owner, requestID, _) = try setup { _, _ in validations += 1 }
            try owner.withSource(requestID: requestID) { _ in publications += 1 }
            try expect(publications == 1 && validations == 2, "one original operation was not preserved")
        }
        test("first admission callback removing map membership prevents publication") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.sources.removeValue(forKey: requestID) }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "removed membership accepted")
            try expect(publications == 0, "source was published after callback released it")
        }
        test("reentrant active release invalidates and finishes the exact request") {
            var publications = 0
            let (owner, requestID, entry) = try setup { owner, requestID in owner.releaseSource(requestID: requestID) }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "active release accepted")
            try expect(publications == 0 && owner.pending == nil && owner.finishes == 1, "active release did not finish safely")
            try expect(rejects { try entry.original.validate() }, "released original proof remained live")
        }
        test("same request identifier with replacement source is not the original source") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.sources[requestID] = try SourceEntry() }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "replacement source accepted")
            try expect(publications == 0, "replacement source inherited an earlier grant")
        }
        test("same request identifier with a replacement Pending is a different operation") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in
                owner.pending = .init(requestID: requestID, validate: {})
            }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "replacement pending accepted")
            try expect(publications == 0, "copied pending survived replacement")
        }
        test("finished admission cannot execute from a copied Pending") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.finish(requestID: requestID, completed: false) }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "finished pending accepted")
            try expect(publications == 0, "finished admission published an old action")
        }
        test("report callback release is rejected on the same synchronous boundary") {
            let (owner, requestID, entry) = try setup()
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in owner.releaseSource(requestID: requestID) } },
                       "report callback released source without rejection")
            try expect(rejects { try entry.original.validate() }, "released report retained authority")
        }
        test("report callback completion cannot return through stale copied Pending") {
            let (owner, requestID, _) = try setup()
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in owner.finish(requestID: requestID, completed: false) } },
                       "completed report returned under stale pending")
        }
        test("last admission callback is followed by fresh membership validation") {
            var validations = 0
            let (owner, requestID, _) = try setup { owner, requestID in
                validations += 1
                if validations == 2 { owner.sources.removeValue(forKey: requestID) }
            }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in } }, "last callback removal accepted")
        }
        test("original source invalidation is checked after admission callback") {
            var publications = 0
            let (owner, requestID, _) = try setup { owner, requestID in owner.sources[requestID]?.original.invalidate() }
            try expect(rejects { try owner.withSource(requestID: requestID) { _ in publications += 1 } }, "invalid original proof accepted")
            try expect(publications == 0, "invalid source executed before the late check")
        }
        test("begin cannot publish Pending after its admission callback releases source") {
            let owner = MembershipBoundary(), requestID = UUID(), entry = try SourceEntry()
            owner.sources[requestID] = entry
            try expect(rejects { try owner.begin(requestID: requestID) { owner.releaseSource(requestID: requestID) } },
                       "begin restored released source")
            try expect(owner.pending == nil, "begin created a stale pending operation")
        }
        test("begin cannot overwrite a reentrant Pending") {
            let owner = MembershipBoundary(), requestID = UUID(), other = UUID()
            owner.sources[requestID] = try SourceEntry()
            try expect(rejects { try owner.begin(requestID: requestID) {
                owner.pending = .init(requestID: other, validate: {})
            } }, "begin overwrote another operation")
            try expect(owner.pending?.requestID == other, "earlier begin stole later ownership")
        }
        test("only exact successfully completed receipt proof survives normal release") {
            let (owner, requestID, entry) = try setup()
            owner.pending = nil; owner.completed = .init(observed: .init(source: entry))
            owner.releaseSource(requestID: requestID)
            try entry.original.validate()
            try expect(owner.sources[requestID] == nil, "normal release retained map ownership")
        }
        test("unrelated completed proof does not retain a released source") {
            let (owner, requestID, entry) = try setup()
            owner.pending = nil; owner.completed = .init(observed: .init(source: try SourceEntry()))
            owner.releaseSource(requestID: requestID)
            try expect(rejects { try entry.original.validate() }, "foreign completed proof retained source")
        }
        return results
    }
}

@main private struct MembershipControls {
    @MainActor static func main() throws {
        let results = MembershipBoundary.run(), failures = results.filter { !$0.passed }.count
        struct Output: Codable { let scope: String; let passed: Int; let failed: Int; let results: [MembershipBoundary.Result] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(Output(scope: "verbatim source boundary controls; UIKit/native not run",
            passed: results.count - failures, failed: failures, results: results))
        print(String(decoding: bytes, as: UTF8.self)); exit(failures == 0 ? 0 : 1)
    }
}
