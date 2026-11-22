public enum OSLogPrivacy { case `public` }
public struct Logger: Sendable {
    public init(subsystem: String, category: String) {}
    public func debug(_ message: OSLogMessage) {}
}
public struct OSLogMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: StringInterpolation) {}
    public struct StringInterpolation: StringInterpolationProtocol {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation<T>(_ value: T) {}
        public mutating func appendInterpolation<T>(_ value: T, privacy: OSLogPrivacy) {}
    }
}
