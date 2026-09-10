import Combine
import Foundation

extension Notification.Name {
    static let activeLibraryBackendDidChange = Notification.Name("activeLibraryBackendDidChange")
    static let libraryBackendConfigurationRequested = Notification.Name("libraryBackendConfigurationRequested")
}

@MainActor
final class BackendCoordinator: ObservableObject {
    enum StartupResolution: Equatable {
        case chooseSource
        case configureOtzaria
        case ready(BackendID)
    }
    static let shared = BackendCoordinator()
    nonisolated static let selectionDefaultsKey = "activeLibraryBackend.v1"

    @Published private(set) var activeBackendID: BackendID
    @Published private(set) var pendingBackendID: BackendID?
    @Published private(set) var generation: UInt64 = 0

    private var registrations: [BackendID: LibraryBackendRegistration] = [:]
    private var inFlightCancellations: [UUID: @Sendable () -> Void] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let committed = defaults.string(forKey: Self.selectionDefaultsKey)
            .flatMap(BackendID.init(rawValue:))
        activeBackendID = committed ?? .otzaria
        pendingBackendID = nil
    }

    var committedBackendID: BackendID? {
        defaults.string(forKey: Self.selectionDefaultsKey).flatMap(BackendID.init(rawValue:))
    }

    var activeCapabilities: BackendCapabilities {
        registrations[activeBackendID]?.capabilities ?? []
    }

    var capabilities: BackendCapabilities {
        activeCapabilities
    }

    var usesNativeMaktabahDataPath: Bool {
        registrations[activeBackendID]?.usesNativeMaktabahDataPath ?? true
    }

    var activeSourceDescription: String {
        registrations[activeBackendID]?.sourceDescription ?? activeBackendID.displayName
    }

    func register(_ registration: LibraryBackendRegistration) {
        registrations[registration.id] = registration
    }

    func beginConfiguration(of backendID: BackendID) {
        pendingBackendID = backendID
    }

    func cancelConfiguration() {
        pendingBackendID = nil
    }

    func resolveStartup(hasValidOtzariaInstallation: Bool) -> StartupResolution {
        switch committedBackendID {
        case .sefaria:
            return .ready(.sefaria)
        case .otzaria:
            return hasValidOtzariaInstallation ? .ready(.otzaria) : .configureOtzaria
        case nil:
            guard hasValidOtzariaInstallation else { return .chooseSource }
            commit(.otzaria)
            return .ready(.otzaria)
        }
    }

    func commit(_ backendID: BackendID) {
        let wasCommitted = committedBackendID == backendID
        pendingBackendID = nil
        defaults.set(backendID.rawValue, forKey: Self.selectionDefaultsKey)
        guard !wasCommitted || backendID != activeBackendID else { return }
        let oldRegistrations = registrations.values
        inFlightCancellations.values.forEach { $0() }
        inFlightCancellations.removeAll()
        generation &+= 1
        activeBackendID = backendID
        Task {
            for registration in oldRegistrations {
                await registration.invalidateTransientState()
            }
        }
        NotificationCenter.default.post(name: .activeLibraryBackendDidChange, object: backendID)
        NotificationCenter.default.post(name: .libraryFolderChanged, object: nil)
    }

    /// Compatibility entry point for callers whose selection is immediately usable.
    func select(_ backendID: BackendID) {
        commit(backendID)
    }

    func catalog(forceRefresh: Bool = false) async throws -> [LibraryCatalogNode] {
        guard let provider = registrations[activeBackendID]?.catalog else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.catalog(forceRefresh: forceRefresh) }
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        guard locator.backend == activeBackendID else { throw LibraryBackendError.staleRequest }
        guard let provider = registrations[activeBackendID]?.text else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.section(at: locator) }
    }

    func normalize(_ input: String) async throws -> TextLocator {
        guard let provider = registrations[activeBackendID]?.navigation else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.normalizedLocator(for: input) }
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        guard work.locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.navigation else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.tableOfContents(for: work) }
    }

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        guard let provider = registrations[activeBackendID]?.search else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.search(request) }
    }

    func authors() async throws -> [LibraryAuthor] {
        guard let provider = registrations[activeBackendID]?.authors else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.authors() }
    }

    func versions(for workKey: String) async throws -> [TextVersionMetadata] {
        guard let provider = registrations[activeBackendID]?.metadata else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.versions(for: workKey) }
    }

    func related(to locator: TextLocator) async throws -> [TextLocator] {
        guard locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.metadata else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.related(to: locator) }
    }

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        guard locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.relationships else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.links(for: locator) }
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        guard locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.relationships else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.topics(for: locator) }
    }

    func offlineProvider() -> (any OfflineLibraryProviding)? {
        registrations[activeBackendID]?.offline
    }

    private func validate(_ requestGeneration: UInt64) throws {
        try Task.checkCancellation()
        guard requestGeneration == generation else { throw LibraryBackendError.staleRequest }
    }

    private func perform<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let requestGeneration = generation
        let id = UUID()
        let task = Task<T, Error> { try await operation() }
        inFlightCancellations[id] = { task.cancel() }
        defer { inFlightCancellations.removeValue(forKey: id) }
        let result = try await task.value
        try validate(requestGeneration)
        return result
    }
}
