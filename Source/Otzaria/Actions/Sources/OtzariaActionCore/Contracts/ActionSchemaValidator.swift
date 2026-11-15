import Foundation

/// Implements only the JSON Schema keywords present in the frozen resources.
/// Semantic identity/rights and operation support are separate mandatory gates.
public enum ActionSchemaValidator {
    public static func validate(_ value: ActionJSON, schema: ActionJSON, path: String = "$") throws {
        guard let s = schema.object else { throw ActionContractError.invalid("schema") }
        func reject() throws -> Never { throw ActionContractError.invalid(path) }
        if let constant = s["const"], value != constant { try reject() }
        if let values = s["enum"]?.array, !values.contains(value) { try reject() }
        if let t = s["type"] {
            let types = t.array?.compactMap(\.string) ?? t.string.map { [$0] } ?? []
            if !types.contains(where: { matches(value, type: $0) }) { try reject() }
        }
        for key in ["oneOf", "anyOf", "allOf"] {
            guard let branches = s[key]?.array else { continue }
            let count = branches.filter { (try? validate(value, schema: $0, path: path)) != nil }.count
            if (key == "oneOf" && count != 1) || (key == "anyOf" && count == 0) || (key == "allOf" && count != branches.count) { try reject() }
        }
        if let condition = s["if"], (try? validate(value, schema: condition, path: path)) != nil, let then = s["then"] {
            try validate(value, schema: then, path: path)
        }
        switch value {
        case .object(let object):
            let properties = s["properties"]?.object ?? [:]
            let required = s["required"]?.array?.compactMap(\.string) ?? []
            if required.contains(where: { object[$0] == nil }) { try reject() }
            if s["additionalProperties"] == .bool(false), !Set(object.keys).isSubset(of: Set(properties.keys)) { try reject() }
            if let max = s["maxProperties"]?.integer, object.count > max { try reject() }
            for (key, rule) in properties { if let v = object[key] { try validate(v, schema: rule, path: path + "." + key) } }
        case .array(let array):
            if let min = s["minItems"]?.integer, array.count < min { try reject() }
            if let max = s["maxItems"]?.integer, array.count > max { try reject() }
            if s["uniqueItems"] == .bool(true), Set(array).count != array.count { try reject() }
            if let item = s["items"] { for (i, v) in array.enumerated() { try validate(v, schema: item, path: "\(path)[\(i)]") } }
        case .string(let string):
            let length = string.unicodeScalars.count
            if let min = s["minLength"]?.integer, length < min { try reject() }
            if let max = s["maxLength"]?.integer, length > max { try reject() }
            if let pattern = s["pattern"]?.string, string.range(of: pattern, options: .regularExpression) == nil { try reject() }
            if s["format"] == .string("uuid"), UUID(uuidString: string) == nil { try reject() }
            if s["format"] == .string("date-time"), ISO8601DateFormatter().date(from: string) == nil { try reject() }
        case .integer(let number):
            if let min = s["minimum"]?.integer, number < min { try reject() }
            if let max = s["maximum"]?.integer, number > max { try reject() }
        case .number(let number):
            guard number.isFinite else { try reject() }
            if let min = s["minimum"]?.integer, number < Double(min) { try reject() }
            if let max = s["maximum"]?.integer, number > Double(max) { try reject() }
        case .unsigned(let number):
            if let min = s["minimum"]?.integer, min >= 0, number < UInt64(min) { try reject() }
            if let max = s["maximum"]?.integer, max < 0 || number > UInt64(max) { try reject() }
        case .bool, .null: break
        }
    }
    private static func matches(_ value: ActionJSON, type: String) -> Bool {
        switch (type, value) {
        case ("object", .object), ("array", .array), ("string", .string), ("integer", .integer),
             ("integer", .unsigned), ("number", .unsigned), ("number", .integer), ("number", .number), ("boolean", .bool), ("null", .null): true
        case ("integer", .number(let v)): v.isFinite && v.rounded() == v
        default: false
        }
    }
}
