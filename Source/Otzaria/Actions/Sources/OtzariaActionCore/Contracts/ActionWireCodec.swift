import Foundation

public enum ActionWireCodec {
    public static let maxRequestBytes = 65_536
    public static func decodeRequest(_ data: Data) throws -> ActionRequest {
        guard data.count <= maxRequestBytes else { throw ActionContractError.inputTooLarge }
        var parser = StrictActionJSONParser(bytes: Array(data))
        let value = try parser.parse()
        try ActionSchemaValidator.validate(value, schema: ActionRegistry.schema("action-request.v1.schema.json"))
        // There is only one parsed/validated value; JSONDecoder never sees the
        // original ambiguous bytes. It decodes this canonical, duplicate-free tree.
        return try value.decoded(as: ActionRequest.self)
    }
    public static func encodeResult(_ result: ActionResult) throws -> Data {
        let value = try ActionJSON.encoded(result)
        try ActionSchemaValidator.validate(value, schema: ActionRegistry.schema("action-result.v1.schema.json"))
        return try JSONEncoder().encode(value)
    }
}

/// Small bounded JSON grammar. Decoded string keys are checked for duplicates,
/// including escaped-equivalent spellings; Foundation handles string Unicode.
private struct StrictActionJSONParser {
    let bytes: [UInt8]
    var index = 0
    var nodes = 0
    mutating func parse() throws -> ActionJSON {
        let result = try value(depth: 0)
        whitespace()
        guard index == bytes.count else { throw ActionContractError.invalid("$") }
        return result
    }
    mutating func value(depth: Int) throws -> ActionJSON {
        nodes += 1
        guard depth <= 16, nodes <= 10_000 else { throw ActionContractError.inputTooLarge }
        whitespace()
        guard index < bytes.count else { throw ActionContractError.invalid("$") }
        switch bytes[index] {
        case 123:
            index += 1; whitespace()
            var object: ActionObject = [:]
            if take(125) { return .object(object) }
            while true {
                whitespace(); let key = try string()
                guard object[key] == nil else { throw ActionContractError.duplicateKey }
                whitespace(); guard take(58) else { throw ActionContractError.invalid("$") }
                object[key] = try value(depth: depth + 1)
                whitespace()
                if take(125) { return .object(object) }
                guard take(44) else { throw ActionContractError.invalid("$") }
            }
        case 91:
            index += 1; whitespace(); var array: [ActionJSON] = []
            if take(93) { return .array(array) }
            while true {
                array.append(try value(depth: depth + 1)); whitespace()
                if take(93) { return .array(array) }
                guard take(44) else { throw ActionContractError.invalid("$") }
            }
        case 34: return .string(try string())
        case 116: try literal("true"); return .bool(true)
        case 102: try literal("false"); return .bool(false)
        case 110: try literal("null"); return .null
        default:
            let start = index
            while index < bytes.count, ![UInt8(32), 9, 10, 13, 44, 93, 125].contains(bytes[index]) { index += 1 }
            let token = Data(bytes[start..<index])
            // Foundation validates the complete numeric grammar (no NaN, +1,
            // leading zero, hex or trailing garbage). Bool/string are not numbers.
            let number = try JSONDecoder().decode(ActionJSON.self, from: token)
            switch number {
            case .integer, .unsigned, .number: return number
            default: throw ActionContractError.invalid("$")
            }
        }
    }
    mutating func string() throws -> String {
        guard take(34) else { throw ActionContractError.invalid("$") }
        let start = index - 1
        var escaped = false
        while index < bytes.count {
            let byte = bytes[index]; index += 1
            if byte == 34 && !escaped { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index])) }
            if byte == 92 && !escaped { escaped = true } else { escaped = false }
        }
        throw ActionContractError.invalid("$")
    }
    mutating func literal(_ string: String) throws {
        let token = Array(string.utf8)
        guard index + token.count <= bytes.count, Array(bytes[index..<index + token.count]) == token else { throw ActionContractError.invalid("$") }
        index += token.count
    }
    mutating func whitespace() { while index < bytes.count && [UInt8(32), 9, 10, 13].contains(bytes[index]) { index += 1 } }
    mutating func take(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1; return true
    }
}
