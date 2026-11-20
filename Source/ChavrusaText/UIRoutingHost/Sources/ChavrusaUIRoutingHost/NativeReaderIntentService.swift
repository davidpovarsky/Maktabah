import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Thin system-entity projection of the SAME injected Core. Entity identifiers
/// carry source identity only, never a scene, permission, receipt or a grant.
@MainActor public final class NativeReaderIntentService {
    public struct CoreObservation: Sendable {
        public let result: ActionResult
        public let snapshot: ActionBackendSnapshot
        public init(result: ActionResult, snapshot: ActionBackendSnapshot) {
            self.result = result; self.snapshot = snapshot
        }
    }
    public struct Work: Sendable, Equatable, Identifiable {
        public let id: String
        public let reference: ActionWorkRef
        public let title: String
        public init(reference: ActionWorkRef, title: String) throws {
            id = try NativeReaderEntityIdentifier.encode(reference, prefix: "maktabah.work.v1.")
            self.reference = reference; self.title = title
        }
    }
    public struct Location: Sendable, Equatable, Identifiable {
        public let id: String
        public let reference: ActionTextRef
        public let title: String
        public init(reference: ActionTextRef, title: String) throws {
            id = try NativeReaderEntityIdentifier.encode(reference, prefix: "maktabah.location.v1.")
            self.reference = reference; self.title = title
        }
    }
    /// Source metadata selected explicitly by the person. This carries no read
    /// scope, saved-note authority, scene ownership or native acknowledgement.
    public struct CommentaryDraft: Sendable, Equatable {
        public let workRef: ActionWorkRef
        public let proposedText: String
    }
    public struct OpenRequest: Sendable {
        public let locator: ActionTextRef
        public let expectedSnapshot: ActionBackendSnapshot
        public let windowIdentifier: String
        public let newTab: Bool
        public let commentaryDraft: CommentaryDraft?
        init(locator: ActionTextRef, expectedSnapshot: ActionBackendSnapshot,
             windowIdentifier: String, newTab: Bool, commentaryDraft: CommentaryDraft? = nil) {
            self.locator = locator; self.expectedSnapshot = expectedSnapshot
            self.windowIdentifier = windowIdentifier; self.newTab = newTab
            self.commentaryDraft = commentaryDraft
        }
    }

    /// A refused later step must not erase the reader effect that already
    /// completed. These are the original results/receipts, never wire authority.
    public struct CommentaryDraftFailure: Error, LocalizedError, Sendable {
        public let journey: ActionSemanticJourneyResult
        public let receipts: [UISceneReceipt]
        public let status: ActionStatus
        public let code: String
        public init(journey: ActionSemanticJourneyResult, receipts: [UISceneReceipt],
                    status: ActionStatus, code: String) {
            self.journey = journey; self.receipts = receipts
            self.status = status; self.code = code
        }
        public var errorDescription: String? {
            if journey.steps.first?.action == "reader.openCommentary", journey.steps.first?.status == .completed {
                return "The commentary opened, but its unsaved note draft could not be confirmed."
            }
            return NativeIntentOutcome(status: status, code: code).errorDescription
        }
    }

