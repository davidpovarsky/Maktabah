import Foundation

enum ActionPolicy {
    static func authorize(_ action: ValidatedAction, context: ActionExecutionContext, backend: ActionBackendID?) throws {
        guard ActionValidation.nonempty(context.subjectID, max: 256), context.maxActions > 0, context.maxActions <= 100,
              context.maxResultBytes >= 1024, context.maxResultBytes <= 262_144 else { throw ActionEngineFailure(.failed, "permission_denied") }
        let scope: ActionScope = action.descriptor.riskTier == 0 ? .discovery : action.descriptor.riskTier == 1 ? .contentRead : .navigation
        guard context.scopes.contains(scope) else { throw ActionEngineFailure(.failed, "permission_denied") }
        if let backend {
            guard context.allowedBackends.contains(backend) else { throw ActionEngineFailure(.failed, "permission_denied") }
            if action.descriptor.riskTier == 1 && !context.contentRights.contains(backend) { throw ActionEngineFailure(.failed, "content_rights_required") }
        }
        if context.origin == .deepLink && action.descriptor.riskTier == 1 { throw ActionEngineFailure(.notSupported, "origin_action_not_allowed") }
        if context.origin == .mcp && !context.pairedDeviceAvailable { throw ActionEngineFailure(.unavailable, "device_offline") }
    }
    static func work(_ workKey: String, backend: ActionBackendID, context: ActionExecutionContext) throws {
        if let restricted = context.allowedWorkKeys, restricted[backend]?.contains(workKey) != true {
            throw ActionEngineFailure(.failed, "permission_denied")
        }
    }
    static func search(_ query: ActionSearchQuery, context: ActionExecutionContext) throws {
        if context.allowedWorkKeys != nil && query.scopeWorkRefs.isEmpty { throw ActionEngineFailure(.failed, "scope_required") }
        for workRef in query.scopeWorkRefs { try work(workRef.workKey, backend: query.backend, context: context) }
    }
    static func capability(_ assessment: ActionCapabilityAssessment) throws {
        guard assessment.registered, assessment.supported else {
            throw ActionEngineFailure(.notSupported, safeReason(assessment.reasonCode, fallback: "capability_unavailable"))
        }
        guard assessment.availableNow else { throw ActionEngineFailure(.unavailable, safeReason(assessment.reasonCode, fallback: "backend_unavailable")) }
    }
    static func safeReason(_ reason: String?, fallback: String) -> String {
        let codes: Set<String> = ["index_missing", "database_missing", "network_unavailable", "runtime_initializing", "rpc_unavailable",
            "search_mode_unavailable", "search_sort_unavailable", "scope_unavailable", "capability_unavailable", "backend_unavailable"]
        return reason.flatMap { codes.contains($0) ? $0 : nil } ?? fallback
    }
}
