import Foundation
import Dispatch

/// Resolves source-owned catalog identities without a second index or guessed refs.
/// DataPort.validate is an existence check against source data, not normalization.
public actor CatalogActionResolver: ActionResolverPort, ActionCommentaryResolverPort {
    private struct CatalogView: Sendable {
        let entries: [ActionCatalogEntry]
        let identities: Set<ActionWorkRef>
        let workKeys: Set<String>
        func contains(_ ref: ActionWorkRef) -> Bool {
            ref.catalogRevision == nil ? workKeys.contains(ref.workKey) : identities.contains(ref)
        }
    }
    private let data: any ActionResolverDataPort
    private let state: any ActionBackendStatePort
    private let uptime: @Sendable () -> UInt64

    // Caps apply before expensive work. Oversized source payloads fail explicitly,
    // rather than searching a prefix and accidentally declaring a unique match.
    private let maximumCatalogEntries: Int
    private let maximumReferenceCandidates: Int
    private let maximumCatalogBytes = 32 * 1_024 * 1_024

    public init(data: any ActionResolverDataPort, state: any ActionBackendStatePort,
                maximumCatalogEntries: Int = 100_000, maximumReferenceCandidates: Int = 256,
                uptime: @escaping @Sendable () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        self.data = data; self.state = state; self.uptime = uptime
        self.maximumCatalogEntries = max(1, min(maximumCatalogEntries, 100_000))
        self.maximumReferenceCandidates = max(1, min(maximumReferenceCandidates, 256))
    }

    public func resolveWork(_ query: ActionResolveWorkQuery,
                            invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> {
        try requireBackend(query.backend, invocation)
        guard (1...25).contains(query.limit), query.query != nil || query.workRef != nil else {
            throw ActionContractError.invalid("resolveWork")
        }
        if let ref = query.workRef { try requireWork(ref, backend: query.backend) }
        let normalized = try query.query.map { try normalizedName($0, field: "query") }
        let entries = try await catalog(query.backend, invocation)
        var seen = Set<ActionWorkRef>()
        var candidates: [(entry: ActionCatalogEntry, confidence: ActionCandidate.Confidence)] = []
        var matchCount = 0
        var explicitFound = false
        for (index, entry) in entries.entries.enumerated() {
            try await scanCheckpoint(index, invocation)
            if let explicit = query.workRef, !matches(entry.workRef, explicit) { continue }
            explicitFound = true
            let confidence: ActionCandidate.Confidence?
            if let normalized { confidence = try match(normalized, entry: entry) }
            else { confidence = .exact }
            guard let confidence else { continue }
            guard seen.insert(entry.workRef).inserted else {
                if let existing = candidates.firstIndex(where: { $0.entry.workRef == entry.workRef }),
                   prefer(entry, confidence, over: candidates[existing]) {
                    candidates[existing] = (entry, confidence)
                }
                continue
            }
            matchCount += 1
            let position = candidates.firstIndex { workLess(entry.workRef, $0.entry.workRef) } ?? candidates.endIndex
            candidates.insert((entry, confidence), at: position)
            if candidates.count > query.limit { candidates.removeLast() }
        }
        try await checkpoint(invocation)
        guard !candidates.isEmpty else {
            if explicitFound, query.workRef != nil, normalized != nil { throw ActionContractError.invalid("query") }
            return .notFound
        }
        if matchCount == 1 { return .unique(candidates[0].entry.workRef) }
        // Only the bounded best candidates are ordered; every entry was checked.
        let output = try candidates.map { item in
            ActionCandidate(ref: try object(item.entry.workRef), title: item.entry.title,
                            kind: item.entry.kind, confidenceBand: item.confidence,
                            reason: "source_catalog; \(item.entry.provenance); normalization=nfc,whitespace,quotes")
        }
        try await checkpoint(invocation)
        return .ambiguous(output)
    }

    public func resolveReference(_ query: ActionResolveReferenceQuery,
                                 invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> {
        try requireBackend(query.backend, invocation)
        guard query.text != nil || query.workRef != nil else { throw ActionContractError.invalid("resolveReference") }
        if let text = query.text { try requireText(text, maximum: 1_000, field: "text") }
        if let section = query.section { try requireText(section, maximum: 500, field: "section") }
        if let ref = query.workRef { try requireWork(ref, backend: query.backend) }
        let entries = try await catalog(query.backend, invocation)
        if let ref = query.workRef, !entries.contains(ref) { return .notFound }
        let response = try await sourceCall(invocation) { [data] in
            try await data.referenceCandidates(query, invocation: invocation)
        }
        switch response {
        case .notFound: return .notFound
        case .unique(let ref):
            try requireSourceReference(ref, backend: query.backend, work: query.workRef, catalog: entries)
            do { try await validateExactly(ref, invocation) }
            catch ActionPortError.notFound { return .notFound }
            return .unique(ref)
        case .ambiguous(let candidates):
            guard !candidates.isEmpty, candidates.count <= maximumReferenceCandidates else { throw ActionPortError.invalidResponse }
            var unique: [ActionTextRef: ActionCandidate] = [:]
            for candidate in candidates {
                try localCheckpoint(invocation)
                guard candidate.ref.keys.allSatisfy({ ["backend", "workKey", "catalogRevision", "position", "dataRevision"].contains($0) }),
                      let position = candidate.ref["position"]?.object,
                      Set(position.keys) == ["kind", "value"],
                      candidate.kind == .section || candidate.kind == .segment else { throw ActionPortError.invalidResponse }
                try requireSourceText(candidate.ref["backend"]?.string ?? "", maximum: 32)
                try requireSourceText(candidate.ref["workKey"]?.string ?? "", maximum: 512)
                for key in ["catalogRevision", "dataRevision"] where candidate.ref[key] != nil {
                    try requireSourceText(candidate.ref[key]?.string ?? "", maximum: 128)
                }
                switch (position["kind"]?.string, position["value"]) {
                case ("legacyLine", .integer(let line)) where line >= 0: break
                case ("canonicalRef", .string(let value)): try requireSourceText(value, maximum: 1_000)
                default: throw ActionPortError.invalidResponse
                }
                let ref: ActionTextRef
                do { ref = try ActionJSON.object(candidate.ref).decoded(as: ActionTextRef.self) }
                catch { throw ActionPortError.invalidResponse }
                try requireSourceReference(ref, backend: query.backend, work: query.workRef, catalog: entries)
                try requireSourceText(candidate.title, maximum: 512)
                if let reason = candidate.reason { try requireSourceText(reason, maximum: 1_000) }
                // Preserve source metadata; never promote a capped ambiguity to unique.
                // One existence proof per full qualified ref in this invocation;
                // duplicate candidates must not multiply DB/RPC reads.
                if unique[ref] == nil {
                    do { try await validateExactly(ref, invocation) }
                    catch ActionPortError.notFound { throw ActionPortError.invalidResponse }
                    unique[ref] = candidate
                }
            }
            let output = unique.keys.sorted(by: textLess)
                .prefix(25).compactMap { unique[$0] }
            try await checkpoint(invocation)
            return .ambiguous(output)
        }
    }

    public func canResolveCommentary() async -> Bool { data is any ActionCommentaryDataPort }

    public func resolveCommentary(_ query: ActionResolveCommentaryQuery,
                                  invocation: ActionPortInvocation) async throws -> ActionResolution<ActionReaderDestination> {
        let base = query.baseLocator, backend = query.baseLocator.backend
        try requireBackend(backend, invocation)
        try requireReference(base)
        guard query.workRef != nil || query.commentaryQuery != nil else { throw ActionContractError.invalid("commentary") }
        if let work = query.workRef { try requireWork(work, backend: backend) }
        let name = try query.commentaryQuery.map { try normalizedName($0, field: "commentaryQuery") }
        guard let source = data as? any ActionCommentaryDataPort else { throw ActionPortError.notSupported }
        let entries = try await catalog(backend, invocation)
        let baseWork = ActionWorkRef(backend: backend, workKey: base.workKey, catalogRevision: base.catalogRevision)
        guard entries.contains(baseWork) else { return .notFound }
        if let work = query.workRef, !entries.contains(work) { return .notFound }
        try await validateExactly(base, invocation)
        let links = try await sourceCall(invocation) {
            try await source.commentaryLinks(for: base, invocation: invocation)
        }
        // Never truncate a source response and then claim a unique match.
        guard links.count <= 10_000 else { throw ActionPortError.invalidResponse }
        var matchingCatalogWorkKeys = Set<String>()
        if let name {
            // Scan the catalog once, not once for every related passage.
            for (index, entry) in entries.entries.enumerated() {
                try await scanCheckpoint(index, invocation)
                if try match(name, entry: entry) != nil { matchingCatalogWorkKeys.insert(entry.workRef.workKey) }
            }
        }
        var destinations: [ActionTextRef: (ActionReaderDestination, String)] = [:]
        var bytes = 0
        for (index, link) in links.enumerated() {
            try await scanCheckpoint(index, invocation)
            guard link.baseLocator == base, link.destination.presentationMode == .sameTab,
                  link.aliases.count <= 64 else { throw ActionPortError.invalidResponse }
            let section = link.destination.sectionLocator, focus = link.destination.focusLocator
            try requireSourceReference(section, backend: backend, work: nil, catalog: entries)
            if let focus {
                try requireSourceReference(focus, backend: backend, work: nil, catalog: entries)
                guard focus.workKey == section.workKey, compatible(focus.catalogRevision, section.catalogRevision),
                      compatible(focus.dataRevision, section.dataRevision) else { throw ActionPortError.invalidResponse }
            }
            try requireSourceText(link.title, maximum: 512)
            for alias in link.aliases { try requireSourceText(alias, maximum: 512) }
            bytes += link.title.utf8.count + link.aliases.reduce(0) { $0 + $1.utf8.count }
            guard bytes <= maximumCatalogBytes else { throw ActionPortError.invalidResponse }
            let work = ActionWorkRef(backend: backend, workKey: section.workKey, catalogRevision: section.catalogRevision)
            if let selected = query.workRef, !matches(work, selected) { continue }
            if let name, !matchingCatalogWorkKeys.contains(work.workKey) {
                guard try ([link.title] + link.aliases).contains(where: {
                    try normalizedName($0, field: "source") == name
                }) else { continue }
            }
            let exact = focus ?? section
            if let previous = destinations[exact] {
                guard previous.0 == link.destination else { throw ActionPortError.invalidResponse }
                continue
            }
            guard destinations.count < maximumReferenceCandidates else { throw ActionPortError.invalidResponse }
            do {
                try await validateExactly(section, invocation)
                if let focus, focus != section { try await validateExactly(focus, invocation) }
            } catch ActionPortError.notFound { throw ActionPortError.invalidResponse }
            destinations[exact] = (link.destination, link.title)
        }
        try await checkpoint(invocation)
        guard !destinations.isEmpty else { return .notFound }
        if destinations.count == 1, let value = destinations.values.first { return .unique(value.0) }
        let candidates = try destinations.keys.sorted(by: textLess).prefix(25).map { ref in
            ActionCandidate(ref: try object(ref), title: destinations[ref]!.1,
                            kind: .segment, confidenceBand: .exact, reason: "source_commentary_link")
        }
        return .ambiguous(candidates)
    }

    public func validateDestination(_ destination: ActionReaderDestination,
                                    invocation: ActionPortInvocation) async throws -> ActionReaderDestination {
        let section = destination.sectionLocator
        try requireBackend(section.backend, invocation)
        try requireReference(section)
        if let focus = destination.focusLocator {
            try requireReference(focus)
            guard focus.backend == section.backend, focus.workKey == section.workKey,
                  compatible(focus.catalogRevision, section.catalogRevision),
                  compatible(focus.dataRevision, section.dataRevision) else { throw ActionContractError.invalid("focusLocator") }
        }
        let entries = try await catalog(section.backend, invocation)
        try requireSourceReference(section, backend: section.backend, work: nil, catalog: entries)
        if let focus = destination.focusLocator {
            try requireSourceReference(focus, backend: section.backend, work: nil, catalog: entries)
        }
        try await validateExactly(section, invocation)
        if let focus = destination.focusLocator, focus != section { try await validateExactly(focus, invocation) }
        try await checkpoint(invocation)
        return destination
    }

    private func catalog(_ backend: ActionBackendID, _ invocation: ActionPortInvocation) async throws -> CatalogView {
        let entries = try await sourceCall(invocation) { [data] in try await data.catalog(for: backend, invocation: invocation) }
        guard entries.count <= maximumCatalogEntries else { throw ActionPortError.invalidResponse }
        var bytes = 0
        var identities = Set<ActionWorkRef>()
        var workKeys = Set<String>()
        for (index, entry) in entries.enumerated() {
            try await scanCheckpoint(index, invocation)
            do { try requireWork(entry.workRef, backend: backend) }
            catch { throw ActionPortError.invalidResponse }
            try requireSourceText(entry.title, maximum: 512)
            try requireSourceText(entry.provenance, maximum: 512)
            guard entry.kind == .work || entry.kind == .commentary, entry.aliases.count <= 64 else { throw ActionPortError.invalidResponse }
            bytes += entry.title.utf8.count + entry.provenance.utf8.count + entry.workRef.workKey.utf8.count + (entry.workRef.catalogRevision?.utf8.count ?? 0)
            identities.insert(entry.workRef)
            workKeys.insert(entry.workRef.workKey)
            for alias in entry.aliases {
                try requireSourceText(alias, maximum: 512)
                bytes += alias.utf8.count
            }
            guard bytes <= maximumCatalogBytes else { throw ActionPortError.invalidResponse }
        }
        try await checkpoint(invocation)
        return CatalogView(entries: entries, identities: identities, workKeys: workKeys)
    }

    private func validateExactly(_ ref: ActionTextRef, _ invocation: ActionPortInvocation) async throws {
        let verified = try await sourceCall(invocation) { [data] in try await data.validate(ref, invocation: invocation) }
        guard verified == ref else { throw ActionPortError.invalidResponse }
    }

    private func sourceCall<T: Sendable>(_ invocation: ActionPortInvocation,
                                        operation: @Sendable () async throws -> T) async throws -> T {
        try await checkpoint(invocation)
        let value: T
        do { value = try await operation() }
        catch {
            try await checkpoint(invocation)
            if error is CancellationError { throw CancellationError() }
            throw (error as? ActionPortError) ?? .unavailable
        }
        try await checkpoint(invocation)
        return value
    }

    private func checkpoint(_ invocation: ActionPortInvocation) async throws {
        try localCheckpoint(invocation)
        let current: ActionBackendSnapshot
        do { current = try await state.snapshot() }
        catch {
            try localCheckpoint(invocation)
            if error is CancellationError { throw CancellationError() }
            throw (error as? ActionPortError) ?? .unavailable
        }
        try localCheckpoint(invocation)
        guard current == invocation.snapshot else { throw ActionPortError.staleState }
    }

    private func localCheckpoint(_ invocation: ActionPortInvocation) throws {
        try Task.checkCancellation()
        guard uptime() < invocation.deadlineUptimeNanoseconds else { throw CancellationError() }
    }

    private func scanCheckpoint(_ index: Int, _ invocation: ActionPortInvocation) async throws {
        try localCheckpoint(invocation)
        if index.isMultiple(of: 256) { await Task.yield(); try await checkpoint(invocation) }
    }

    private func requireBackend(_ backend: ActionBackendID, _ invocation: ActionPortInvocation) throws {
        guard backend == invocation.snapshot.backend else { throw ActionContractError.invalid("backend") }
        if backend == .sefariaEmbedded, invocation.snapshot.rpcEpoch == nil { throw ActionPortError.unavailable }
    }

    private func requireWork(_ ref: ActionWorkRef, backend: ActionBackendID) throws {
        guard ref.backend == backend else { throw ActionContractError.invalid("workRef.backend") }
        try requireText(ref.workKey, maximum: 512, field: "workRef.workKey")
        guard ref.workKey == ref.workKey.trimmingCharacters(in: .whitespacesAndNewlines) else { throw ActionContractError.invalid("workRef.workKey") }
        if ref.backend == .otzaria {
            guard ref.workKey.hasPrefix("book:"), let id = Int64(ref.workKey.dropFirst(5)), id >= 0,
                  ref.workKey == "book:\(id)" else { throw ActionContractError.invalid("workRef.workKey") }
        }
        if let revision = ref.catalogRevision { try requireText(revision, maximum: 128, field: "catalogRevision") }
    }

    private func requireReference(_ ref: ActionTextRef) throws {
        try requireWork(ActionWorkRef(backend: ref.backend, workKey: ref.workKey, catalogRevision: ref.catalogRevision), backend: ref.backend)
        switch (ref.backend, ref.position) {
        case (.otzaria, .legacyLine(let line)) where line >= 0: break
        case (.sefaria, .canonicalRef(let value)), (.sefariaEmbedded, .canonicalRef(let value)):
            try requireText(value, maximum: 1_000, field: "position")
        default: throw ActionContractError.invalid("position")
        }
        if let revision = ref.dataRevision { try requireText(revision, maximum: 128, field: "dataRevision") }
    }

    private func requireSourceReference(_ ref: ActionTextRef, backend: ActionBackendID,
                                        work: ActionWorkRef?, catalog: CatalogView) throws {
        do { try requireReference(ref) } catch { throw ActionPortError.invalidResponse }
        guard ref.backend == backend,
              work.map({ $0.backend == ref.backend && $0.workKey == ref.workKey && ($0.catalogRevision == nil || $0.catalogRevision == ref.catalogRevision) }) ?? true,
              catalog.contains(ActionWorkRef(backend: ref.backend, workKey: ref.workKey, catalogRevision: ref.catalogRevision)) else {
            throw ActionPortError.invalidResponse
        }
    }

    private func requireText(_ value: String, maximum: Int, field: String) throws {
        guard !value.isEmpty, value.utf8.count <= maximum * 8, value.count <= maximum,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            throw ActionContractError.invalid(field)
        }
    }

    private func requireSourceText(_ value: String, maximum: Int) throws {
        do { try requireText(value, maximum: maximum, field: "source") }
        catch { throw ActionPortError.invalidResponse }
    }

    private func normalizedName(_ value: String, field: String) throws -> String {
        try ActionSourceName.normalize(value, field: field)
    }

    private func match(_ query: String, entry: ActionCatalogEntry) throws -> ActionCandidate.Confidence? {
        if query == (try normalizedName(entry.title, field: "source")) || query == entry.workRef.workKey { return .exact }
        for alias in entry.aliases where query == (try normalizedName(alias, field: "source")) { return .alias }
        return nil
    }

    private func matches(_ source: ActionWorkRef, _ explicit: ActionWorkRef) -> Bool {
        source.backend == explicit.backend && source.workKey == explicit.workKey && (explicit.catalogRevision == nil || source.catalogRevision == explicit.catalogRevision)
    }

    private func compatible(_ a: String?, _ b: String?) -> Bool { a == nil || b == nil || a == b }
    private func workLess(_ a: ActionWorkRef, _ b: ActionWorkRef) -> Bool {
        (a.backend.rawValue, a.workKey, a.catalogRevision ?? "") < (b.backend.rawValue, b.workKey, b.catalogRevision ?? "")
    }
    private func textLess(_ a: ActionTextRef, _ b: ActionTextRef) -> Bool {
        let aw = ActionWorkRef(backend: a.backend, workKey: a.workKey, catalogRevision: a.catalogRevision)
        let bw = ActionWorkRef(backend: b.backend, workKey: b.workKey, catalogRevision: b.catalogRevision)
        if aw != bw { return workLess(aw, bw) }
        if a.position != b.position {
            switch (a.position, b.position) {
            case (.legacyLine(let x), .legacyLine(let y)): return x < y
            case (.canonicalRef(let x), .canonicalRef(let y)): return x < y
            case (.legacyLine, .canonicalRef): return true
            case (.canonicalRef, .legacyLine): return false
            }
        }
        return (a.dataRevision ?? "") < (b.dataRevision ?? "")
    }
    private func prefer(_ entry: ActionCatalogEntry, _ confidence: ActionCandidate.Confidence,
                        over current: (entry: ActionCatalogEntry, confidence: ActionCandidate.Confidence)) -> Bool {
        let priority = confidence == .exact ? 0 : 1
        let currentPriority = current.confidence == .exact ? 0 : 1
        return (priority, entry.title, entry.provenance) < (currentPriority, current.entry.title, current.entry.provenance)
    }
    private func object<T: Encodable>(_ value: T) throws -> ActionObject {
        guard let object = try ActionJSON.encoded(value).object else { throw ActionPortError.invalidResponse }
        return object
    }
}