    /// Only the two observed native receipts may complete this fixed sequence.
    /// Core still owns both independent admissions and final visibility checks.
    public static func commentaryDraftAcknowledgement(_ journey: ActionSemanticJourneyResult,
        receipts: [UISceneReceipt], request: OpenRequest) throws -> UISceneAcknowledgement {
        func failure(_ status: ActionStatus, _ code: String) -> CommentaryDraftFailure {
            .init(journey: journey, receipts: receipts, status: status, code: code)
        }
        let plan = ["reader.openCommentary", "notes.prepareDraft"]
        guard journey.plannedActions == plan, !journey.steps.isEmpty, journey.steps.count <= 2,
              journey.steps.map(\.action) == Array(plan.prefix(journey.steps.count)),
              Set(journey.steps.map(\.requestId)).count == journey.steps.count else {
            throw failure(.failed, "native_effect_uncertain")
        }
        guard journey.isComplete else {
            let refused = journey.steps.last!
            throw failure(refused.status == .completed ? .failed : refused.status,
                refused.error?.code ?? "semantic_journey_not_completed")
        }
        do {
            guard request.newTab, let draft = request.commentaryDraft, receipts.count == 2,
                  let reader = receipts[0].coreReceipt,
                  receipts[0].requestId == journey.steps[0].requestId,
                  receipts[1].requestId == journey.steps[1].requestId,
                  receipts[0].sceneID == receipts[1].sceneID,
                  receipts.allSatisfy({
                      $0.backendSnapshot == request.expectedSnapshot
                          && $0.route.requestId == $0.requestId
                          && $0.route.backend == request.expectedSnapshot.backend
                          && $0.route.expectedBackendSnapshot == request.expectedSnapshot
                          && $0.route.scene.kind == .specific && $0.route.scene.sceneID == $0.sceneID
                          && $0.appliedSceneRevision > $0.basedOnSceneRevision
                  }),
                  journey.steps.allSatisfy({
                      $0.backend == request.expectedSnapshot.backend
                          && $0.backendGeneration == request.expectedSnapshot.generation
                  }),
                  reader.requestId == receipts[0].requestId, reader.snapshot == request.expectedSnapshot,
                  reader.sceneID == receipts[0].sceneID.rawValue,
                  reader.destination.presentationMode == .newTab,
                  reader.destination.sectionLocator.backend == draft.workRef.backend,
                  reader.destination.sectionLocator.workKey == draft.workRef.workKey,
                  reader.destination.sectionLocator.catalogRevision == draft.workRef.catalogRevision,
                  receipts[0].route.destination.rawValue == "native.reader",
                  receipts[0].route.content == reader.destination,
                  receipts[1].route.destination.rawValue == "native.reader.noteDraft",
                  receipts[1].route.presentation.kind == .sheet, receipts[1].coreReceipt == nil,
                  receipts[0].route.state.workspaceID == receipts[1].route.state.workspaceID,
                  receipts[0].route.state.profileID == receipts[1].route.state.profileID,
                  try journey.steps[0].data?["destination"]?.decoded(as: ActionReaderDestination.self) == reader.destination,
                  try journey.steps[0].data?["locator"]?.decoded(as: ActionTextRef.self)
                    == (reader.destination.focusLocator ?? reader.destination.sectionLocator),
                  try journey.steps[1].data?["locator"]?.decoded(as: ActionTextRef.self)
                    == (reader.destination.focusLocator ?? reader.destination.sectionLocator),
                  journey.steps[1].data?["saved"] == .bool(false) else {
                throw failure(.failed, "native_effect_uncertain")
            }
            return .acknowledged(receipts[1])
        } catch let error as CommentaryDraftFailure { throw error }
        catch { throw failure(.failed, "native_effect_uncertain") }
    }
    public typealias Execute = @MainActor @Sendable (ActionRequest) async throws -> CoreObservation
    public typealias Open = @MainActor @Sendable (OpenRequest) async throws -> UISceneAcknowledgement
    private let execute: Execute
    private let navigate: Open
    public init(execute: @escaping Execute, navigate: @escaping Open) {
        self.execute = execute; self.navigate = navigate
    }

