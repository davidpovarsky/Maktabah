import Combine
import Foundation

@MainActor
final class ZayitSearchSessionController: ObservableObject {
    enum State: Equatable {
        case notConfigured
        case restoring
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .restoring

    let model: ZayitSearchViewModel

    private let folderAccess: ZayitSearchFolderAccess
    private var configuredStamp: String?
    private var configuredPaths: ZayitSearchDataPaths?
    private var pendingStamp: String?
    private var restoreTask: Task<Void, Never>?
    private var operationGeneration = 0
    private var modelObservation: AnyCancellable?
    private var dataObservation: AnyCancellable?

    init() {
        let model = ZayitSearchViewModel(repository: ZayitSearchRepository())
        self.model = model
        self.folderAccess = ZayitSearchFolderAccess()
        modelObservation = model.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        dataObservation = ZayitSearchDataController.shared.$revision.dropFirst().sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.invalidate()
            }
        }
    }

    func restoreIfNeeded(existingSeforimDB: URL?) async {
        let stamp = configurationStamp(existingSeforimDB: existingSeforimDB)
        if pendingStamp == stamp, let restoreTask {
            await restoreTask.value
            return
        }
        guard state != .ready || configuredStamp != stamp || restoreTask != nil else { return }
        state = .restoring
        pendingStamp = stamp
        await enqueue { generation in
            await self.restore(existingSeforimDB: existingSeforimDB, generation: generation, stamp: stamp)
        }
    }

    // Keep configure/reset ordered across suspension points. Superseded work
    // may finish in the repository, but cannot publish readiness or race a reset.
    private func enqueue(_ operation: @escaping @MainActor (Int) async -> Void) async {
        operationGeneration += 1
        let generation = operationGeneration
        let previous = restoreTask
        let task = Task { @MainActor in
            await previous?.value
            guard self.operationGeneration == generation else { return }
            await operation(generation)
        }
        restoreTask = task
        await task.value
        if operationGeneration == generation {
            restoreTask = nil
            pendingStamp = nil
        }
    }

    private func restore(existingSeforimDB: URL?, generation: Int, stamp: String) async {
        let expectedSource = configurationStamp(existingSeforimDB: existingSeforimDB, includeConfiguredPaths: false)
        await model.reset()
        guard operationGeneration == generation else { return }

        do {
            if let database = existingSeforimDB {
                let package = await ZayitSearchArtifactService.shared.status(databaseURL: database)
                guard operationGeneration == generation else { return }
                guard expectedSource == configurationStamp(existingSeforimDB: existingSeforimDB, includeConfiguredPaths: false) else {
                    throw ZayitSearchDistributionError.incompatible("database or index changed during validation")
                }
                switch package {
                case .ready:
                    guard let lexical = OtzariaMagicDictionaryManager.shared.validatedDatabaseURL else {
                        if OtzariaDatabaseAccessController.shared.source == .managedInternal {
                            throw ZayitSearchDistributionError.validationFailed("lexical.db אינו זמין; יש לבדוק את נתוני החיפוש.")
                        }
                        break
                    }
                    let storage = try ZayitSearchArtifactStorage()
                    let paths = try ZayitSearchDataValidator.managedPaths(
                        seforimDB: database, lexicalDB: lexical, indexDirectory: storage.finalIndex)
                    try await model.configure(paths: paths)
                    guard operationGeneration == generation else { return }
                    guard expectedSource == configurationStamp(existingSeforimDB: existingSeforimDB, includeConfiguredPaths: false) else {
                        throw ZayitSearchDistributionError.incompatible("database or index changed during configuration")
                    }
                    configuredPaths = paths
                    configuredStamp = configurationStamp(existingSeforimDB: existingSeforimDB)
                    state = .ready
                    return
                case .incompatible(let detail):
                    if OtzariaDatabaseAccessController.shared.source == .managedInternal {
                        throw ZayitSearchDistributionError.incompatible(detail)
                    }
                case .repairRequired(let detail), .failed(let detail):
                    if OtzariaDatabaseAccessController.shared.source == .managedInternal {
                        throw ZayitSearchDistributionError.validationFailed(detail)
                    }
                default: break
                }
            }
            guard let folder = try folderAccess.restoreAndActivate() else {
                state = .notConfigured
                return
            }
            try await configure(folder: folder, existingSeforimDB: existingSeforimDB)
            guard operationGeneration == generation else { return }
            guard expectedSource == configurationStamp(existingSeforimDB: existingSeforimDB, includeConfiguredPaths: false) else {
                throw ZayitSearchDistributionError.incompatible("database or index changed during configuration")
            }
            configuredStamp = configurationStamp(existingSeforimDB: existingSeforimDB)
            state = .ready
        } catch {
            guard operationGeneration == generation else { return }
            await model.reset()
            guard operationGeneration == generation else { return }
            folderAccess.deactivate()
            state = .failed(error.localizedDescription)
        }
    }

    func chooseFolder(_ url: URL, existingSeforimDB: URL?) async {
        configuredStamp = nil
        configuredPaths = nil
        pendingStamp = nil
        state = .restoring
        await enqueue { generation in
            await self.model.reset()
            guard self.operationGeneration == generation else { return }
            do {
                let folder = try self.folderAccess.selectAndActivate(url)
                try await self.configure(folder: folder, existingSeforimDB: existingSeforimDB)
                guard self.operationGeneration == generation else { return }
                self.configuredStamp = self.configurationStamp(existingSeforimDB: existingSeforimDB)
                self.state = .ready
            } catch {
                guard self.operationGeneration == generation else { return }
                await self.model.reset()
                guard self.operationGeneration == generation else { return }
                self.folderAccess.deactivate()
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func forget() async {
        configuredStamp = nil
        configuredPaths = nil
        pendingStamp = nil
        state = .notConfigured
        await enqueue { generation in
            await self.model.reset()
            guard self.operationGeneration == generation else { return }
            self.folderAccess.clear()
        }
    }

    /// Revoke the previous library's ready state synchronously. Queued
    /// restores may finish, but their older generation cannot publish it again.
    func invalidateSourceReadiness() {
        operationGeneration += 1
        configuredStamp = nil
        configuredPaths = nil
        pendingStamp = nil
        state = .notConfigured
    }

    func invalidate() async {
        configuredStamp = nil
        configuredPaths = nil
        pendingStamp = nil
        state = .notConfigured
        await enqueue { _ in await self.model.reset() }
    }

    private func configurationStamp(
        existingSeforimDB: URL?, includeConfiguredPaths: Bool = true,
        additionalPaths: ZayitSearchDataPaths? = nil
    ) -> String {
        var urls = [existingSeforimDB, OtzariaMagicDictionaryManager.shared.validatedDatabaseURL].compactMap { $0 }
        for paths in [includeConfiguredPaths ? configuredPaths : nil, additionalPaths].compactMap({ $0 }) {
            let index = URL(fileURLWithPath: paths.indexDir, isDirectory: true)
            urls += [URL(fileURLWithPath: paths.seforimDb), URL(fileURLWithPath: paths.lexicalDb),
                     index.appendingPathComponent("meta.json"), index.appendingPathComponent("zayit-index-metadata.json")]
        }
        if let storage = try? ZayitSearchArtifactStorage() {
            urls += [storage.installedManifest, storage.finalIndex.appendingPathComponent("meta.json"),
                     storage.finalIndex.appendingPathComponent("zayit-index-metadata.json")]
        }
        let files = urls.map { url in
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            return "\(url.path)|\(attributes?[.size] ?? 0)|\(attributes?[.modificationDate] ?? "missing")"
        }
        return ([OtzariaDataProfileRegistry.activeProfileID, String(describing: OtzariaDatabaseAccessController.shared.source),
                 String(ZayitSearchDataController.shared.revision),
                 managedDatabaseIdentityStamp(existingSeforimDB: existingSeforimDB)] + files)
            .joined(separator: "\u{1f}")
    }

    private func managedDatabaseIdentityStamp(existingSeforimDB: URL?) -> String {
        let selection = OtzariaDatabaseAccessController.shared.selectionObservation()
        guard selection.source == .managedInternal else { return "external" }
        guard let database = existingSeforimDB?.standardizedFileURL,
              database == selection.url?.standardizedFileURL else { return "managed-unavailable" }
        let url = database.deletingLastPathComponent().appendingPathComponent("seforim-installation.json")
        // The complete small receipt participates, so a same-size replacement
        // with a preserved mtime cannot reuse readiness from another release.
        let maximum = 1_048_576
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.uint64Value <= UInt64(maximum),
              let file = try? FileHandle(forReadingFrom: url) else { return "managed-unavailable" }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: maximum + 1),
              data.count == size.intValue, data.count <= maximum else { return "managed-unavailable" }
        return "\(selection.revision)|\(data.base64EncodedString())"
    }

    private func configure(folder: URL, existingSeforimDB: URL?) async throws {
        let paths = try ZayitSearchDataValidator.paths(
            in: folder,
            existingSeforimDB: existingSeforimDB
        )
        let expectedSource = configurationStamp(existingSeforimDB: existingSeforimDB,
            includeConfiguredPaths: false, additionalPaths: paths)
        try await model.configure(paths: paths)
        guard expectedSource == configurationStamp(existingSeforimDB: existingSeforimDB,
            includeConfiguredPaths: false, additionalPaths: paths) else {
            await model.reset()
            throw ZayitSearchDistributionError.incompatible("database or index changed during configuration")
        }
        configuredPaths = paths
    }
}
