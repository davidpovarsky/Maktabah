import Foundation

public enum ActionWireCodec {
    public static let maxRequestBytes = 65_536
    public static func decodeRequest(_ data: Data) throws -> ActionRequest {
        guard data.count <= maxRequestBytes else { throw ActionContractError.inputTooLarge }
        var parser = StrictActionJSONParser(bytes: Array(data))
        let value = try parser.parse()
        try ActionSchemaValidator.validate(value, schema: ActionRegistry.schema("action-request.v1.schema.json"))
        // Preserve arguments from this EXACT tree. Re-encoding an approximate
        // .number(1) and decoding again could erase its fractional-token origin
        // before the descriptor checks offset/limit/position integer semantics.
        guard let fields = value.object, let id = fields["requestId"]?.string.flatMap(UUID.init(uuidString:)),
              let action = fields["action"]?.string, let arguments = fields["arguments"]?.object else {
            throw ActionContractError.invalid("$")
        }
        return ActionRequest(requestId: id, action: action, arguments: arguments,
            expectedBackend: fields["expectedBackend"]?.string.flatMap(ActionBackendID.init(rawValue:)),
            expectedGeneration: fields["expectedGeneration"]?.unsignedInteger,
            idempotencyKey: fields["idempotencyKey"]?.string,
            requestedPresentation: fields["requestedPresentation"]?.string.flatMap(ActionPresentation.init(rawValue:)),
            deadlineMs: fields["deadlineMs"]?.integer.map(Int.init))
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
            return try exactNumber(Array(bytes[start..<index]))
        }
    }
    private func exactNumber(_ token: [UInt8]) throws -> ActionJSON {
        // Classify decimal tokens mathematically BEFORE any Foundation/Double
        // coercion. Int64 decoding can otherwise round long fractional tokens.
        guard !token.isEmpty, token.count <= 512 else { throw ActionContractError.invalid("$") }
        var i = 0
        let negative = token[0] == 45
        if negative { i += 1 }
        func digit(_ i: Int) -> Bool { i < token.count && (48...57).contains(token[i]) }
        let intStart = i
        guard digit(i) else { throw ActionContractError.invalid("$") }
        if token[i] == 48 { i += 1 } else { while digit(i) { i += 1 } }
        var digits = Array(token[intStart..<i])
        var fractionCount = 0
        if i < token.count && token[i] == 46 {
            i += 1; let start = i
            while digit(i) { i += 1 }
            guard i > start else { throw ActionContractError.invalid("$") }
            fractionCount = i - start; digits += token[start..<i]
        }
        var exponentText = "0"
        if i < token.count && (token[i] == 101 || token[i] == 69) {
            i += 1; let start = i
            if i < token.count && (token[i] == 43 || token[i] == 45) { i += 1 }
            let firstDigit = i
            while digit(i) { i += 1 }
            guard i > firstDigit else { throw ActionContractError.invalid("$") }
            exponentText = String(decoding: token[start..<i], as: UTF8.self)
        }
        guard i == token.count else { throw ActionContractError.invalid("$") }
        guard let significant = digits.firstIndex(where: { $0 != 48 }) else { return .integer(0) }
        digits = Array(digits[significant...])
        guard let exponent = Int(exponentText), (-10_000...10_000).contains(exponent) else { throw ActionContractError.invalid("$") }
        let scale = exponent - fractionCount
        if scale < 0 {
            let places = -scale
            if places > digits.count || !digits.suffix(places).allSatisfy({ $0 == 48 }) {
                guard let number = Double(String(decoding: token, as: UTF8.self)), number.isFinite, number != 0 else {
                    throw ActionContractError.invalid("$")
                }
                return .number(number) // NEVER accepted as an integer by schema.
            }
            digits.removeLast(places)
        } else {
            guard digits.count + scale <= 20 else { throw ActionContractError.invalid("$") }
            digits += Array(repeating: 48, count: scale)
        }
        let text = (negative ? "-" : "") + String(decoding: digits, as: UTF8.self)
        if let value = Int64(text) { return .integer(value) }
        if !negative, let value = UInt64(text) { return .unsigned(value) }
        throw ActionContractError.invalid("$")
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
