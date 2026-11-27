import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Metadata and system-intent adapter for an existing original live Reader tab.
/// The app owns resolution, retained source, Core grant, mutation and visibility.
/// This service never changes profile/group/backend or manufactures a receipt.
@MainActor
public final class NativeReaderTabIntentService {
    public struct Tab: Sendable, Equatable {
        public let sceneID: UIStableID
        public let profileID: UUID
        public let groupID: UUID
        public let tabID: UUID
        public let backend: ActionBackendID
        public let title: String
        public let profileTitle: String
        public let groupTitle: String
        public let windowTitle: String
        public init(sceneID: UIStableID, profileID: UUID, groupID: UUID, tabID: UUID,
                    backend: ActionBackendID, title: String, profileTitle: String, groupTitle: String, windowTitle: String) {
            self.sceneID = sceneID; self.profileID = profileID; self.groupID = groupID
            self.tabID = tabID; self.backend = backend; self.title = title
            self.profileTitle = profileTitle; self.groupTitle = groupTitle; self.windowTitle = windowTitle
        }
        /// Length-independent, unambiguous composition of real identities.
        /// Titles and array offsets never identify a tab; this is not a URL.
        public var id: String {
            let identity = [sceneID.rawValue, backend.rawValue, profileID.uuidString, groupID.uuidString, tabID.uuidString]
                .joined(separator: "\u{0}")
            return "readerTab.v1." + Data(identity.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        public var detail: String { windowTitle }
    }
    public struct Failure: Error, Sendable {
        public let receipt: UISceneReceipt
        public let code: String
        public init(receipt: UISceneReceipt, code: String) { self.receipt = receipt; self.code = code }
    }
    public static let destination = UIDestinationID(rawValue: "native.reader.tab")!
    private let discover: @MainActor () throws -> [Tab]
    private let navigate: @MainActor (Tab, UUID) async throws -> UISceneAcknowledgement

    public init(discover: @escaping @MainActor () throws -> [Tab],
                navigate: @escaping @MainActor (Tab, UUID) async throws -> UISceneAcknowledgement) {
        self.discover = discover; self.navigate = navigate
    }
    private func catalog() throws -> [Tab] {
        try Task.checkCancellation()
        let values = try discover()
        guard values.count <= 512, Set(values.map(\.id)).count == values.count,
              values.allSatisfy({
                  !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.title.utf8.count <= 4096 && $0.profileTitle.utf8.count <= 1024
                    && $0.groupTitle.utf8.count <= 1024 && $0.windowTitle.utf8.count <= 1024 && $0.id.utf8.count <= 1024
              }) else { throw UIRouteError(.unavailable, "native_reader_tab_catalog_invalid") }
        return values
    }
    public func tabs(identifiers: [String]? = nil, matching query: String? = nil) throws -> [Tab] {
        guard (identifiers?.count ?? 0) <= 64, (query?.utf8.count ?? 0) <= 512,
              identifiers?.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1024 }) ?? true,
              identifiers.map({ Set($0).count == $0.count }) ?? true else {
            throw UIRouteError(.notSupported, "native_reader_tab_query_not_supported")
        }
        let values = try catalog()
        if let identifiers {
            let byID = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
            // Missing IDs remain absent for EntityQuery; execution rejects them.
            return identifiers.compactMap { byID[$0] }
        }
        guard let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return values }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let exact = values.filter { $0.title.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        if !exact.isEmpty { return exact }
        return values.filter {
            $0.title.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || $0.groupTitle.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || $0.profileTitle.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
    public func open(identifier: String) async throws -> UISceneAcknowledgement {
        guard !identifier.isEmpty, identifier.utf8.count <= 1024 else {
            throw UIRouteError(.notSupported, "native_reader_tab_identity_not_supported")
        }
        let current = try catalog().filter { $0.id == identifier }
        guard current.count == 1, let target = current.first else {
            throw UIRouteError(.staleState, "native_reader_tab_not_available")
        }
        let requestID = UUID()
        // The app retains the actual scene/store/tab BEFORE its first await,
        // enters the existing Core navigation fence once, then revalidates the
        // original native completion before returning this acknowledgement.
        let result = try await navigate(target, requestID)
        do { try Task.checkCancellation() }
        catch {
            if case .acknowledged(let receipt) = result {
                throw Failure(receipt: receipt, code: "native_effect_uncertain")
            }
            throw error
        }
        if case .acknowledged(let receipt) = result {
            let route = receipt.route
            guard route.version == 1, receipt.requestId == requestID, route.requestId == requestID,
                  route.destination == Self.destination, route.backend == target.backend,
                  route.content == nil, route.focus == nil, route.expectedBackendSnapshot == receipt.backendSnapshot,
                  route.presentation == .init(kind: .currentTab, tabID: UIStableID(rawValue: target.tabID.uuidString)),
                  route.state == .init(workspaceID: UIStableID(rawValue: target.groupID.uuidString),
                                       profileID: UIStableID(rawValue: target.profileID.uuidString)),
                  route.scene.kind == .specific, route.scene.sceneID == target.sceneID,
                  receipt.sceneID == target.sceneID, receipt.backendSnapshot.backend == target.backend,
                  receipt.appliedSceneRevision > receipt.basedOnSceneRevision, receipt.coreReceipt == nil else {
                throw Failure(receipt: receipt, code: "native_reader_tab_receipt_mismatch")
            }
        }
        return result
    }
}
