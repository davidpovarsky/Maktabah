import Foundation
import OtzariaActionCore

/// App-internal persistence types stay outside the portable package.
enum ActionAppIdentityBridge {
    static func actionBackend(_ value: BackendID) -> ActionBackendID {
        switch value { case .otzaria: .otzaria; case .sefaria: .sefaria; case .sefariaEmbedded: .sefariaEmbedded }
    }
    static func appBackend(_ value: ActionBackendID) -> BackendID {
        switch value { case .otzaria: .otzaria; case .sefaria: .sefaria; case .sefariaEmbedded: .sefariaEmbedded }
    }
    static func appPosition(_ value: ActionTextPosition) throws -> TextPosition {
        switch value {
        case .legacyLine(let line):
            guard line >= 0, let exact = Int(exactly: line) else { throw ActionPortError.invalidResponse }
            return .legacyLine(exact)
        case .canonicalRef(let ref):
            guard !ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, ref.count <= 1_000 else { throw ActionPortError.invalidResponse }
            return .canonicalRef(ref)
        }
    }
    static func actionPosition(_ value: TextPosition) throws -> ActionTextPosition {
        switch value {
        case .legacyLine(let line):
            guard line >= 0, let exact = Int64(exactly: line) else { throw ActionPortError.invalidResponse }
            return .legacyLine(exact)
        case .canonicalRef(let ref):
            guard !ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, ref.count <= 1_000 else { throw ActionPortError.invalidResponse }
            return .canonicalRef(ref)
        }
    }
    static func appLocator(_ ref: ActionTextRef) throws -> TextLocator {
        guard !ref.workKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, ref.workKey.count <= 512 else { throw ActionPortError.invalidResponse }
        // The old persistence format has no revision fields: never silently lose them.
        guard ref.catalogRevision == nil, ref.dataRevision == nil else { throw ActionPortError.notSupported }
        return TextLocator(backend: appBackend(ref.backend), workKey: ref.workKey, position: try appPosition(ref.position))
    }
    static func actionRef(_ locator: TextLocator) throws -> ActionTextRef {
        guard !locator.workKey.isEmpty else { throw ActionPortError.invalidResponse }
        return ActionTextRef(backend: actionBackend(locator.backend), workKey: locator.workKey,
                             position: try actionPosition(locator.position))
    }
    static func capabilityNames(_ value: BackendCapabilities) -> Set<String> {
        let fields: [(String, BackendCapabilities)] = [
            ("catalog", .catalog), ("reading", .reading), ("navigation", .navigation), ("search", .search),
            ("authors", .authors), ("links", .links), ("versions", .versions), ("offlineLibrary", .offlineLibrary),
            ("offlineSearch", .offlineSearch), ("workMetadata", .workMetadata)
        ]
        return Set(fields.compactMap { value.contains($0.1) ? $0.0 : nil })
    }
}

struct ActionAppCatalogSnapshot: Sendable {
    let works: [LibraryWork]
    let workKeys: Set<String>
}

