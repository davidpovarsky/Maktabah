import Foundation

extension CatalogActionResolver {
    /// Source-only candidate matching for the data port. The enclosing canonical
    /// resolveReference still proves every returned locator against the provider
    /// and rechecks its retained backend generation. Never picks the first of
    /// several same-named sections and never searches a truncated TOC prefix.
    public nonisolated static func sourceSectionCandidates(
        section: String, work: ActionWorkRef, entries: [ActionSourceSectionEntry],
        invocation: ActionPortInvocation
    ) throws -> ActionResolution<ActionTextRef> {
        try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: work.backend)
        try ActionValidation.work(work, backend: invocation.snapshot.backend)
        let wanted = try ActionSourceName.normalize(section, field: "section")
        guard entries.count <= 100_000 else { throw ActionPortError.unavailable }
        var bytes = 0, seen = Set<ActionTextRef>()
        var matches: [ActionSourceSectionEntry] = []
        for entry in entries {
            try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: work.backend)
            let normalized: String
            do {
                try ActionValidation.text(entry.locator, backend: work.backend)
                normalized = try ActionSourceName.normalize(entry.title, field: "source")
            } catch { throw ActionPortError.invalidResponse }
            guard entry.locator.workKey == work.workKey,
                  work.catalogRevision == nil || work.catalogRevision == entry.locator.catalogRevision else {
                throw ActionPortError.invalidResponse
            }
            bytes += entry.title.utf8.count + entry.locator.workKey.utf8.count
                + (entry.locator.catalogRevision?.utf8.count ?? 0) + (entry.locator.dataRevision?.utf8.count ?? 0)
            switch entry.locator.position {
            case .canonicalRef(let value): bytes += value.utf8.count
            case .legacyLine: break
            }
            guard bytes <= 32 * 1_024 * 1_024 else { throw ActionPortError.unavailable }
            if normalized == wanted, seen.insert(entry.locator).inserted {
                matches.append(entry)
                guard matches.count <= 256 else { throw ActionPortError.unavailable }
            }
        }
        try ActionBackendInvocationGuard.check(invocation, current: invocation.snapshot, target: work.backend)
        if matches.isEmpty { return .notFound }
        if matches.count == 1 { return .unique(matches[0].locator) }
        return .ambiguous(try matches.map { entry in
            guard let ref = try ActionJSON.encoded(entry.locator).object else { throw ActionPortError.invalidResponse }
            return ActionCandidate(ref: ref, title: entry.title, kind: .section, confidenceBand: .exact)
        })
    }
}
