import Foundation
import OtzariaActionCore

public struct UIDestinationID: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String
    public init?(rawValue: String) {
        guard rawValue.utf8.count <= 128, rawValue.range(of: "^[a-z][A-Za-z0-9_-]*(\\.[a-z][A-Za-z0-9_-]*){1,7}$", options: .regularExpression) != nil else { return nil }
        self.rawValue = rawValue
    }
    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let id = Self(rawValue: value) else { throw UIRouteError(.failed, "invalid_destination_id") }
        self = id
    }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

/// Opaque existing scene/tab/workspace/profile/item identity. Never a selector,
/// file path, JS method or permission. The host verifies existence and access.
public struct UIStableID: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String
    public init?(rawValue: String) {
        guard rawValue.utf8.count <= 128, rawValue.range(of: "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$", options: .regularExpression) != nil else { return nil }
        self.rawValue = rawValue
    }
    public init(from decoder: any Decoder) throws {
        guard let id = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) else { throw UIRouteError(.failed, "invalid_stable_id") }
        self = id
    }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

public struct PresentationSpec: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable { case currentTab, newTab, newWindow, sheet, popover, inspector, sidebar }
    public let kind: Kind
    public let tabID: UIStableID?
    public init(kind: Kind = .currentTab, tabID: UIStableID? = nil) { self.kind = kind; self.tabID = tabID }
}
public struct SceneTarget: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case current, specific, newWindow }
    public let kind: Kind
    public let sceneID: UIStableID?
    public let expectedRevision: UInt64?
    public init(kind: Kind = .current, sceneID: UIStableID? = nil, expectedRevision: UInt64? = nil) {
        self.kind = kind; self.sceneID = sceneID; self.expectedRevision = expectedRevision
    }
}
public struct UIUTF16Range: Codable, Sendable, Equatable {
    public let location: UInt64
    public let length: UInt64
    public init(location: UInt64, length: UInt64) { self.location = location; self.length = length }
}
public struct FocusSpec: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case content, component, selection }
    public let kind: Kind
    public let locator: ActionTextRef?
    public let anchor: UIDestinationID?
    public let range: UIUTF16Range?
    public init(kind: Kind, locator: ActionTextRef? = nil, anchor: UIDestinationID? = nil, range: UIUTF16Range? = nil) {
        self.kind = kind; self.locator = locator; self.anchor = anchor; self.range = range
    }
}

public struct UIPrivateState: Codable, Sendable, Equatable {
    public let search: ActionSearchQuery?
    public let draftNote: String?
    public let selectedText: String?
    public init(search: ActionSearchQuery? = nil, draftNote: String? = nil, selectedText: String? = nil) {
        self.search = search; self.draftNote = draftNote; self.selectedText = selectedText
    }
}
public struct UIStateSpec: Codable, Sendable, Equatable {
    public let version: Int
    public let workspaceID: UIStableID?
    public let profileID: UIStableID?
    public let selectedItemID: UIStableID?
    public let visibleComponents: [UIDestinationID]
    public let expandedComponents: [UIDestinationID]
    public let sidebarVisible: Bool?
    public let inspectorVisible: Bool?
    public let sheet: UIDestinationID?
    public let scrollAnchor: ActionTextRef?
    public let privateState: UIPrivateState?
    public init(version: Int = 1, workspaceID: UIStableID? = nil, profileID: UIStableID? = nil, selectedItemID: UIStableID? = nil,
                visibleComponents: [UIDestinationID] = [], expandedComponents: [UIDestinationID] = [], sidebarVisible: Bool? = nil,
                inspectorVisible: Bool? = nil, sheet: UIDestinationID? = nil, scrollAnchor: ActionTextRef? = nil, privateState: UIPrivateState? = nil) {
        self.version = version; self.workspaceID = workspaceID; self.profileID = profileID; self.selectedItemID = selectedItemID
        self.visibleComponents = visibleComponents; self.expandedComponents = expandedComponents; self.sidebarVisible = sidebarVisible
        self.inspectorVisible = inspectorVisible; self.sheet = sheet; self.scrollAnchor = scrollAnchor; self.privateState = privateState
    }
}
public struct RouteSpec: Codable, Sendable, Equatable {
    public let version: Int
    public let requestId: UUID
    public let destination: UIDestinationID
    public let backend: ActionBackendID?
    public let content: ActionReaderDestination?
    public let presentation: PresentationSpec
    public let state: UIStateSpec
    public let focus: FocusSpec?
    public let scene: SceneTarget
    public let expectedBackendSnapshot: ActionBackendSnapshot?
    public init(version: Int = 1, requestId: UUID = UUID(), destination: UIDestinationID, backend: ActionBackendID? = nil,
                content: ActionReaderDestination? = nil, presentation: PresentationSpec = .init(), state: UIStateSpec = .init(),
                focus: FocusSpec? = nil, scene: SceneTarget = .init(), expectedBackendSnapshot: ActionBackendSnapshot? = nil) {
        self.version = version; self.requestId = requestId; self.destination = destination; self.backend = backend; self.content = content
        self.presentation = presentation; self.state = state; self.focus = focus; self.scene = scene; self.expectedBackendSnapshot = expectedBackendSnapshot
    }
}

/// A deliberately separate navigation-only wire form. No automatic projection
/// from private RouteSpec exists. Host approval of shareability is still required.
public struct PublicRouteSpec: Codable, Sendable, Equatable {
    public enum Presentation: String, Codable, Sendable { case currentTab, newTab }
    public let version: Int
    public let requestId: UUID
    public let destination: UIDestinationID
    public let backend: ActionBackendID?
    public let content: ActionReaderDestination?
    public let presentation: Presentation
    public init(version: Int = 1, requestId: UUID = UUID(), destination: UIDestinationID, backend: ActionBackendID? = nil,
                content: ActionReaderDestination? = nil, presentation: Presentation = .currentTab) {
        self.version = version; self.requestId = requestId; self.destination = destination; self.backend = backend; self.content = content; self.presentation = presentation
    }
}
public struct UIRouteError: Error, Sendable, Equatable {
    public let status: ActionStatus
    public let code: String
    public init(_ status: ActionStatus, _ code: String) { self.status = status; self.code = code }
}
