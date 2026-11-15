import Foundation
import OtzariaActionCore

public enum UIRouteCodec {
    public static let maxPrivateBytes = 32_768
    public static let maxPublicBytes = 4_096

    public static func decodePrivate(_ data: Data, registry: UIDestinationRegistry) throws -> UIDecodedRoute {
        guard data.count <= maxPrivateBytes else { throw UIRouteError(.failed, "route_too_large") }
        var fields: ActionObject
        do { fields = try ActionWireCodec.decodeObject(data) } catch { throw UIRouteError(.failed, "invalid_route_json") }
        guard let version = fields["version"]?.unsignedInteger, version <= 1 else { throw UIRouteError(.notSupported, "route_version_unsupported") }
        do { try ActionSchemaValidator.validate(.object(fields), schema: UIRouteSchemas.privateRoute(version: Int(version))) }
        catch { throw UIRouteError(.failed, "invalid_route_shape") }
        var migration: UIRouteMigration?
        if version == 0 {
            guard let from = fields["destination"]?.string.flatMap(UIDestinationID.init(rawValue:)),
                  let rule = registry.migrations.first(where: { $0.fromVersion == 0 && $0.from == from }) else { throw UIRouteError(.notSupported, "unknown_legacy_destination") }
            guard let to = rule.to else { throw UIRouteError(.notSupported, "removed_destination") }
            fields["version"] = .integer(1); fields["destination"] = .string(to.rawValue); migration = rule
        }
        let route: RouteSpec
        do { route = try ActionJSON.object(fields).decoded(as: RouteSpec.self) }
        catch { throw UIRouteError(.failed, "invalid_route_values") }
        return UIDecodedRoute(route: try registry.validate(route), migration: migration)
    }
    public static func encodePrivate(_ route: RouteSpec, registry: UIDestinationRegistry) throws -> Data {
        let value = try registry.validate(route)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value.route)
        guard data.count <= maxPrivateBytes else { throw UIRouteError(.failed, "route_too_large") }
        return data
    }

    /// Parsing this public shape grants no permission/shareability. Actual URL
    /// routing/publishing and host data-rights approval are intentionally absent.
    public static func decodePublic(_ data: Data, registry: UIDestinationRegistry) throws -> PublicRouteSpec {
        guard data.count <= maxPublicBytes else { throw UIRouteError(.failed, "public_route_too_large") }
        let fields: ActionObject
        do { fields = try ActionWireCodec.decodeObject(data); try ActionSchemaValidator.validate(.object(fields), schema: UIRouteSchemas.publicRoute()) }
        catch { throw UIRouteError(.failed, "invalid_public_route") }
        let route: PublicRouteSpec
        do { route = try ActionJSON.object(fields).decoded(as: PublicRouteSpec.self) }
        catch { throw UIRouteError(.failed, "invalid_public_reference") }
        guard let descriptor = registry.descriptor(for: route.destination), descriptor.allowsPublicRoute,
              !descriptor.mutatesUserData, descriptor.riskTier < 3 else { throw UIRouteError(.notSupported, "public_route_not_supported") }
        try validatePublicReferences(route.content)
        let privateShape = RouteSpec(requestId: route.requestId, destination: route.destination, backend: route.backend, content: route.content,
            presentation: PresentationSpec(kind: route.presentation == .newTab ? .newTab : .currentTab))
        let validated = try registry.validate(privateShape)
        return PublicRouteSpec(version: route.version, requestId: route.requestId, destination: route.destination,
                               backend: validated.route.backend, content: route.content, presentation: route.presentation)
    }
    static func validatePublicReferences(_ content: ActionReaderDestination?) throws {
        for ref in [content?.sectionLocator, content?.focusLocator].compactMap({ $0 }) {
            let key = ref.workKey
            guard !key.contains("/"), !key.contains("\\"), !key.contains("?"), !key.contains("#"),
                  !key.contains("\0"), !key.lowercased().hasPrefix("file:"), !key.lowercased().hasPrefix("http:") else { throw UIRouteError(.failed, "private_path_not_public") }
        }
    }
    /// Explicit public input only; never projects private restoration state.
    /// The host must separately approve content rights and URL publishing.
    public static func encodePublic(_ route: PublicRouteSpec, registry: UIDestinationRegistry) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let validated = try decodePublic(encoder.encode(route), registry: registry)
        let data = try encoder.encode(validated)
        guard data.count <= maxPublicBytes else { throw UIRouteError(.failed, "public_route_too_large") }
        return data
    }
}
