import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Finite metadata for the original scene's study profiles and tab groups.
/// Resolution, original async staging, Core authority, Store publication and
/// actual native visibility remain in the application-owned selection path.
@MainActor
public final class NativeWorkspaceSelectionIntentService {
    public enum Kind: String, Sendable { case profile, group }
    public struct Selection: Sendable, Equatable {
        public let kind: Kind
        public let sceneID: UIStableID
        public let backend: ActionBackendID
        public let profileID: UUID
        public let groupID: UUID
        public let activeDocumentID: UUID?
        public let title: String
        public let profileTitle: String
        public let groupTitle: String
        public let windowTitle: String

        public init(kind: Kind, sceneID: UIStableID, backend: ActionBackendID,
                    profileID: UUID, groupID: UUID, activeDocumentID: UUID?,
                    title: String, profileTitle: String, groupTitle: String, windowTitle: String) {
            self.kind = kind; self.sceneID = sceneID; self.backend = backend
            self.profileID = profileID; self.groupID = groupID; self.activeDocumentID = activeDocumentID
            self.title = title; self.profileTitle = profileTitle; self.groupTitle = groupTitle; self.windowTitle = windowTitle
        }
        /// A profile's identity is stable when its original first ordered group
        /// changes. Execution resolves that group freshly BEFORE its first await.
        /// No title, integer offset, locator or alternate backend is executable.
        public var id: String {
            let fields = [kind.rawValue, sceneID.rawValue, backend.rawValue, profileID.uuidString]
                + (kind == .group ? [groupID.uuidString] : [])
            return "workspaceSelection.v1." + Data(fields.joined(separator: "\u{0}").utf8).base64EncodedString()
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
    public static let destination = UIDestinationID(rawValue: "native.workspace.selection")!
    private let discover: @MainActor () throws -> [Selection]
    private let navigate: @MainActor (Selection, UUID) async throws -> UISceneAcknowledgement

    public init(discover: @escaping @MainActor () throws -> [Selection],
                navigate: @escaping @MainActor (Selection, UUID) async throws -> UISceneAcknowledgement) {
        self.discover = discover; self.navigate = navigate
    }

    private func catalog() throws -> [Selection] {
        try Task.checkCancellation()
        let values = try discover()
        guard values.count <= 512, Set(values.map(\.id)).count == values.count,
              values.allSatisfy({
                  !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.profileTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.title.utf8.count <= 1024 && $0.profileTitle.utf8.count <= 1024
                    && $0.groupTitle.utf8.count <= 1024 && $0.windowTitle.utf8.count <= 1024
                    && $0.id.utf8.count <= 1024
              }) else { throw UIRouteError(.unavailable, "native_workspace_selection_catalog_invalid") }
        return values
    }

    public func selections(kind: Kind, identifiers: [String]? = nil, matching query: String? = nil) throws -> [Selection] {
        guard (identifiers?.count ?? 0) <= 64, (query?.utf8.count ?? 0) <= 512,
              identifiers?.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1024 }) ?? true,
              identifiers.map({ Set($0).count == $0.count }) ?? true else {
            throw UIRouteError(.notSupported, "native_workspace_selection_query_not_supported")
        }
        let values = try catalog().filter { $0.kind == kind }
        if let identifiers {
            let byID = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
            return identifiers.compactMap { byID[$0] }
        }
        guard let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return values }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let exact = values.filter { $0.title.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        if !exact.isEmpty { return exact }
        return values.filter {
            $0.title.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || $0.profileTitle.range(of: normalized, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    public func open(kind: Kind, identifier: String) async throws -> UISceneAcknowledgement {
        guard !identifier.isEmpty, identifier.utf8.count <= 1024 else {
            throw UIRouteError(.notSupported, "native_workspace_selection_identity_not_supported")
        }
        let current = try catalog().filter { $0.kind == kind && $0.id == identifier }
        guard current.count == 1, let target = current.first else {
            throw UIRouteError(.staleState, "native_workspace_selection_not_available")
        }
        let requestID = UUID()
        let result = try await navigate(target, requestID)
        do { try Task.checkCancellation() }
        catch {
            if case .acknowledged(let receipt) = result { throw Failure(receipt: receipt, code: "native_effect_uncertain") }
            throw error
        }
        if case .acknowledged(let receipt) = result {
            let route = receipt.route
            guard route.version == 1, receipt.requestId == requestID, route.requestId == requestID,
                  route.destination == Self.destination, route.backend == target.backend,
                  route.content == nil, route.focus == nil, route.expectedBackendSnapshot == receipt.backendSnapshot,
                  route.presentation == .init(kind: .currentTab, tabID: target.activeDocumentID.flatMap { UIStableID(rawValue: $0.uuidString) }),
                  route.state == .init(workspaceID: UIStableID(rawValue: target.groupID.uuidString),
                                       profileID: UIStableID(rawValue: target.profileID.uuidString)),
                  route.scene.kind == .specific, route.scene.sceneID == target.sceneID, receipt.sceneID == target.sceneID,
                  receipt.backendSnapshot.backend == target.backend,
                  receipt.appliedSceneRevision > receipt.basedOnSceneRevision, receipt.coreReceipt == nil else {
                throw Failure(receipt: receipt, code: "native_workspace_selection_receipt_mismatch")
            }
        }
        return result
    }
}
