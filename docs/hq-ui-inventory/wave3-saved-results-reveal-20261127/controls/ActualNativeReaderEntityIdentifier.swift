import Foundation
import OtzariaUIRouting

enum NativeReaderEntityIdentifier {
    static func encode<T: Encodable>(_ value: T, prefix: String) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= 6_144 else { throw UIRouteError(.failed, "intent_entity_too_large") }
        return prefix + data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func decode<T: Codable>(_ value: String, prefix: String) throws -> T {
        guard value.hasPrefix(prefix), value.utf8.count <= 8_224 else { throw UIRouteError(.failed, "invalid_intent_entity") }
        let encoded = String(value.dropFirst(prefix.count))
        guard !encoded.isEmpty, encoded.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw UIRouteError(.failed, "invalid_intent_entity")
        }
        let padded = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: padded), data.count <= 6_144 else { throw UIRouteError(.failed, "invalid_intent_entity") }
        let decoded = try JSONDecoder().decode(T.self, from: data)
        guard try encode(decoded, prefix: prefix) == value else { throw UIRouteError(.failed, "noncanonical_intent_entity") }
        return decoded
    }
}
