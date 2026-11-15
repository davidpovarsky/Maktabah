import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// URL envelope only. P's codec and Core's exact JSON/schema implementation
/// remain the sole route/reference parser. Private restoration is never a URL.
public enum NativeRouteURL {
    public enum Input: Sendable, Equatable {
        /// Pass this exact URL to the existing WidgetDeepLink handler once.
        case legacy(URL)
        case route(PublicRouteSpec)
    }

    public static let maximumURLBytes = 6_144

    public static func decode(_ url: URL, scheme: String = "maktabah", registry: UIDestinationRegistry) throws -> Input {
        guard ["maktabah", "maktabah-debug"].contains(scheme), url.absoluteString.utf8.count <= maximumURLBytes,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme == scheme, c.user == nil, c.password == nil,
              c.port == nil, c.fragment == nil else { throw UIRouteError(.failed, "invalid_route_url") }
        // Preserve the original numeric widget-link implementation and scheme.
        // The caller delegates; this module neither reparses nor handles it.
        if c.host == "history" || c.host == "annotation" { return .legacy(url) }
        guard c.host == "action" else { throw UIRouteError(.notSupported, "unknown_url_host") }
        let path = c.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard path.count == 3, path[0].isEmpty, path[1] == "v1" else {
            throw UIRouteError(.notSupported, "url_version_unsupported")
        }
        guard let id = UIDestinationID(rawValue: String(path[2])),
              let items = c.queryItems, items.count == 1, items[0].name == "route",
              let token = items[0].value, !token.isEmpty,
              token.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw UIRouteError(.failed, "invalid_route_url")
        }
        guard c.percentEncodedQuery == "route=" + token else { throw UIRouteError(.failed, "noncanonical_route_query") }
        // Base64url is transport encoding, not a place to recover lossy numbers.
        var base64 = token.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let bytes = Data(base64Encoded: base64), encodeToken(bytes) == token else {
            throw UIRouteError(.failed, "invalid_route_encoding")
        }
        let route = try UIRouteCodec.decodePublic(bytes, registry: registry)
        guard route.destination == id else { throw UIRouteError(.failed, "conflicting_url_destination") }
        return .route(route)
    }

    /// Caller must have approved shareability/content rights before publication.
    /// Explicit public input prevents accidental projection of private state.
    public static func encode(_ route: PublicRouteSpec, scheme: String = "maktabah", registry: UIDestinationRegistry) throws -> URL {
        guard ["maktabah", "maktabah-debug"].contains(scheme) else { throw UIRouteError(.notSupported, "native_url_scheme_required") }
        let data = try UIRouteCodec.encodePublic(route, registry: registry)
        var c = URLComponents()
        c.scheme = scheme; c.host = "action"; c.path = "/v1/" + route.destination.rawValue
        c.queryItems = [URLQueryItem(name: "route", value: encodeToken(data))]
        guard let url = c.url, url.absoluteString.utf8.count <= maximumURLBytes else { throw UIRouteError(.failed, "route_url_too_large") }
        return url
    }

    private static func encodeToken(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
