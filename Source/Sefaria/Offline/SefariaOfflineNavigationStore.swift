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
        let structures = try await navigationStructures(for: work)
        return structures.first(where: { $0.id == "primary" })?.nodes ?? structures.first?.nodes ?? []
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        let nodes = try await tableOfContents(for: work)
        var items: [LibraryNavigationItem] = []
        func collectLeaves(_ values: [LibraryTOCNode]) {
            for node in values {
                if node.children.isEmpty {
                    items.append(LibraryNavigationItem(locator: node.locator, title: node.title, index: items.count))
                } else {
                    collectLeaves(node.children)
                }
            }
        }
        collectLeaves(nodes)
        return items
    }

    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        let index = try await offline.index(for: work.locator.workKey)
        var structures = SefariaNavigationParser.structures(
            schema: index.schema,
            alternateStructures: index.alternateStructures,
            indexTitle: index.title,
            baseRef: index.title
        )
        let metadataNodes = SefariaOfflineNavigationBuilder.nodes(
            metadata: try await offline.navigationMetadata(for: work.locator.workKey),
            workKey: work.locator.workKey
        )
        if let primaryIndex = structures.firstIndex(where: { $0.id == "primary" }),
           structures[primaryIndex].nodes.isEmpty,
           !metadataNodes.isEmpty {
            structures[primaryIndex] = LibraryNavigationStructure(
                id: "primary",
                title: structures[primaryIndex].title,
                nodes: metadataNodes
            )
        }
        if structures.isEmpty, !metadataNodes.isEmpty {
            structures = [LibraryNavigationStructure(
                id: "primary",
                title: String(localized: "Table of Contents"),
                nodes: metadataNodes
            )]
        }
        guard structures.contains(where: { !$0.nodes.isEmpty }) else {
            throw LibraryBackendError.corruptData("downloaded work has no navigation units")
        }
        return structures.filter { !$0.nodes.isEmpty }
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
