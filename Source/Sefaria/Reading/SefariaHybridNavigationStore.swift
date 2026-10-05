import Foundation

actor SefariaHybridNavigationStore: LibraryNavigationProviding, LibraryWorkMetadataProviding {
    private let isInstalled: @Sendable (String) async -> Bool
    private let local: any LibraryNavigationProviding
    private let remote: any LibraryNavigationProviding
    private let localMetadata: any LibraryWorkMetadataProviding
    private let remoteMetadata: any LibraryWorkMetadataProviding

    init(
        isInstalled: @escaping @Sendable (String) async -> Bool,
        local: any LibraryNavigationProviding & LibraryWorkMetadataProviding,
        remote: any LibraryNavigationProviding & LibraryWorkMetadataProviding
    ) {
        self.isInstalled = isInstalled
        self.local = local
        self.remote = remote
        self.localMetadata = local
        self.remoteMetadata = remote
    }

    func normalizedLocator(for input: String) async throws -> TextLocator {
        do { return try await remote.normalizedLocator(for: input) }
        catch { return try await local.normalizedLocator(for: input) }
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        try await localFirst(work: work) { provider in try await provider.tableOfContents(for: work) }
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        try await localFirst(work: work) { provider in try await provider.navigationItems(for: work) }
    }

    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        try await localFirst(work: work) { provider in try await provider.navigationStructures(for: work) }
    }

    func workMetadata(for workKey: String) async throws -> LibraryWorkMetadata? {
        if await isInstalled(workKey), let metadata = try? await localMetadata.workMetadata(for: workKey) {
            return metadata
        }
        do { return try await remoteMetadata.workMetadata(for: workKey) }
        catch {
            if await isInstalled(workKey) { return try await localMetadata.workMetadata(for: workKey) }
            throw error
        }
    }

    private func localFirst<T: Sendable>(
        work: LibraryWork,
        operation: @escaping @Sendable (any LibraryNavigationProviding) async throws -> T
    ) async throws -> T {
        if await isInstalled(work.locator.workKey),
           let value = try? await operation(local) { return value }
        do { return try await operation(remote) }
        catch {
            if await isInstalled(work.locator.workKey) { return try await operation(local) }
            throw error
        }
    }
}
