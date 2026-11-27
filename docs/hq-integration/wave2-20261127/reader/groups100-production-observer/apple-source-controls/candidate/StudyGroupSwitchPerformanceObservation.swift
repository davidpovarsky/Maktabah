#if DEBUG
import Foundation

/// Passive observations of the original group-switch operation. The interval
/// excludes the memory probes and log encoding/writing. It ends after ordinary
/// session persistence, not after TextKit/layout/first-pixel presentation.
@MainActor
enum StudyGroupSwitchPerformanceObservation {
    static let prefix = "[NativeGroupSwitchPerformance] "
    private static let launchID = UUID()
    private static var sequence = 0
    private static let limit = 512

    struct Token: Sendable {
        let namespace: String
        let operationID: UUID
        let launchID: UUID
        let sequence: Int
        let processID: Int32
        let sceneID: String
        let fromGroupID: UUID?
        let toGroupID: UUID
        let fromDocumentID: UUID?
        let beforeRevision: UInt64?
        let fromBackend: String
        let footprintBeforeBytes: UInt64?
        let startUptime: TimeInterval
    }

    private struct Sample: Encodable {
        let schema = 1
        let timingScope = "original group operation through ordinary session persistence"
        let memoryMetric = "phys_footprint_bytes"
        let memoryScope = "operation boundary samples; not continuous peak RSS"
        let namespace: String
        let operationID: UUID
        let launchID: UUID
        let sequence: Int
        let processID: Int32
        let sceneID: String
        let fromGroupID: UUID?
        let toGroupID: UUID
        let observedGroupID: UUID?
        let fromDocumentID: UUID?
        let observedDocumentID: UUID?
        let beforeRevision: UInt64?
        let afterRevision: UInt64?
        let fromBackend: String
        let observedBackend: String
        let footprintBeforeBytes: UInt64?
        let footprintAfterBytes: UInt64?
        let elapsedSeconds: TimeInterval
        let returnedNormally: Bool
    }

    /// All inputs are the actual process/registry/defaults values at begin().
    /// Ordinary production remains silent. The separate Debug-only opt-in lets
    /// the owned full-corpus native case observe the same original operation.
    static func admittedNamespace(arguments: [String], environment: [String: String],
                                  activeProfile: String, enabled: Bool, namespace: String?,
                                  productionEnabled: Bool = false) -> String? {
        guard arguments.contains("-StudyGroupPerformanceEnabled"), enabled,
              let namespace, UUID(uuidString: namespace) != nil else { return nil }
        let miniTest = environment["OTZARIA_DATA_PROFILE"] == "miniTest10" && activeProfile == "miniTest10"
        let explicitProduction = environment["OTZARIA_DATA_PROFILE"] == "production" && activeProfile == "production"
            && arguments.contains("-StudyGroupProductionPerformanceEnabled") && productionEnabled
        guard miniTest || explicitProduction else { return nil }
        return namespace
    }

    static func begin(sceneID: String, fromGroupID: UUID?, toGroupID: UUID,
                      fromDocumentID: UUID?, beforeRevision: UInt64?, backend: String) -> Token? {
        guard let namespace = admittedNamespace(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            activeProfile: OtzariaDataProfileRegistry.activeProfileID,
            enabled: UserDefaults.standard.bool(forKey: "StudyGroupPerformanceEnabled"),
            namespace: UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace"),
            productionEnabled: UserDefaults.standard.bool(forKey: "StudyGroupProductionPerformanceEnabled")
        ), sequence < limit else { return nil }
        sequence += 1
        let operationID = UUID()
        let footprint = UInt64(OtzariaIndexFileLogger.memoryFootprint)
        // The process clock is sampled after the start memory observation.
        return Token(namespace: namespace, operationID: operationID, launchID: launchID,
                     sequence: sequence, processID: ProcessInfo.processInfo.processIdentifier,
                     sceneID: sceneID, fromGroupID: fromGroupID, toGroupID: toGroupID,
                     fromDocumentID: fromDocumentID, beforeRevision: beforeRevision,
                     fromBackend: backend, footprintBeforeBytes: footprint,
                     startUptime: ProcessInfo.processInfo.systemUptime)
    }

    static func finish(_ token: Token, returnedNormally: Bool, observedGroupID: UUID?,
                       observedDocumentID: UUID?, afterRevision: UInt64?, backend: String) {
        let elapsed = ProcessInfo.processInfo.systemUptime - token.startUptime
        let footprint = UInt64(OtzariaIndexFileLogger.memoryFootprint)
        guard elapsed.isFinite, elapsed >= 0 else {
            OtzariaFileLogger.shared.log(prefix + "invalid monotonic interval")
            return
        }
        let sample = Sample(
            namespace: token.namespace, operationID: token.operationID, launchID: token.launchID,
            sequence: token.sequence, processID: token.processID, sceneID: token.sceneID,
            fromGroupID: token.fromGroupID, toGroupID: token.toGroupID, observedGroupID: observedGroupID,
            fromDocumentID: token.fromDocumentID, observedDocumentID: observedDocumentID,
            beforeRevision: token.beforeRevision, afterRevision: afterRevision,
            fromBackend: token.fromBackend, observedBackend: backend,
            footprintBeforeBytes: token.footprintBeforeBytes, footprintAfterBytes: footprint,
            elapsedSeconds: elapsed, returnedNormally: returnedNormally)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(sample), let text = String(data: bytes, encoding: .utf8) else { return }
        // The original serial logger owns all I/O. No synchronous writer,
        // new persistence owner, app state change, or diagnostic success oracle.
        OtzariaFileLogger.shared.log(prefix + text)
    }
}
#endif