    public func works(matching query: String) async throws -> [Work] {
        try bounded(query, maximum: 512)
        let response = try await call("catalog.resolveWork", arguments: ["query": .string(query), "limit": .integer(25)])
        return try workValues(response, defaultTitle: query)
    }
    public func works(identifiers: [String]) async throws -> [Work] {
        guard identifiers.count <= 64 else { throw UIRouteError(.failed, "too_many_intent_entities") }
        var values: [Work] = []
        var seen = Set<String>()
        for identifier in identifiers where seen.insert(identifier).inserted {
            try Task.checkCancellation()
            let ref: ActionWorkRef = try NativeReaderEntityIdentifier.decode(identifier, prefix: "maktabah.work.v1.")
            let response = try await call("catalog.resolveWork", arguments: ["workRef": try ActionJSON.encoded(ref)], backend: ref.backend)
            let matches = try workValues(response, defaultTitle: ref.workKey)
            guard matches.isEmpty || (matches.count == 1 && matches[0].reference == ref) else {
                throw UIRouteError(.staleState, "intent_work_identity_changed")
            }
            values += matches
        }
        return values
    }
    public func locations(matching section: String, workIdentifier: String) async throws -> [Location] {
        try bounded(section, maximum: 500)
        let work: ActionWorkRef = try NativeReaderEntityIdentifier.decode(workIdentifier, prefix: "maktabah.work.v1.")
        let response = try await call("catalog.resolveReference",
            arguments: ["workRef": try ActionJSON.encoded(work), "section": .string(section)], backend: work.backend)
        return try locationValues(response, work: work, defaultTitle: section)
    }
    public func locations(identifiers: [String], workIdentifier: String? = nil) async throws -> [Location] {
        guard identifiers.count <= 64 else { throw UIRouteError(.failed, "too_many_intent_entities") }
        let work: ActionWorkRef? = try workIdentifier.map { try NativeReaderEntityIdentifier.decode($0, prefix: "maktabah.work.v1.") }
        var values: [Location] = []
        var seen = Set<String>()
        for identifier in identifiers where seen.insert(identifier).inserted {
            let ref: ActionTextRef = try NativeReaderEntityIdentifier.decode(identifier, prefix: "maktabah.location.v1.")
            if let work, !sameWork(ref, work) { continue }
            if let verified = try await verifyLocation(ref) { values.append(verified.location) }
        }
        return values
    }
    public func open(workIdentifier: String, locationIdentifier: String,
                     windowIdentifier: String, newTab: Bool,
                     commentaryWorkIdentifier: String? = nil, proposedText: String? = nil) async throws -> UISceneAcknowledgement {
        try Task.checkCancellation()
        guard !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_window")
        }
        let work: ActionWorkRef = try NativeReaderEntityIdentifier.decode(workIdentifier, prefix: "maktabah.work.v1.")
        let ref: ActionTextRef = try NativeReaderEntityIdentifier.decode(locationIdentifier, prefix: "maktabah.location.v1.")
        guard sameWork(ref, work) else { throw UIRouteError(.failed, "intent_work_location_mismatch") }
        let commentary: ActionWorkRef?
        switch (commentaryWorkIdentifier, proposedText) {
        case (nil, nil): commentary = nil
        case let (.some(identifier), .some(text)):
            guard newTab else { throw UIRouteError(.failed, "intent_commentary_requires_new_tab") }
            guard text.unicodeScalars.count <= 10_000, text.utf8.count <= 40_000 else {
                throw UIRouteError(.failed, "invalid_intent_note_proposal")
            }
            let target: ActionWorkRef = try NativeReaderEntityIdentifier.decode(identifier, prefix: "maktabah.work.v1.")
            guard target.backend == work.backend else {
                throw UIRouteError(.failed, "intent_commentary_backend_mismatch")
            }
            commentary = target
        default: throw UIRouteError(.failed, "incomplete_intent_commentary_draft")
        }
        // Re-resolve the cached system entity through Core immediately before the
        // native host. Its original source/binder/reader.open validate again.
        guard let verified = try await verifyLocation(ref) else { throw UIRouteError(.staleState, "intent_location_no_longer_available") }
        try Task.checkCancellation()
        var draft: CommentaryDraft?
        if let commentary, let proposedText {
            let response = try await call("catalog.resolveWork",
                arguments: ["workRef": try ActionJSON.encoded(commentary)], backend: commentary.backend)
            guard response.snapshot == verified.snapshot else {
                throw UIRouteError(.staleState, "intent_source_generation_changed")
            }
            let matches = try workValues(response, defaultTitle: commentary.workKey)
            guard matches.count == 1, matches[0].reference == commentary else {
                throw UIRouteError(.staleState, "intent_commentary_no_longer_available")
            }
            try Task.checkCancellation()
            draft = .init(workRef: commentary, proposedText: proposedText)
        }
        return try await navigate(.init(locator: verified.location.reference, expectedSnapshot: verified.snapshot,
                                        windowIdentifier: windowIdentifier, newTab: newTab, commentaryDraft: draft))
    }

    private func verifyLocation(_ ref: ActionTextRef) async throws -> (location: Location, snapshot: ActionBackendSnapshot)? {
        let work = ActionWorkRef(backend: ref.backend, workKey: ref.workKey, catalogRevision: ref.catalogRevision)
        var arguments: ActionObject = ["workRef": try ActionJSON.encoded(work)]
        let title: String
        switch ref.position {
        case .legacyLine(let line): title = String(line); arguments["section"] = .string(title)
        case .canonicalRef(let value): title = value; arguments["text"] = .string(value)
        }
        let response = try await call("catalog.resolveReference", arguments: arguments, backend: ref.backend)
        let values = try locationValues(response, work: work, defaultTitle: title)
        if values.isEmpty { return nil }
        guard values.count == 1, values[0].reference == ref else { throw UIRouteError(.staleState, "intent_location_identity_changed") }
        return (values[0], response.snapshot)
    }
    private func call(_ action: String, arguments: ActionObject, backend: ActionBackendID? = nil) async throws -> CoreObservation {
        try Task.checkCancellation()
        let request = ActionRequest(action: action, arguments: arguments, expectedBackend: backend, requestedPresentation: .headless)
        let response = try await execute(request)
        try Task.checkCancellation()
        guard response.result.requestId == request.requestId, response.result.action == action else {
            throw UIRouteError(.failed, "invalid_core_metadata_result")
        }
        if response.result.status == .completed || response.result.status == .needsDisambiguation {
            guard response.result.backend == response.snapshot.backend,
                  response.result.backendGeneration == response.snapshot.generation,
                  backend == nil || backend == response.snapshot.backend else {
                throw UIRouteError(.staleState, "intent_source_generation_changed")
            }
        }
        return response
    }
    private func workValues(_ response: CoreObservation, defaultTitle: String) throws -> [Work] {
        let result = response.result
        if result.status == .completed {
            guard let ref = try result.data?["workRef"]?.decoded(as: ActionWorkRef.self), ref.backend == response.snapshot.backend else {
                throw UIRouteError(.failed, "invalid_core_metadata_result")
            }
            return [try Work(reference: ref, title: defaultTitle)]
        }
        if result.status == .needsDisambiguation {
            let candidates = try candidates(result)
            let values = try candidates.map { candidate -> Work in
                guard candidate.kind == .work || candidate.kind == .commentary else {
                    throw UIRouteError(.failed, "invalid_core_metadata_result")
                }
                let ref = try ActionJSON.object(candidate.ref).decoded(as: ActionWorkRef.self)
                guard ref.backend == response.snapshot.backend else { throw UIRouteError(.failed, "invalid_core_metadata_result") }
                return try Work(reference: ref, title: candidate.title)
            }
            guard Set(values.map(\.id)).count == values.count else { throw UIRouteError(.failed, "duplicate_core_entities") }
            return values
        }
        if result.status == .failed && result.error?.code == "not_found" { return [] }
        throw NativeIntentOutcome(status: result.status, code: result.error?.code ?? "core_metadata_unavailable")
    }
    private func locationValues(_ response: CoreObservation, work: ActionWorkRef, defaultTitle: String) throws -> [Location] {
        let result = response.result
        if result.status == .completed {
            guard let ref = try result.data?["locator"]?.decoded(as: ActionTextRef.self), sameWork(ref, work) else {
                throw UIRouteError(.failed, "invalid_core_metadata_result")
            }
            return [try Location(reference: ref, title: defaultTitle)]
        }
        if result.status == .needsDisambiguation {
            let values = try candidates(result).map { candidate -> Location in
                guard candidate.kind == .section || candidate.kind == .segment else {
                    throw UIRouteError(.failed, "invalid_core_metadata_result")
                }
                let ref = try ActionJSON.object(candidate.ref).decoded(as: ActionTextRef.self)
                guard sameWork(ref, work) else { throw UIRouteError(.failed, "invalid_core_metadata_result") }
                return try Location(reference: ref, title: candidate.title)
            }
            guard Set(values.map(\.id)).count == values.count else { throw UIRouteError(.failed, "duplicate_core_entities") }
            return values
        }
        if result.status == .failed && result.error?.code == "not_found" { return [] }
        throw NativeIntentOutcome(status: result.status, code: result.error?.code ?? "core_metadata_unavailable")
    }
    private func candidates(_ result: ActionResult) throws -> [ActionCandidate] {
        guard let values = result.candidates, !values.isEmpty, values.count <= 25 else { throw UIRouteError(.failed, "invalid_core_metadata_result") }
        return values
    }
    private func sameWork(_ locator: ActionTextRef, _ work: ActionWorkRef) -> Bool {
        locator.backend == work.backend && locator.workKey == work.workKey && locator.catalogRevision == work.catalogRevision
    }
    private func bounded(_ value: String, maximum: Int) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.unicodeScalars.count <= maximum, value.utf8.count <= maximum * 4 else {
            throw UIRouteError(.failed, "invalid_intent_query")
        }
    }
}

/// Strict canonical transport identity; decoder normalization/extra fields cannot
/// turn a different system entity into a trusted source reference.
enum NativeReaderEntityIdentifier {
    static func encode<T: Encodable>(_ value: T, prefix: String) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= 6_144 else { throw UIRouteError(.failed, "intent_entity_too_large") }
        return prefix + data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func decode<T: Codable>(_ value: String, prefix: String) throws -> T {
        guard value.hasPrefix(prefix), value.utf8.count <= 8_224 else { throw UIRouteError(.failed, "invalid_intent_entity") }
        let encoded = String(value.dropFirst(prefix.count))
        guard !encoded.isEmpty, encoded.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw UIRouteError(.failed, "invalid_intent_entity")
        }
        let padded = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: padded), data.count <= 6_144 else { throw UIRouteError(.failed, "invalid_intent_entity") }
        let decoded = try JSONDecoder().decode(T.self, from: data)
        guard try encode(decoded, prefix: prefix) == value else { throw UIRouteError(.failed, "noncanonical_intent_entity") }
        return decoded
    }
}
