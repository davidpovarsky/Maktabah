// DEBUG evidence only. This single process-lived slot stores an immutable
// return from the REAL public caller. It has no chooser, grant, source owner,
// trigger or executable fallback. Capture precedes all fallible projection.
@MainActor
private final class MaktabahNativePublicSearchProbeReturn {
    private static var retained: MaktabahNativePublicSearchProbeReturn?
    private enum RetentionError: Error { case invalidKind, alreadyCaptured, alreadyPublished }
    static var hasCaptured: Bool { retained != nil }
    let kind: String
    let token: UUID
    let request: NativeSearchContinuationIntentService.OpenRequest
    let execution: NativeSearchContinuationIntentService.Execution
    private(set) var checkpointReference: [String: Any]?
    private var attemptedPublication = false

    private init(kind: String, token: UUID, request: NativeSearchContinuationIntentService.OpenRequest,
                 execution: NativeSearchContinuationIntentService.Execution) {
        self.kind = kind; self.token = token; self.request = request; self.execution = execution
    }

    static func capture(kind: String, token: UUID, request: NativeSearchContinuationIntentService.OpenRequest,
                        execution: NativeSearchContinuationIntentService.Execution) throws -> MaktabahNativePublicSearchProbeReturn {
        let expected = request.target.reference.kind == .result ? "search-public-hit" : "search-public-page"
        guard kind == expected else { throw RetentionError.invalidKind }
        guard retained == nil else { throw RetentionError.alreadyCaptured }
        let value = MaktabahNativePublicSearchProbeReturn(kind: kind, token: token, request: request, execution: execution)
        retained = value
        return value
    }

    func publish(checkpoint: (NativeSearchContinuationIntentService.OpenRequest,
                              NativeSearchContinuationIntentService.Execution) throws -> [String: Any],
                 envelope: ([String: Any]) throws -> Void) throws {
        guard !attemptedPublication else { throw RetentionError.alreadyPublished }
        attemptedPublication = true
        let reference = try checkpoint(request, execution)
        checkpointReference = reference
        try envelope(reference)
    }
}
