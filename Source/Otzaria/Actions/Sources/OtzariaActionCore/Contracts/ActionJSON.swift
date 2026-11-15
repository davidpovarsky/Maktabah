import Foundation

public typealias ActionObject = [String: ActionJSON]

/// An integer is never a Bool or a floating-point approximation.
public enum ActionJSON: Sendable, Hashable, Codable {
    case object(ActionObject), array([ActionJSON]), string(String), integer(Int64), unsigned(UInt64), number(Double), bool(Bool), null

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(UInt64.self) { self = .unsigned(v) }
        else if let v = try? c.decode(Double.self), v.isFinite { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([ActionJSON].self) { self = .array(v) }
        else { self = .object(try c.decode(ActionObject.self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .unsigned(let v): try c.encode(v)
        case .number(let v):
            guard v.isFinite else { throw ActionContractError.invalid("$") }
            try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    public var object: ActionObject? { if case .object(let v) = self { v } else { nil } }
    public var array: [ActionJSON]? { if case .array(let v) = self { v } else { nil } }
    public var string: String? { if case .string(let v) = self { v } else { nil } }
    public var integer: Int64? { if case .integer(let v) = self { v } else { nil } }
    public var unsignedInteger: UInt64? {
        switch self { case .unsigned(let v): v; case .integer(let v) where v >= 0: UInt64(v); default: nil }
    }
    public var boolean: Bool? { if case .bool(let v) = self { v } else { nil } }

    public static func encoded<T: Encodable>(_ value: T) throws -> ActionJSON {
        try JSONDecoder().decode(Self.self, from: JSONEncoder().encode(value))
    }
    public func decoded<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
    }
}

public enum ActionContractError: Error, Sendable, Equatable {
    case invalid(String)
    case inputTooLarge
    case duplicateKey
}
