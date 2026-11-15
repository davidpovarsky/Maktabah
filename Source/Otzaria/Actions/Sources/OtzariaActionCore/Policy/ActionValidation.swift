import Foundation

struct ValidatedAction: Sendable {
    let request: ActionRequest
    let descriptor: ActionDescriptor
    let explicitBackend: ActionBackendID?
}

enum ActionValidation {
    static func request(_ request: ActionRequest, registry: ActionRegistry) throws -> ValidatedAction {
        try bounded(.object(request.arguments))
        let wire = try ActionJSON.encoded(request)
        guard try JSONEncoder().encode(wire).count <= ActionWireCodec.maxRequestBytes else { throw ActionContractError.inputTooLarge }
        try ActionSchemaValidator.validate(wire, schema: ActionRegistry.schema("action-request.v1.schema.json"))
        guard let descriptor = registry.descriptor(for: request.action) else { throw ActionEngineFailure(.notSupported, "unknown_action") }
        try ActionSchemaValidator.validate(.object(request.arguments), schema: descriptor.argumentsSchema, path: "$.arguments")
        var backends = Set<ActionBackendID>()
        if let explicit = request.expectedBackend { backends.insert(explicit) }
        try collectBackends(.object(request.arguments), into: &backends)
        guard backends.count <= 1 else { throw ActionContractError.invalid("$.arguments") }
        try semanticReferences(.object(request.arguments))
        for key in ["query", "text", "section"] {
            if let value = request.arguments[key]?.string, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ActionContractError.invalid("$.arguments.\(key)")
            }
        }
        if request.action == "reader.open" {
            _ = try destination(request.arguments)
        }
        return ValidatedAction(request: request, descriptor: descriptor, explicitBackend: backends.first)
    }

    private static func semanticReferences(_ value: ActionJSON) throws {
        switch value {
        case .object(let object):
            if object["workKey"] != nil, let name = object["backend"]?.string, let backend = ActionBackendID(rawValue: name) {
                if object["position"] != nil { try text(try value.decoded(as: ActionTextRef.self), backend: backend) }
                else { try work(try value.decoded(as: ActionWorkRef.self), backend: backend) }
            }
            for value in object.values { try semanticReferences(value) }
        case .array(let values): for value in values { try semanticReferences(value) }
        default: break
        }
    }

    static func bounded(_ value: ActionJSON) throws {
        var stack: [(ActionJSON, Int)] = [(value, 0)]
        var nodes = 0, stringBytes = 0
        while let (value, depth) = stack.popLast() {
            nodes += 1
            guard nodes <= 10_000, depth <= 16 else { throw ActionContractError.inputTooLarge }
            switch value {
            case .object(let fields):
                for (key, value) in fields { stringBytes += key.utf8.count; stack.append((value, depth + 1)) }
            case .array(let values): stack += values.map { ($0, depth + 1) }
            case .string(let string): stringBytes += string.utf8.count
            case .number(let number): guard number.isFinite else { throw ActionContractError.invalid("$") }
            default: break
            }
            guard stringBytes <= ActionWireCodec.maxRequestBytes else { throw ActionContractError.inputTooLarge }
        }
    }
    private static func collectBackends(_ value: ActionJSON, into backends: inout Set<ActionBackendID>) throws {
        switch value {
        case .object(let fields):
            for (key, value) in fields {
                if ["backend", "targetBackend"].contains(key) {
                    guard let name = value.string, let backend = ActionBackendID(rawValue: name) else { throw ActionContractError.invalid("$.arguments") }
                    backends.insert(backend)
                }
                try collectBackends(value, into: &backends)
            }
        case .array(let values): for value in values { try collectBackends(value, into: &backends) }
        default: break
        }
    }
    static func work(_ ref: ActionWorkRef, backend: ActionBackendID) throws {
        guard ref.backend == backend, nonempty(ref.workKey, max: 512), (ref.catalogRevision?.unicodeScalars.count ?? 0) <= 128 else {
            throw ActionContractError.invalid("workRef")
        }
    }
    static func text(_ ref: ActionTextRef, backend: ActionBackendID) throws {
        try work(ActionWorkRef(backend: ref.backend, workKey: ref.workKey, catalogRevision: ref.catalogRevision), backend: backend)
        guard (ref.dataRevision?.unicodeScalars.count ?? 0) <= 128 else { throw ActionContractError.invalid("dataRevision") }
        switch ref.position {
        case .legacyLine(let line): guard line >= 0 else { throw ActionContractError.invalid("position") }
        case .canonicalRef(let string): guard nonempty(string, max: 1000) else { throw ActionContractError.invalid("position") }
        }
    }
    static func destination(_ args: ActionObject) throws -> ActionReaderDestination {
        guard let raw = args["sectionLocator"] else { throw ActionContractError.invalid("sectionLocator") }
        let section = try raw.decoded(as: ActionTextRef.self)
        try text(section, backend: section.backend)
        let focus = try args["focusLocator"]?.decoded(as: ActionTextRef.self)
        if let focus {
            try text(focus, backend: section.backend)
            guard focus.workKey == section.workKey else { throw ActionContractError.invalid("focusLocator") }
        }
        return ActionReaderDestination(sectionLocator: section, focusLocator: focus,
            presentationMode: args["presentationMode"]?.string.flatMap(ActionReaderDestination.PresentationMode.init(rawValue:)) ?? .sameTab)
    }
    static func search(_ args: ActionObject, backend: ActionBackendID) throws -> ActionSearchQuery {
        guard let text = args["text"]?.string, nonempty(text, max: 1000) else { throw ActionContractError.invalid("text") }
        let scopes = try (args["scopeWorkRefs"] ?? .array([])).decoded(as: [ActionWorkRef].self)
        for ref in scopes { try work(ref, backend: backend) }
        return ActionSearchQuery(backend: backend, text: text, scopeWorkRefs: scopes,
            searchMode: args["searchMode"]?.string.flatMap(ActionSearchQuery.Mode.init(rawValue:)) ?? .phrase,
            matchMode: args["matchMode"]?.string.flatMap(ActionSearchQuery.Match.init(rawValue:)) ?? .exact,
            wordDistance: Int(args["wordDistance"]?.integer ?? 0),
            sortOrder: args["sortOrder"]?.string.flatMap(ActionSearchQuery.Sort.init(rawValue:)) ?? .relevance,
            offset: Int(args["offset"]?.integer ?? 0), limit: Int(args["limit"]?.integer ?? 20))
    }
    static func nonempty(_ string: String, max: Int) -> Bool {
        !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && string.unicodeScalars.count <= max
    }
}

struct ActionEngineFailure: Error, Sendable {
    let status: ActionStatus
    let code: String
    init(_ status: ActionStatus, _ code: String) { self.status = status; self.code = code }
}
