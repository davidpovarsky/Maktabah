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
    private var didAttemptRestore = false
    private var modelObservation: AnyCancellable?

    init() {
        let model = ZayitSearchViewModel(repository: ZayitSearchRepository())
        self.model = model
        self.folderAccess = ZayitSearchFolderAccess()
        modelObservation = model.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func restoreIfNeeded(existingSeforimDB: URL?) async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true
        state = .restoring

        do {
            guard let folder = try folderAccess.restoreAndActivate() else {
                state = .notConfigured
                return
            }
            try await configure(folder: folder, existingSeforimDB: existingSeforimDB)
            state = .ready
        } catch {
            await model.reset()
            folderAccess.deactivate()
            state = .failed(error.localizedDescription)
        }
    }

    func chooseFolder(_ url: URL, existingSeforimDB: URL?) async {
        didAttemptRestore = true
        state = .restoring
        await model.reset()

        do {
            let folder = try folderAccess.selectAndActivate(url)
            try await configure(folder: folder, existingSeforimDB: existingSeforimDB)
            state = .ready
        } catch {
            await model.reset()
            folderAccess.deactivate()
            state = .failed(error.localizedDescription)
        }
    }

    func forget() async {
        didAttemptRestore = true
        await model.reset()
        folderAccess.clear()
        state = .notConfigured
    }

    private func configure(folder: URL, existingSeforimDB: URL?) async throws {
        let paths = try ZayitSearchDataValidator.paths(
            in: folder,
            existingSeforimDB: existingSeforimDB
        )
        try await model.configure(paths: paths)
    }
}
