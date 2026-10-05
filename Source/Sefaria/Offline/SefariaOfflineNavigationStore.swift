import Foundation

actor SefariaOfflineNavigationStore: LibraryNavigationProviding, LibraryWorkMetadataProviding {
    private let offline: SefariaOfflineStore

    init(offline: SefariaOfflineStore) {
        self.offline = offline
    }

    func normalizedLocator(for input: String) async throws -> TextLocator {
        let ref = SefariaRef.canonicalInput(input)
        let installed = try await candidateWorkKey(for: ref)
        return TextLocator(backend: .sefaria, workKey: installed, position: .canonicalRef(ref))
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        SefariaOfflineNavigationBuilder.nodes(
            metadata: try await offline.navigationMetadata(for: work.locator.workKey),
            workKey: work.locator.workKey
        )
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        let nodes = try await tableOfContents(for: work)
        return nodes.enumerated().map {
            LibraryNavigationItem(locator: $0.element.locator, title: $0.element.title, index: $0.offset)
        }
    }

    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        let nodes = try await tableOfContents(for: work)
        guard !nodes.isEmpty else { throw LibraryBackendError.corruptData("downloaded work has no navigation units") }
        return [LibraryNavigationStructure(id: "primary", title: String(localized: "Table of Contents"), nodes: nodes)]
    }

    func workMetadata(for workKey: String) async throws -> LibraryWorkMetadata? {
        let index = try await offline.index(for: workKey)
        return LibraryWorkMetadata(
            workKey: workKey,
            title: index.title,
            heTitle: index.heTitle,
            description: LibraryPresentationPolicy.prefersHebrew() ? (index.heDesc ?? index.enDesc) : (index.enDesc ?? index.heDesc),
            categories: LibraryPresentationPolicy.prefersHebrew() ? (index.heCategories ?? index.categories ?? []) : (index.categories ?? []),
            factualFields: []
        )
    }

    private func candidateWorkKey(for ref: String) async throws -> String {
        let components = ref.split(separator: " ")
        for count in stride(from: components.count, through: 1, by: -1) {
            let candidate = components.prefix(count).joined(separator: " ")
            if await offline.contains(workKey: candidate) { return candidate }
        }
        throw LibraryBackendError.unavailableOffline
    }

}
