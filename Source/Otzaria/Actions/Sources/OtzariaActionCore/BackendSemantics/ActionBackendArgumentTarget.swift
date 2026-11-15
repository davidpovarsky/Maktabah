import Foundation

/// Adapter boundary check only. Authorization/descriptor validation stay in the
/// shared executor; a state probe must not inspect the wrong active source.
public enum ActionBackendArgumentTarget {
    public static func resolve(_ arguments: ActionObject, fallback: ActionBackendID) throws -> ActionBackendID {
        var sources: [ActionBackendID] = []
        func add(_ value: ActionJSON?) throws {
            guard let value else { return }
            guard let raw = value.string, let backend = ActionBackendID(rawValue: raw) else {
                throw ActionContractError.invalid("backend")
            }
            sources.append(backend)
        }
        try add(arguments["backend"])
        for key in ["workRef", "sectionLocator", "focusLocator", "sourceLocator", "locator"] {
            if let value = arguments[key] {
                guard let ref = value.object, ref["backend"] != nil else { throw ActionContractError.invalid(key) }
                try add(ref["backend"])
            }
        }
        if let value = arguments["scopeWorkRefs"] {
            guard let refs = value.array, refs.count <= 200 else { throw ActionContractError.invalid("scopeWorkRefs") }
            for value in refs {
                guard let ref = value.object, ref["backend"] != nil else { throw ActionContractError.invalid("scopeWorkRefs") }
                try add(ref["backend"])
            }
        }
        let target = sources.first ?? fallback
        guard sources.allSatisfy({ $0 == target }) else { throw ActionContractError.invalid("backend") }
        return target
    }
}
