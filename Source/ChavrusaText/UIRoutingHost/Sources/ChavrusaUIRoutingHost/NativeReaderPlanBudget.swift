import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Transport budget projection only. Core's bundled schema remains the source
/// of request bounds; Core still owns semantic validation/rights/resolution.
enum NativeReaderPlanBudget {
    static func request(for retained: UIValidatedRoute, original: ActionPortInvocation, now: UInt64) throws -> ActionRequest {
        let route = retained.route
        guard let content = route.content, route.requestId == original.requestId,
              route.backend == original.snapshot.backend, route.expectedBackendSnapshot == original.snapshot,
              route.scene.kind == .specific, route.scene.sceneID != nil, route.presentation.tabID != nil else {
            throw UIRouteError(.failed, "reader_plan_binding_mismatch")
        }
        guard now < original.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        let schema = try ActionRegistry.schema("action-request.v1.schema.json")
        guard let bounds = schema.object?["properties"]?.object?["deadlineMs"]?.object,
              let minimum = bounds["minimum"]?.unsignedInteger, let maximum = bounds["maximum"]?.unsignedInteger,
              minimum > 0, maximum >= minimum else { throw UIRouteError(.unavailable, "core_deadline_contract_unavailable") }
        // Round DOWN; rounding up to Core's minimum would extend the original
        // import budget. Too little time means no Core invocation at all.
        let remaining = (original.deadlineUptimeNanoseconds - now) / 1_000_000
        guard remaining >= minimum else { throw UIRouteError(.cancelled, "insufficient_reader_deadline_budget") }
        guard let milliseconds = Int(exactly: min(remaining, maximum)),
              let arguments = try ActionJSON.encoded(content).object else {
            throw UIRouteError(.failed, "reader_plan_binding_mismatch")
        }
        return ActionRequest(requestId: original.requestId, action: "reader.open", arguments: arguments,
            expectedBackend: original.snapshot.backend, expectedGeneration: original.snapshot.generation,
            requestedPresentation: .foreground, deadlineMs: milliseconds)
    }
}
