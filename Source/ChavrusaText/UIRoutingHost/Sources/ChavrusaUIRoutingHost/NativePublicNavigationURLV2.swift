import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// An explicitly versioned public envelope. The original Core/UI Registry
/// codec owns all JSON, reference and static-variant validation. No fallback
/// to v1 or private restoration; no imported local identity or grant.
public enum NativePublicNavigationURLV2 {
    public static func decode(_ url: URL, scheme: String = "maktabah", registry: UIDestinationRegistry) throws -> PublicNavigationSpecV2 {
        guard ["maktabah", "maktabah-debug"].contains(scheme),
              url.absoluteString.utf8.count <= NativeRouteURL.maximumURLBytes,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme == scheme, c.host == "action", c.user == nil, c.password == nil,
              c.port == nil, c.fragment == nil else { throw UIRouteError(.failed, "invalid_route_url") }
        let path = c.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard path.count == 3, path[0].isEmpty, path[1] == "v2" else { throw UIRouteError(.notSupported, "url_version_unsupported") }
        guard let id = UIDestinationID(rawValue: String(path[2])),
              let items = c.queryItems, items.count == 1, items[0].name == "route",
              let token = items[0].value, !token.isEmpty,
              token.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }),
              c.percentEncodedQuery == "route=" + token else { throw UIRouteError(.failed, "invalid_route_url") }
        var base64 = token.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let bytes = Data(base64Encoded: base64), encodeToken(bytes) == token else { throw UIRouteError(.failed, "invalid_route_encoding") }
        let intent = try UIRouteCodec.decodePublicV2(bytes, registry: registry)
        guard intent.destination == id else { throw UIRouteError(.failed, "conflicting_url_destination") }
        return intent
    }

    public static func encode(_ intent: PublicNavigationSpecV2, scheme: String = "maktabah", registry: UIDestinationRegistry) throws -> URL {
        guard ["maktabah", "maktabah-debug"].contains(scheme) else { throw UIRouteError(.notSupported, "native_url_scheme_required") }
        let data = try UIRouteCodec.encodePublicV2(intent, registry: registry)
        var c = URLComponents()
        c.scheme = scheme; c.host = "action"; c.path = "/v2/" + intent.destination.rawValue
        c.queryItems = [URLQueryItem(name: "route", value: encodeToken(data))]
        guard let url = c.url, url.absoluteString.utf8.count <= NativeRouteURL.maximumURLBytes else { throw UIRouteError(.failed, "route_url_too_large") }
        return url
    }

    private static func encodeToken(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
