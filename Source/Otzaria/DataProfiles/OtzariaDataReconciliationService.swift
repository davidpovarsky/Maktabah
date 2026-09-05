import Foundation

struct OtzariaDataReconciliationSnapshot: Equatable, Sendable {
    enum ComponentState: Equatable, Sendable {
        case ready
        case missing
        case stale(String)
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    let profileID: String
    let database: ComponentState
    let lexicalDatabase: ComponentState
    let otzariaIndex: ComponentState
    let zayitIndex: ComponentState

    var isReady: Bool {
        [database, lexicalDatabase, otzariaIndex, zayitIndex].allSatisfy(\.isReady)
    }

    var missingComponents: [OtzariaArtifactComponent] {
        [
            (.database, database),
            (.lexicalDatabase, lexicalDatabase),
            (.otzariaIndex, otzariaIndex),
            (.zayitIndex, zayitIndex),
        ].compactMap { component, state in state.isReady ? nil : component }
    }
}

actor OtzariaDataReconciliationService {
    static let shared = OtzariaDataReconciliationService()

    func reconcile(restoreDatabase: Bool = true) async -> OtzariaDataReconciliationSnapshot {
        let profileID = OtzariaDataProfileRegistry.activeProfileID
        let databaseState: OtzariaDataReconciliationSnapshot.ComponentState
        do {
            let available: Bool
            if restoreDatabase {
                available = try await OtzariaBootstrapAdapter.restoreForAppLaunch()
            } else {
                available = OtzariaMaktabahBridge.shared.databaseURL != nil
            }
            databaseState = available ? .ready : .missing
        } catch {
            databaseState = .failed(error.localizedDescription)
        }

        guard databaseState.isReady,
              let databasePath = OtzariaMaktabahBridge.shared.databasePath,
              let databaseURL = OtzariaMaktabahBridge.shared.databaseURL else {
            return .init(
                profileID: profileID,
                database: databaseState,
                lexicalDatabase: .missing,
                otzariaIndex: .missing,
                zayitIndex: .missing
            )
        }

        let lexicalState: OtzariaDataReconciliationSnapshot.ComponentState =
            OtzariaMagicDictionaryManager.shared.validatedDatabaseURL == nil ? .missing : .ready

        let otzariaState: OtzariaDataReconciliationSnapshot.ComponentState
        let manager = OtzariaSearchIndexManager.shared
        if manager.isIndexCurrent(databasePath: databasePath) {
            otzariaState = .ready
        } else if FileManager.default.fileExists(atPath: manager.indexURL(for: databasePath).path) {
            otzariaState = .stale("The installed Otzaria index does not match the active corpus profile.")
        } else {
            otzariaState = .missing
        }

        let zayitState: OtzariaDataReconciliationSnapshot.ComponentState
        switch await ZayitSearchArtifactService.shared.status(databaseURL: databaseURL) {
        case .ready:
            zayitState = .ready
        case .notInstalled, .available(_, _):
            zayitState = .missing
        case .repairRequired(let detail), .incompatible(let detail), .failed(let detail):
            zayitState = .stale(detail)
        case .discovering, .downloading(_, _), .installing(_, _), .updateAvailable(_, _):
            zayitState = .stale("The Zayit index is not ready for the active profile.")
        }

        return .init(
            profileID: profileID,
            database: databaseState,
            lexicalDatabase: lexicalState,
            otzariaIndex: otzariaState,
            zayitIndex: zayitState
        )
    }
}

actor OtzariaDataProfileSwitchService {
    static let shared = OtzariaDataProfileSwitchService()

    func switchProfile(to profileID: String) async throws -> OtzariaDataReconciliationSnapshot {
        let previous = OtzariaDataProfileRegistry.activeProfileID
        guard previous != profileID else {
            return await OtzariaDataReconciliationService.shared.reconcile()
        }

        OtzariaFileLogger.shared.log("[Otzaria] profile switch begin from=\(previous) to=\(profileID)")
        OtzariaBootstrapAdapter.cancelManagedDatabaseDownload()
        await OtzariaSearchArtifactService.shared.cancel()
        await ZayitSearchArtifactService.shared.cancel()

        OtzariaTantivySearchRepository.shared.closeAllEngines()
        OtzariaMaktabahBridge.shared.close()
        OtzariaDatabaseAccessController.shared.resetRuntimeState()

        do {
            try OtzariaDataProfileRegistry.selectProfile(profileID)
            let snapshot = await OtzariaDataReconciliationService.shared.reconcile()
            OtzariaFileLogger.shared.log(
                "[Otzaria] profile switch complete profile=\(profileID) ready=\(snapshot.isReady)"
            )
            return snapshot
        } catch {
            try? OtzariaDataProfileRegistry.selectProfile(previous)
            OtzariaDatabaseAccessController.shared.resetRuntimeState()
            _ = await OtzariaDataReconciliationService.shared.reconcile()
            OtzariaFileLogger.shared.log(
                "[Otzaria] profile switch rollback from=\(profileID) to=\(previous) error=\(error.localizedDescription)"
            )
            throw error
        }
    }
}
