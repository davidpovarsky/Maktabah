import Foundation

/// Typed projection of already schema-validated arguments. This is not another
/// action executor, registry or permissive general-purpose JSON decoder.
public enum ActionSearchArgumentMapping {
    public static func query(_ arguments: ActionObject, backend: ActionBackendID) throws -> ActionSearchQuery {
        guard let text = arguments["text"]?.string else { throw ActionContractError.invalid("text") }
        func integer(_ key: String, fallback: Int) throws -> Int {
            guard let value = arguments[key] else { return fallback }
            guard let integer = value.integer, let exact = Int(exactly: integer) else { throw ActionContractError.invalid(key) }
            return exact
        }
        func choice<T: RawRepresentable>(_ key: String, fallback: T) throws -> T where T.RawValue == String {
            guard let value = arguments[key] else { return fallback }
            guard let string = value.string, let result = T(rawValue: string) else { throw ActionContractError.invalid(key) }
            return result
        }
        let scope: [ActionWorkRef]
        if let value = arguments["scopeWorkRefs"] { scope = try value.decoded(as: [ActionWorkRef].self) }
        else { scope = [] }
        let result = try ActionSearchQuery(backend: backend, text: text, scopeWorkRefs: scope,
            searchMode: choice("searchMode", fallback: .phrase), matchMode: choice("matchMode", fallback: .exact),
            wordDistance: integer("wordDistance", fallback: 0), sortOrder: choice("sortOrder", fallback: .relevance),
            offset: integer("offset", fallback: 0), limit: integer("limit", fallback: 20))
        try ActionSearchSemantics.validateBounds(result)
        return result
    }
}
