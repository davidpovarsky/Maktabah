import Foundation
import OtzariaActionCore

public struct UIDestinationDescriptor: Codable, Sendable, Equatable {
    public enum Implementation: String, Codable, Sendable { case inventoryOnly, fixture, implemented }
    public let id: UIDestinationID
    public let title: String
    public let implementation: Implementation
    public let supportedBackends: [ActionBackendID]
    public let presentations: [PresentationSpec.Kind]
    public let anchors: [UIDestinationID]
    public let requiredCoreActions: [String]
    public let riskTier: Int
    public let mutatesUserData: Bool
    public let requiresContent: Bool
    public let allowsPrivateState: Bool
    public let allowsPublicRoute: Bool
    public let publicNavigationV2: UIPublicNavigationPolicyV2?
    public init(id: UIDestinationID, title: String, implementation: Implementation, supportedBackends: [ActionBackendID],
                presentations: [PresentationSpec.Kind], anchors: [UIDestinationID] = [], requiredCoreActions: [String] = [], riskTier: Int = 2,
                mutatesUserData: Bool = false, requiresContent: Bool = false, allowsPrivateState: Bool = false, allowsPublicRoute: Bool = false,
                publicNavigationV2: UIPublicNavigationPolicyV2? = nil) {
        self.id = id; self.title = title; self.implementation = implementation; self.supportedBackends = supportedBackends
        self.presentations = presentations; self.anchors = anchors; self.requiredCoreActions = requiredCoreActions; self.riskTier = riskTier
        self.mutatesUserData = mutatesUserData; self.requiresContent = requiresContent; self.allowsPrivateState = allowsPrivateState; self.allowsPublicRoute = allowsPublicRoute
        self.publicNavigationV2 = publicNavigationV2
    }
    /// Generic discovery has not assessed public-v2 combinations. Do not return
    /// the opt-in rules there as if all variants had passed live host checks.
    func withoutPublicNavigationV2() -> Self {
        guard publicNavigationV2 != nil else { return self }
        return .init(id: id, title: title, implementation: implementation, supportedBackends: supportedBackends,
            presentations: presentations, anchors: anchors, requiredCoreActions: requiredCoreActions, riskTier: riskTier,
            mutatesUserData: mutatesUserData, requiresContent: requiresContent, allowsPrivateState: allowsPrivateState,
            allowsPublicRoute: allowsPublicRoute)
    }
}
public struct UIRouteMigration: Codable, Sendable, Equatable {
    public let fromVersion: Int
    public let from: UIDestinationID
    public let to: UIDestinationID?
    public init(fromVersion: Int, from: UIDestinationID, to: UIDestinationID?) { self.fromVersion = fromVersion; self.from = from; self.to = to }
}
public struct UIDecodedRoute: Sendable, Equatable {
    public let route: UIValidatedRoute
    public let migration: UIRouteMigration?
    public init(route: UIValidatedRoute, migration: UIRouteMigration? = nil) { self.route = route; self.migration = migration }
}
