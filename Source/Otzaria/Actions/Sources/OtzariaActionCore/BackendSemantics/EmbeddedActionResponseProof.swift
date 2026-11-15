import Foundation

/// Validates evidence emitted by the existing JS engine; never runs a search or
/// constructs a missing source reference/count. Older bundles fail closed.
public enum EmbeddedActionResponseProof {
    /// Echo plus strict version/readiness proves the loaded facade implements
    /// the response schema. It never certifies a count or a disk bundle hash.
    public static func matchesRuntimeContract(_ body: ActionJSON, nonce: String) -> Bool {
        guard let value = body.object else { return false }
        return value["contract"]?.string == "chavrusa.actions.search-fidelity.v1"
            && value["searchFidelitySchema"]?.integer == 1
            && value["nonce"]?.string == nonce
            && value["catalogReady"]?.boolean == true
            && value["searchReady"]?.boolean == true
            && value["resourcesStable"]?.boolean == true
    }

    public static func catalogEntries(_ body: ActionJSON, invocation: ActionPortInvocation) throws -> [ActionCatalogEntry] {
        try catalogEntries(body) {
            try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: .sefariaEmbedded)
        }
    }

    /// The same strict source decoder serves native adapters without creating
    /// a synthetic ActionBackendSnapshot or a second catalog parser.
    public static func catalogWorkKeys(_ body: ActionJSON) throws -> Set<String> {
        Set(try catalogEntries(body) { try Task.checkCancellation() }.map { $0.workRef.workKey })
    }

    private static func catalogEntries(_ body: ActionJSON, check: () throws -> Void) throws -> [ActionCatalogEntry] {
        guard let roots = body.array else { throw ActionPortError.invalidResponse }
        var pending = roots.reversed().map { ($0, 0) }, count = 0, entries: [ActionCatalogEntry] = []
        while let (node, depth) = pending.popLast() {
            count += 1
            guard count <= 100_000, depth <= 32, let item = node.object else { throw ActionPortError.invalidResponse }
            try check()
            if let category = item["category"] {
                guard let title = category.string, !title.isEmpty, let children = item["contents"]?.array else {
                    throw ActionPortError.invalidResponse
                }
                pending.append(contentsOf: children.reversed().map { ($0, depth + 1) })
            } else {
                guard let title = item["title"]?.string, !title.isEmpty, title.count <= 512 else { throw ActionPortError.invalidResponse }
                let aliases: [String]
                if let hebrew = item["heTitle"] {
                    guard let value = hebrew.string else { throw ActionPortError.invalidResponse }
                    aliases = value.isEmpty || value == title ? [] : [value]
                } else { aliases = [] }
                entries.append(.init(workRef: .init(backend: .sefariaEmbedded, workKey: title), title: title,
                    aliases: aliases, provenance: "SefariaJSRPCBridge.catalog.toc"))
            }
        }
        // The old JS catalog route can return[] before the catalog is present.
        guard !entries.isEmpty else { throw ActionPortError.unavailable }
        return entries
    }

    public static func searchPage(_ body: ActionJSON, query: ActionSearchQuery) throws -> ActionSearchPage {
        try ActionSearchSemantics.validateBounds(query)
        guard query.backend == .sefariaEmbedded, ActionSearchSemantics.unsupportedReason(query) == nil,
              let object = body.object, let evidence = object["fidelity"]?.object,
              evidence["schemaVersion"]?.integer == 1,
              evidence["rawHitsPresent"]?.boolean == true,
              evidence["rawStart"]?.integer == Int64(query.offset),
              evidence["rawSize"]?.integer == Int64(query.limit),
              object["start"]?.integer == Int64(query.offset), object["size"]?.integer == Int64(query.limit),
              evidence["totalPresent"]?.boolean != nil,
              evidence["sourceCursorPresent"]?.boolean != nil, evidence["sourceCursorValid"]?.boolean != nil,
              let rawCount = evidence["rawHitCount"]?.integer, rawCount >= 0, rawCount <= query.limit,
              let rows = object["hits"]?.array,
              evidence["processedHitCount"]?.integer == Int64(rows.count), rows.count <= rawCount else {
            throw ActionPortError.invalidResponse
        }
        let hits = try rows.map { row -> ActionSearchHit in
            guard let values = row.object, let ref = values["ref"]?.string, !ref.isEmpty,
                  let workKey = values["workKey"]?.string, !workKey.isEmpty,
                  ref == workKey || ref.hasPrefix(workKey + " "),
                  let title = values["title"]?.string, !title.isEmpty, title.count <= 512,
                  ref.count <= 1_000, workKey.count <= 512,
                  let snippet = values["snippet"]?.string, snippet.utf8.count <= 65_536 else { throw ActionPortError.invalidResponse }
            let locator = ActionTextRef(backend: .sefariaEmbedded, workKey: workKey, position: .canonicalRef(ref))
            let version = values["version"]?.string ?? ""
            let language = values["language"]?.string ?? ""
            // A structured tuple avoids delimiter collisions and retains versions.
            let idData = try JSONEncoder().encode(["sefariaEmbedded", workKey, ref, version, language])
            return .init(id: String(decoding: idData, as: UTF8.self), locator: locator, title: title, snippet: snippet)
        }
        let consumed = query.offset.addingReportingOverflow(Int(rawCount))
        guard !consumed.overflow else { throw ActionPortError.invalidResponse }
        let total: Int?
        if evidence["totalPresent"]?.boolean == true,
           let value = evidence["totalValue"]?.integer, value >= 0, let exact = Int(exactly: value) { total = exact }
        else { total = nil }
        let relation = evidence["totalRelation"]?.string ?? "unknown"
        if relation == "eq", let total, rawCount > 0, total < consumed.partialValue {
            throw ActionPortError.invalidResponse
        }
        let next: Int?
        if evidence["sourceCursorPresent"]?.boolean == true {
            guard evidence["sourceCursorValid"]?.boolean == true else { throw ActionPortError.invalidResponse }
            if let value = evidence["sourceNextOffset"]?.integer, let exact = Int(exactly: value) {
                guard exact > query.offset, rawCount > 0 else { throw ActionPortError.invalidResponse }
                next = exact
            } else if evidence["sourceNextOffset"] == .null { next = nil }
            else { throw ActionPortError.invalidResponse }
        } else if let total, relation == "eq" || relation == "gte" && total > consumed.partialValue {
            // This is the consumed RAW source position, never processed-hit count.
            if consumed.partialValue < total {
                guard rawCount > 0 else { throw ActionPortError.invalidResponse }
                next = consumed.partialValue
            } else { next = nil }
        } else {
            // A legacy fallback total/raw length cannot prove exhaustion/cursor.
            throw ActionPortError.unavailable
        }
        if hits.isEmpty, rawCount != 0 { throw ActionPortError.invalidResponse }
        if hits.isEmpty, !(relation == "eq" && total.map({ $0 <= query.offset }) == true)
            && !(evidence["sourceCursorPresent"]?.boolean == true && evidence["sourceNextOffset"] == .null) {
            throw ActionPortError.unavailable
        }
        // Raw engine relation establishes cursor evidence, not certified public
        // segment/occurrence counting across processed versions and grouping.
        return .init(hits: hits, total: total, precision: .unknown, totalSemantics: .matchingSegments, nextOffset: next)
    }

    public static func validateText(_ body: ActionJSON, ref: ActionTextRef) throws {
        guard ref.backend == .sefariaEmbedded, case .canonicalRef(let value) = ref.position,
              value == ref.workKey || value.hasPrefix(ref.workKey + " "),
              let content = body.object?["textContent"]?.object,
              let section = content["sectionRef"]?.string,
              section == ref.workKey || section.hasPrefix(ref.workKey + " "),
              let segments = content["content"]?.array, !segments.isEmpty, segments.count <= 10_000 else { throw ActionPortError.invalidResponse }
        let references = try segments.map { segment -> String in
            guard let object = segment.object, let actual = object["ref"]?.string,
                  actual == ref.workKey || actual.hasPrefix(ref.workKey + " "),
                  object["he"]?.string != nil || object["text"]?.string != nil else { throw ActionPortError.invalidResponse }
            return actual
        }
        guard value == section || references.contains(value) else { throw ActionPortError.notFound }
    }
}
