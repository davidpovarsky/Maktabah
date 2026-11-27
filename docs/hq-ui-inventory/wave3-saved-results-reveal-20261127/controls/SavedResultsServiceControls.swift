import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

struct Failure: Error { let message: String }
@MainActor func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw Failure(message: message) }
}
@MainActor final class ServiceFixture {
    typealias Service = NativeSavedResultIntentService
    var snapshot = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var records: [Service.Record]
    var windows: [NativeIntentService.Destination]
    var calls = 0, reads = 0
    var mode = "ok"
    var after: (() -> Void)?
    var beforeSecondCatalog: (() -> Void)?
    var observed: UISceneAcknowledgement?
    init(kind: Service.Kind = .result) throws {
        let scene = UIStableID(rawValue: "original-scene")!
        records = [try .init(reference: .init(backend: .otzaria, kind: kind, token: UUID()), title: "Actual visible saved label", sceneID: scene)]
        windows = [.init(backend: .otzaria, destination: .init(rawValue: "native.savedResults")!, title: "Saved Results", sceneID: scene)]
    }
    func service() -> Service {
        Service(read: { self.reads += 1; if self.reads == 2 { self.beforeSecondCatalog?() }
            return .init(snapshot: self.snapshot, records: self.records)
        }, windows: { self.windows }, navigate: { request in
            self.calls += 1
            let route = RouteSpec(requestId: self.mode == "wrong-request" ? UUID() : request.requestID,
                destination: .init(rawValue: self.mode == "wrong-parent" ? "native.search" : "native.savedResults")!,
                backend: .otzaria, presentation: .init(kind: .sheet),
                state: .init(selectedItemID: self.mode == "missing-row" ? nil : request.record.itemID),
                scene: .init(kind: .specific, sceneID: request.window.sceneID, expectedRevision: 5),
                expectedBackendSnapshot: request.expectedSnapshot)
            let receipt = UISceneReceipt(requestId: request.requestID, route: route,
                backendSnapshot: request.expectedSnapshot, sceneID: request.window.sceneID,
                basedOnSceneRevision: 5, appliedSceneRevision: 6)
            let response = UISceneAcknowledgement.acknowledged(receipt)
            self.observed = response; self.after?()
            return response
        })
    }
    func run(_ service: Service) async throws -> UISceneAcknowledgement {
        try await service.reveal(kind: records[0].reference.kind, identifier: records[0].id, windowIdentifier: windows[0].id)
    }
}
@main struct ServiceControls {
    @MainActor static func main() async {
        var cases: [[String: Any]] = []
        func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
            do { try await body(); cases.append(["name": name, "pass": true]) }
            catch { cases.append(["name": name, "pass": false, "error": String(describing: error)]) }
        }
        for kind in [NativeSavedResultIntentService.Kind.folder, .result] {
            await run("exact original \(kind.rawValue) canonical return") {
                let f = try ServiceFixture(kind: kind), service = f.service()
                let value = try await f.run(service)
                try NativeIntentOutcome.requireVisibleAcknowledgement(value)
                try check(f.calls == 1 && value == f.observed, "one actual host call/return")
            }
        }
        await run("metadata carries no query title path or SQL ID") {
            let f = try ServiceFixture(), service = f.service()
            let values = try service.records(kind: .result), windows = try service.windows()
            try check(values.count == 1 && windows.count == 1 && f.calls == 0, "metadata only")
            try check(!values[0].id.contains(values[0].title) && !values[0].id.contains("original-scene"), "opaque original reference")
        }
        await run("changed catalog before dispatch refuses without any UI operation") {
            let f = try ServiceFixture(), service = f.service()
            f.beforeSecondCatalog = { f.records = [] }
            do { _ = try await f.run(service); throw Failure(message: "expected stale source") }
            catch is Failure { throw Failure(message: "unexpected source acceptance") } catch {}
            try check(f.calls == 0, "no dispatch")
        }
        await run("wrong original window refuses") {
            let f = try ServiceFixture(), service = f.service(), record = f.records[0]
            do { _ = try await service.reveal(kind: .result, identifier: record.id, windowIdentifier: "foreign"); throw Failure(message: "accepted foreign") }
            catch is Failure { throw Failure(message: "accepted foreign") } catch {}
            try check(f.calls == 0, "no dispatch")
        }
        await run("malformed reference refuses before metadata or operation") {
            let f = try ServiceFixture(), service = f.service()
            do { _ = try await service.reveal(kind: .result, identifier: f.records[0].id + "=", windowIdentifier: f.windows[0].id); throw Failure(message: "accepted malformed") }
            catch is Failure { throw Failure(message: "accepted malformed") } catch {}
            try check(f.calls == 0, "no dispatch")
        }
        for mode in ["wrong-request", "wrong-parent", "missing-row"] {
            await run("\(mode) preserves actual host return as failure") {
                let f = try ServiceFixture(), service = f.service(); f.mode = mode
                do { _ = try await f.run(service); throw Failure(message: "accepted malformed ACK") }
                catch let error as NativeSavedResultIntentService.Failure {
                    try check(error.acknowledgement == f.observed && f.calls == 1, "actual return retained")
                }
            }
        }
        await run("source retirement after actual ACK cannot become service success") {
            let f = try ServiceFixture(), service = f.service(); f.after = { f.records = [] }
            do { _ = try await f.run(service); throw Failure(message: "accepted retired source") }
            catch let error as NativeSavedResultIntentService.Failure {
                try check(error.acknowledgement == f.observed && error.status == .staleState, "observed ACK retained honestly")
            }
        }
        await run("window removal after actual ACK preserves original receipt and refuses") {
            let f = try ServiceFixture(), service = f.service(); f.after = { f.windows = [] }
            do { _ = try await f.run(service); throw Failure(message: "accepted removed window") }
            catch let error as NativeSavedResultIntentService.Failure {
                try check(error.acknowledgement == f.observed, "observed ACK retained")
            }
        }
        await run("post-effect cancellation retains actual return") {
            let task = Task { @MainActor in
                let f = try ServiceFixture(), service = f.service()
                f.after = { withUnsafeCurrentTask { $0?.cancel() } }
                do { _ = try await f.run(service); throw Failure(message: "accepted cancelled") }
                catch let error as NativeSavedResultIntentService.Failure {
                    try check(error.acknowledgement == f.observed && error.status == .cancelled, "actual return retained")
                }
            }
            try await task.value
        }
        let report: [String: Any] = ["boundary": "actual new service + original Core/UIRouting/Host value types; explicit metadata and navigation boundary; no Core/app/native execution", "passed": cases.filter { $0["pass"] as? Bool == true }.count, "failed": cases.filter { $0["pass"] as? Bool == false }.count, "cases": cases]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys,.prettyPrinted]), as: UTF8.self))
        if report["failed"] as? Int != 0 { exit(1) }
    }
}
