import Foundation
import OtzariaUIRouting
import ChavrusaUIRoutingHost

struct ControlFailure: Error { let message: String }
@MainActor func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw ControlFailure(message: message) }
}
@MainActor func refuses(_ operation: () throws -> Void) throws {
    do { try operation(); throw ControlFailure(message: "unexpected acceptance") }
    catch is ControlFailure { throw ControlFailure(message: "unexpected acceptance") }
    catch {}
}

@main struct PublicationControls {
    @MainActor static func main() async {
        var results: [[String: Any]] = []
        func test(_ name: String, _ body: @MainActor () async throws -> Void) async {
            if CommandLine.arguments.count > 1 && !name.contains(CommandLine.arguments[1]) { return }
            do { try await body(); results.append(["name": name, "pass": true]) }
            catch { results.append(["name": name, "pass": false, "error": String(describing: error)]) }
        }
        await test("exact unmodified publication remains live") {
            let owner = MaktabahNativeAnnotationListPublication(), proof = try owner.capture()
            try proof.validate(); try proof.validate()
        }
        await test("source publication permanently revokes a retained witness") {
            let owner = MaktabahNativeAnnotationListPublication(), proof = try owner.capture()
            owner.willPublish(); try refuses { try proof.validate() }
            let current = try owner.capture(); try current.validate(); try refuses { try proof.validate() }
        }
        await test("original equal search setter revokes before its didSet no-op") {
            let model = OriginalSearchSetterCapsule(), proof = try model.nativeRoutingPublication.capture()
            model.searchText = ""
            try refuses { try proof.validate() }
            try require(!model.nativeRoutingPublication.searchPending && model.applies == 0, "no search fabricated")
        }
        await test("original debounce refuses catalog while original task is pending") {
            let model = OriginalSearchSetterCapsule()
            model.searchText = "actual query"
            try require(model.nativeRoutingPublication.searchPending, "actual task pending")
            try refuses { _ = try model.nativeRoutingPublication.capture() }
            try await Task.sleep(for: .seconds(0.4))
            try require(!model.nativeRoutingPublication.searchPending && model.applies == 1, "actual task settled")
            _ = try model.nativeRoutingPublication.capture()
        }
        await test("original search A-B-A does not restore prior witness") {
            let model = OriginalSearchSetterCapsule(), old = try model.nativeRoutingPublication.capture()
            model.searchText = "B"; model.searchText = ""
            try refuses { try old.validate() }
            try await Task.sleep(for: .seconds(0.4))
            try refuses { try old.validate() }
            try require(model.applies == 1, "only latest original debounce applied")
        }
        await test("old cancelled task cannot settle a newer original task") {
            let owner = MaktabahNativeAnnotationListPublication()
            let first = owner.beginOriginalSearch(), second = owner.beginOriginalSearch()
            owner.finishOriginalSearch(first)
            try require(owner.searchPending, "new task retained")
            try refuses { _ = try owner.capture() }
            owner.finishOriginalSearch(second)
            let proof = try owner.capture(); try proof.validate()
            owner.finishOriginalSearch(first); try proof.validate()
        }
        await test("duplicate task completion cannot revoke a new settled witness") {
            let owner = MaktabahNativeAnnotationListPublication(), token = owner.beginOriginalSearch()
            owner.finishOriginalSearch(token); let proof = try owner.capture()
            owner.finishOriginalSearch(token); try proof.validate()
        }
        await test("owner lifetime removal refuses retained witness") {
            var owner: MaktabahNativeAnnotationListPublication? = .init()
            let proof = try owner!.capture(); owner = nil
            try refuses { try proof.validate() }
        }
        await test("bounded observations prune released weak witnesses") {
            let owner = MaktabahNativeAnnotationListPublication()
            for _ in 0..<128 { let proof = try owner.capture(); try proof.validate() }
            let retained = try (0..<64).map { _ in try owner.capture() }
            try require(retained.count == 64, "bounded real retained observations")
            try refuses { _ = try owner.capture() }
            owner.willPublish(); try refuses { try retained[0].validate() }
            _ = try owner.capture()
        }
        await test("revision exhaustion is terminal and cannot rearm") {
            let owner = MaktabahNativeAnnotationListPublication()
            owner.controlSetRevision(.max)
            let proof = try owner.capture(); owner.willPublish()
            try refuses { try proof.validate() }; try refuses { _ = try owner.capture() }
            owner.willPublish(); try refuses { _ = try owner.capture() }
        }
        let report: [String: Any] = ["boundary": "Exact publication source plus original search setter/debounce bodies; applyFilter is an explicit domain boundary; no UIKit/DB/Core/app/native execution", "passed": results.filter { $0["pass"] as? Bool == true }.count, "failed": results.filter { $0["pass"] as? Bool == false }.count, "cases": results]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self))
        if report["failed"] as? Int != 0 { exit(1) }
    }
}