enum ActionLibraryProjection {
    static func works(_ roots: [LibraryCatalogNode], invocation: ActionPortInvocation) throws -> [LibraryWork] {
        var pending = roots, works: [LibraryWork] = [], visited = 0
        while let node = pending.popLast() {
            visited += 1
            guard visited <= 100_000 else { throw ActionPortError.unavailable }
            try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: invocation.snapshot.backend)
            if let work = node.work {
                guard ActionAppIdentityBridge.actionBackend(work.locator.backend) == invocation.snapshot.backend,
                      !work.locator.workKey.isEmpty else { throw ActionPortError.invalidResponse }
                works.append(work)
            } else if node.kind == .work {
                throw ActionPortError.invalidResponse
            }
            pending.append(contentsOf: node.children.reversed())
        }
        return works
    }

    static func catalog(_ works: [LibraryWork], backend: ActionBackendID, invocation: ActionPortInvocation) throws -> [ActionCatalogEntry] {
        var byKey: [String: ActionCatalogEntry] = [:]
        var order: [String] = []
        for work in works {
            try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: backend)
            let key = work.locator.workKey
            let aliases = [work.heTitle].compactMap { $0 }.filter { !$0.isEmpty && $0 != work.title }
            if let previous = byKey[key] {
                byKey[key] = .init(workRef: previous.workRef, title: previous.title,
                    aliases: Array(Set(previous.aliases + aliases + [work.title])).sorted(),
                    kind: previous.kind, provenance: previous.provenance)
            } else {
                order.append(key)
                byKey[key] = .init(workRef: .init(backend: backend, workKey: key), title: work.title,
                                  aliases: aliases, provenance: backend == .sefariaEmbedded ? "SefariaJSRPCBridge.catalog.toc" : "BackendCoordinator.catalog:\(backend.rawValue)")
            }
        }
        return order.compactMap { byKey[$0] }
    }

    /// Flatten only original provider TOC identities. Matching remains in the
    /// canonical Core resolver; the app adapter does not infer chapter numbers.
    static func sourceSections(_ roots: [LibraryTOCNode], invocation: ActionPortInvocation,
                               maximumEntries: Int = 100_000, leavesOnly: Bool = false) throws -> [ActionSourceSectionEntry] {
        guard roots.count <= 100_000 else { throw ActionPortError.unavailable }
        var pending = roots.reversed().map { ($0, 0) }
        var entries: [ActionSourceSectionEntry] = [], visited = 0
        while entries.count < maximumEntries, let (node, depth) = pending.popLast() {
            visited += 1
            try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: invocation.snapshot.backend)
            guard depth <= 64, visited + pending.count <= 100_000,
                  node.children.count <= 100_000 - visited - pending.count else {
                throw ActionPortError.unavailable
            }
            if !leavesOnly || node.children.isEmpty {
                entries.append(.init(locator: try ActionAppIdentityBridge.actionRef(node.locator), title: node.title))
            }
            pending.append(contentsOf: node.children.reversed().map { ($0, depth + 1) })
        }
        return entries
    }

    static func searchPage(_ page: LibrarySearchPage, query: ActionSearchQuery, works: [LibraryWork]) throws -> ActionSearchPage {
        guard page.hits.count <= query.limit, page.total >= 0 else { throw ActionPortError.invalidResponse }
        if let next = page.nextOffset {
            guard next > query.offset, !page.hits.isEmpty else { throw ActionPortError.invalidResponse }
        }
        // The Embedded JS facade can synthesize an empty array/count on invalid
        // upstream data. Until it exposes provenance, this is not verified zero.
        if let source = page.sourceEvidence {
            guard ActionAppIdentityBridge.actionBackend(source.backend) == query.backend,
                  source.allRowsMapped, source.rawHitCount == page.hits.count else { throw ActionPortError.invalidResponse }
        }
        if query.backend == .sefaria, page.hits.isEmpty {
            guard let source = page.sourceEvidence, source.rawHitCount == 0,
                  source.totalRelation == "eq", page.total <= query.offset, page.nextOffset == nil else {
                throw ActionPortError.unavailable
            }
        } else if query.backend == .sefariaEmbedded, page.hits.isEmpty {
            throw ActionPortError.unavailable
        }
        let allowed = Set(query.scopeWorkRefs.map(\.workKey))
        var seen = Set<String>()
        let hits = try page.hits.compactMap { hit -> ActionSearchHit? in
            let ref = try ActionAppIdentityBridge.actionRef(hit.locator)
            if case .canonicalRef(let value) = ref.position {
                guard value == ref.workKey || value.hasPrefix(ref.workKey + " ") || value.hasPrefix(ref.workKey + ", ") else {
                    throw ActionPortError.invalidResponse
                }
            }
            guard ref.backend == query.backend, allowed.isEmpty || allowed.contains(ref.workKey) else {
                throw ActionPortError.invalidResponse
            }
            let titles = works.filter { $0.locator.workKey == ref.workKey }
            guard !titles.isEmpty else { throw ActionPortError.invalidResponse }
            guard seen.insert(hit.id).inserted else { return nil }
            return ActionSearchHit(id: hit.id, locator: ref, title: titles[0].heTitle ?? titles[0].title, snippet: hit.snippet)
        }
        // Preserve the actual provider cursor. Its aggregate total is not an
        // occurrence count, and LibrarySearchPage does not expose exactness.
        return .init(hits: hits, total: page.total, precision: .unknown,
                     totalSemantics: .matchingSegments, nextOffset: page.nextOffset)
    }
}
