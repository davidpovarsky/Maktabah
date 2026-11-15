// Downstream-owned strict adapter over the original Sefaria-Mobile related API.
import Foundation
import OtzariaActionCore

final class SefariaEmbeddedRelationshipsAdapter: LibraryRelationshipsProviding, Sendable {
    static let shared = SefariaEmbeddedRelationshipsAdapter()
    private init() {}

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        let (body, keys) = try await related(locator)
        return try Self.decodeLinks(body, catalogWorkKeys: keys)
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        let (body, _) = try await related(locator)
        return try Self.decodeTopics(body)
    }

    private func related(_ locator: TextLocator) async throws -> (ActionJSON, Set<String>) {
        guard locator.backend == .sefariaEmbedded, !locator.workKey.isEmpty,
              case .canonicalRef(let ref) = locator.position,
              ref == locator.workKey || ref.hasPrefix(locator.workKey + " ") || ref.hasPrefix(locator.workKey + ", ") else {
            throw LibraryBackendError.invalidLocator
        }
        try Task.checkCancellation()
        let bridge = SefariaJSRPCBridge.shared
        if await bridge.isTransportReady {
            try await requireStableJSResources(epoch: await bridge.sessionEpoch)
        }
        try await SefariaRuntimeManager.shared.ensureReady()
        let epoch = await bridge.sessionEpoch
        guard await bridge.resourcesAreStable else { throw LibraryBackendError.staleRequest }
        try await requireStableJSResources(epoch: epoch)
        let params = String(decoding: try JSONEncoder().encode(["ref": ActionJSON.string(ref), "online": .bool(true)]), as: UTF8.self)
        let response = try await bridge.call(method: "relationships.links", paramsJson: params, generation: epoch)
        let body = try Self.decodeResponse(response)
        // Fetch the actual current catalog in the same resource epoch. The
        // existing catalog adapter caches across epochs, so its cache cannot
        // establish this identity. Reuse the canonical strict decoder instead.
        let catalog = try Self.decodeResponse(await bridge.call(method: "catalog.toc", generation: epoch))
        let keys = try EmbeddedActionResponseProof.catalogWorkKeys(catalog)
        try await requireStableJSResources(epoch: epoch)
        try Task.checkCancellation()
        guard await bridge.sessionEpoch == epoch, await bridge.resourcesAreStable else {
            throw LibraryBackendError.staleRequest
        }
        guard keys.contains(locator.workKey) else { throw LibraryBackendError.invalidLocator }
        return (body, keys)
    }

    private func requireStableJSResources(epoch: UInt64) async throws {
        let nonce = UUID().uuidString
        let params = String(decoding: try JSONEncoder().encode(["nonce": nonce]), as: UTF8.self)
        let bridge = SefariaJSRPCBridge.shared
        let response = try await bridge.call(method: "runtime.actionContract", paramsJson: params,
            generation: epoch, timeoutMs: 2_000)
        guard EmbeddedActionResponseProof.matchesRuntimeResourceProof(try Self.decodeResponse(response), nonce: nonce),
              await bridge.sessionEpoch == epoch else { throw LibraryBackendError.staleRequest }
    }

    static func decodeResponse(_ response: SefariaRPCResponse) throws -> ActionJSON {
        guard response.isSuccess else {
            throw response.error ?? LibraryBackendError.invalidResponse("Related RPC failed without an error payload")
        }
        guard let json = response.resultJson, json.utf8.count <= 16_777_216 else {
            throw LibraryBackendError.invalidResponse("Missing or oversized related payload")
        }
        do { return try JSONDecoder().decode(ActionJSON.self, from: Data(json.utf8)) }
        catch { throw LibraryBackendError.invalidResponse("Malformed related payload") }
    }

    static func decodeLinks(_ body: ActionJSON, catalogWorkKeys: Set<String>) throws -> [LibraryRelatedSource] {
        let rows: [ActionJSON]
        if let array = body.array { rows = array }
        else if let array = body.object?["links"]?.array { rows = array }
        else { throw LibraryBackendError.invalidResponse("Related response has no links array") }
        guard rows.count <= 10_000 else { throw LibraryBackendError.invalidResponse("Too many related sources") }
        return try rows.map { row in
            try Task.checkCancellation()
            guard let value = row.object else { throw LibraryBackendError.invalidResponse("Malformed related source") }
            let source = try optionalString(value, "sourceRef") ?? optionalString(value, "ref")
            guard let source, !source.isEmpty, source.count <= 1_000,
                  let work = try optionalString(value, "sourceWorkKey"), !work.isEmpty,
                  catalogWorkKeys.contains(work),
                  source == work || source.hasPrefix(work + " ") || source.hasPrefix(work + ", ") else {
                throw LibraryBackendError.invalidResponse("Related source has no proven catalog work identity")
            }
            if let backend = try optionalString(value, "backend"), backend != BackendID.sefariaEmbedded.rawValue {
                throw LibraryBackendError.invalidResponse("Foreign related-source backend")
            }
            let category = try optionalString(value, "category") ?? "Related"
            let type = try optionalString(value, "type") ?? category
            let collective = value["collectiveTitle"]
            let title: String?, heTitle: String?
            if let object = collective?.object {
                title = try optionalString(object, "en"); heTitle = try optionalString(object, "he")
            } else {
                title = try optionalString(value, "collectiveTitle"); heTitle = nil
            }
            let anchor = try optionalString(value, "anchorRef")
            return try LibraryRelatedSource(
                locator: .init(backend: .sefariaEmbedded, workKey: work, position: .canonicalRef(source)),
                displayRef: source,
                heRef: optionalString(value, "sourceHeRef") ?? optionalString(value, "heRef"),
                category: category, type: type, collectiveTitle: title, heCollectiveTitle: heTitle,
                primaryText: optionalString(value, "he"), translation: optionalString(value, "text"),
                versionTitle: optionalString(value, "versionTitle"), heVersionTitle: optionalString(value, "heVersionTitle"),
                license: optionalString(value, "license"), anchorRefs: anchor.map { [$0] } ?? [])
        }
    }

    static func decodeTopics(_ body: ActionJSON) throws -> [LibraryRelatedTopic] {
        guard let rows = body.object?["topics"]?.array else {
            // A links-only response supplies no evidence of zero topics.
            throw LibraryBackendError.capabilityUnavailable
        }
        guard rows.count <= 10_000 else { throw LibraryBackendError.invalidResponse("Too many related topics") }
        return try rows.map { row in
            guard let value = row.object,
                  let slug = try optionalString(value, "topic") ?? optionalString(value, "slug"),
                  !slug.isEmpty else { throw LibraryBackendError.invalidResponse("Malformed related topic") }
            return try .init(slug: slug, titleHe: optionalString(value, "he"),
                titleEn: optionalString(value, "title") ?? optionalString(value, "en"))
        }
    }

    private static func optionalString(_ value: ActionObject, _ key: String) throws -> String? {
        guard let item = value[key], item != .null else { return nil }
        guard let text = item.string, text.utf8.count <= 1_048_576 else {
            throw LibraryBackendError.invalidResponse("Invalid related string field: " + key)
        }
        return text
    }
}
