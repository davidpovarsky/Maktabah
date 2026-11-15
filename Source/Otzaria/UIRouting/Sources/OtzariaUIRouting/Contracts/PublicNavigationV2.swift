import Foundation
import OtzariaActionCore

/// Public read/navigation intent, NOT a private RouteSpec or an authority.
/// No request/session/scene/tab/restoration ID is imported. The native host
/// issues fresh correlation and binds actual local state at execution.
public struct PublicNavigationSpecV2: Codable, Sendable, Equatable {
    public enum Presentation: String, Codable, Sendable, CaseIterable {
        case currentTab, newTab, sheet, inspector
        var nativeKind: PresentationSpec.Kind {
            switch self {
            case .currentTab: .currentTab
            case .newTab: .newTab
            case .sheet: .sheet
            case .inspector: .inspector
            }
        }
    }
    public let version: Int
    public let destination: UIDestinationID
    public let backend: ActionBackendID?
    public let content: ActionReaderDestination?
    public let presentation: Presentation
    public let component: UIDestinationID?
    public init(version: Int = 2, destination: UIDestinationID, backend: ActionBackendID? = nil,
                content: ActionReaderDestination? = nil, presentation: Presentation = .currentTab,
                component: UIDestinationID? = nil) {
        self.version = version; self.destination = destination; self.backend = backend
        self.content = content; self.presentation = presentation; self.component = component
    }
}

/// Trusted registration-time allowlist, distinct from live host availability.
/// Opting in does not change the existing v1 allowsPublicRoute flag.
public struct UIPublicNavigationPolicyV2: Codable, Sendable, Equatable {
    public struct Rule: Codable, Sendable, Equatable {
        public let presentation: PublicNavigationSpecV2.Presentation
        public let allowsRoot: Bool
        public let components: [UIDestinationID]
        public init(presentation: PublicNavigationSpecV2.Presentation, allowsRoot: Bool = true, components: [UIDestinationID] = []) {
            self.presentation = presentation; self.allowsRoot = allowsRoot; self.components = components
        }
    }
    public let rules: [Rule]
    public init(rules: [Rule]) { self.rules = rules }
}

/// Live discovery result for ONE host-verified static variant, not a grant.
public struct UIPublicNavigationVariantV2: Sendable, Equatable {
    public let destination: UIDestinationID
    public let presentation: PublicNavigationSpecV2.Presentation
    public let component: UIDestinationID?
    public let requiresContent: Bool
    public init(destination: UIDestinationID, presentation: PublicNavigationSpecV2.Presentation,
                component: UIDestinationID? = nil, requiresContent: Bool) {
        self.destination = destination; self.presentation = presentation; self.component = component; self.requiresContent = requiresContent
    }
}

/// Mandatory exact-variant host checks. There is no default broad-descriptor
/// fallback. Navigation checks actual content/shareability/rights as well as
/// installed native presentation/component support and local lifetime.
public protocol UIPublicNavigationEligibilityPort: UIDestinationEligibilityPort {
    func assessPublicVariant(_ variant: UIPublicNavigationVariantV2, scene: UISceneSnapshot,
                             context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility
    func assessPublicNavigation(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot,
                                context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility
}

/// Non-Codable local plan: content still MUST execute canonical reader.open.
/// The surface case holds Core-issued one-use navigation authorization. Neither
/// decoding nor a discovery result constructs a plan or a native receipt.
public enum UIPublicNavigationPlanV2: Sendable {
    case surface(UIAuthorizedSceneCommand)
    // At the canonical sink, construct UISceneCommand with Core's actual reader
    // invocation/deadline and a fresh local scene. Retained route expectations
    // still reject a changed scene/backend; never reuse an import-stage deadline
    // as if it were the independently issued Core reader invocation.
    case reader(UIValidatedRoute)
}
