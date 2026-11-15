import Foundation
import OtzariaActionCore

extension UIRouteCodec {
    /// Explicit v2 only. Never falls back to v1/private/legacy decoding.
    public static func decodePublicV2(_ data: Data, registry: UIDestinationRegistry) throws -> PublicNavigationSpecV2 {
        guard data.count <= maxPublicBytes else { throw UIRouteError(.failed, "public_route_too_large") }
        let fields: ActionObject
        do { fields = try ActionWireCodec.decodeObject(data) }
        catch { throw UIRouteError(.failed, "invalid_public_route") }
        guard fields["version"]?.unsignedInteger == 2 else { throw UIRouteError(.notSupported, "public_route_version_unsupported") }
        do { try ActionSchemaValidator.validate(.object(fields), schema: UIRouteSchemas.publicNavigationV2()) }
        catch { throw UIRouteError(.failed, "invalid_public_route") }
        let intent: PublicNavigationSpecV2
        do { intent = try ActionJSON.object(fields).decoded(as: PublicNavigationSpecV2.self) }
        catch { throw UIRouteError(.failed, "invalid_public_reference") }
        try validatePublicReferences(intent.content)
        // v2 adds no paths/URI schemes through a canonical-reference string.
        // This stricter public filter does not alter frozen v1 acceptance.
        for ref in [intent.content?.sectionLocator, intent.content?.focusLocator].compactMap({ $0 }) {
            var tokens = [ref.workKey]
            if case .canonicalRef(let value) = ref.position { tokens.append(value) }
            for token in tokens {
                let lower = token.lowercased()
                guard !token.contains("/"), !token.contains("\\"), !token.contains("?"), !token.contains("#"),
                      token.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value != 0x2028 && $0.value != 0x2029 }),
                      token.range(of: "^[A-Za-z]:", options: .regularExpression) == nil,
                      !["file:", "http:", "https:", "javascript:", "data:", "mailto:", "ftp:"].contains(where: lower.hasPrefix) else {
                    throw UIRouteError(.failed, "private_path_not_public")
                }
            }
        }
        return try registry.validatePublicNavigationV2(intent)
    }

    /// An explicit public DTO only, never a projection of private route state.
    public static func encodePublicV2(_ intent: PublicNavigationSpecV2, registry: UIDestinationRegistry) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(decodePublicV2(encoder.encode(intent), registry: registry))
        guard data.count <= maxPublicBytes else { throw UIRouteError(.failed, "public_route_too_large") }
        return data
    }

    /// Explicit opt-in migration. v1 stays unchanged and independently valid.
    /// v2 drops the imported v1 request UUID; native correlation is freshly issued.
    public static func migratePublicV1ToV2(_ data: Data, registry: UIDestinationRegistry) throws -> PublicNavigationSpecV2 {
        let old = try decodePublic(data, registry: registry)
        let intent = PublicNavigationSpecV2(destination: old.destination, backend: old.backend, content: old.content,
            presentation: old.presentation == .newTab ? .newTab : .currentTab)
        return try decodePublicV2(encodePublicV2(intent, registry: registry), registry: registry)
    }
}
