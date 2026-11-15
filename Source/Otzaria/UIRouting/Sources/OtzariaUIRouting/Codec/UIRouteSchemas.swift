import Foundation
import OtzariaActionCore

/// Schema projection reuses Core's canonical ref/search field definitions.
/// It never defines another identity, business policy or JSON parser.
public enum UIRouteSchemas {
    private static let destinationPattern = "^[a-z][A-Za-z0-9_-]*(\\.[a-z][A-Za-z0-9_-]*){1,7}$"
    private static let stablePattern = "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$"
    private static func string(_ max: Int, min: Int = 1, pattern: String? = nil) -> ActionJSON {
        var fields: ActionObject = ["type": .string("string"), "minLength": .integer(Int64(min)), "maxLength": .integer(Int64(max))]
        if let pattern { fields["pattern"] = .string(pattern) }; return .object(fields)
    }
    private static func enumeration(_ values: [String]) -> ActionJSON { .object(["enum": .array(values.map(ActionJSON.string))]) }
    private static func integer(max: Int64? = nil) -> ActionJSON {
        var fields: ActionObject = ["type": .string("integer"), "minimum": .integer(0)]
        if let max { fields["maximum"] = .integer(max) }; return .object(fields)
    }
    private static func object(_ fields: ActionObject, required: [String]) -> ActionJSON {
        .object(["type": .string("object"), "additionalProperties": .bool(false), "properties": .object(fields), "required": .array(required.map(ActionJSON.string))])
    }
    private static func array(_ item: ActionJSON, max: Int = 32) -> ActionJSON {
        .object(["type": .string("array"), "items": item, "maxItems": .integer(Int64(max)), "uniqueItems": .bool(true)])
    }
    public static func privateRoute(version: Int = 1) throws -> ActionJSON {
        guard version == 0 || version == 1 else { throw UIRouteError(.notSupported, "route_version_unsupported") }
        let core = try ActionRegistry()
        let reference = try coreReference(core)
        let content = try contentSchema(core: core, publicOnly: false)
        var search = try fields(core, action: "search.query")
        search["required"] = .array(["backend", "text", "scopeWorkRefs", "searchMode", "matchMode", "wordDistance", "sortOrder", "offset", "limit"].map(ActionJSON.string))
        let privateState = object(["search": .object(search), "draftNote": string(10_000, min: 0), "selectedText": string(10_000, min: 0)], required: [])
        let id = string(128, pattern: destinationPattern), stable = string(128, pattern: stablePattern)
        let state = object([
            "version": .object(["const": .integer(1)]), "workspaceID": stable, "profileID": stable, "selectedItemID": stable,
            "visibleComponents": array(id), "expandedComponents": array(id), "sidebarVisible": .object(["type": .string("boolean")]),
            "inspectorVisible": .object(["type": .string("boolean")]), "sheet": id, "scrollAnchor": reference, "privateState": privateState
        ], required: ["version", "visibleComponents", "expandedComponents"])
        let focus = object([
            "kind": enumeration(["content", "component", "selection"]), "locator": reference, "anchor": id,
            "range": object(["location": integer(max: 1_000_000_000), "length": integer(max: 10_000)], required: ["location", "length"])
        ], required: ["kind"])
        return object([
            "version": .object(["const": .integer(Int64(version))]), "requestId": uuid(), "destination": id,
            "backend": enumeration(ActionBackendID.allCases.map(\.rawValue)), "content": content,
            "presentation": object(["kind": enumeration(PresentationSpec.Kind.allCases.map(\.rawValue)), "tabID": stable], required: ["kind"]),
            "state": state, "focus": focus,
            "scene": object(["kind": enumeration(["current", "specific", "newWindow"]), "sceneID": stable, "expectedRevision": integer()], required: ["kind"]),
            "expectedBackendSnapshot": object(["backend": enumeration(ActionBackendID.allCases.map(\.rawValue)), "generation": integer(), "rpcEpoch": integer()], required: ["backend", "generation"])
        ], required: ["version", "requestId", "destination", "presentation", "state", "scene"])
    }
    public static func publicRoute() throws -> ActionJSON {
        let core = try ActionRegistry()
        return object([
            "version": .object(["const": .integer(1)]), "requestId": uuid(), "destination": string(128, pattern: destinationPattern),
            "backend": enumeration(ActionBackendID.allCases.map(\.rawValue)), "content": try contentSchema(core: core, publicOnly: true),
            "presentation": enumeration(["currentTab", "newTab"])
        ], required: ["version", "requestId", "destination", "presentation"])
    }
    private static func uuid() -> ActionJSON { .object(["type": .string("string"), "format": .string("uuid"), "maxLength": .integer(36), "minLength": .integer(36)]) }
    private static func fields(_ core: ActionRegistry, action: String) throws -> ActionObject {
        guard let fields = core.descriptor(for: action)?.argumentsSchema.object else { throw UIRouteError(.failed, "core_schema_missing") }
        return fields
    }
    private static func coreReference(_ core: ActionRegistry) throws -> ActionJSON {
        guard let reference = try fields(core, action: "reader.open")["properties"]?.object?["sectionLocator"] else { throw UIRouteError(.failed, "core_schema_missing") }
        return reference
    }
    private static func contentSchema(core: ActionRegistry, publicOnly: Bool) throws -> ActionJSON {
        var reference = try coreReference(core)
        if publicOnly, var shape = reference.object, var properties = shape["properties"]?.object {
            properties.removeValue(forKey: "catalogRevision"); properties.removeValue(forKey: "dataRevision")
            shape["properties"] = .object(properties); reference = .object(shape)
        }
        return object(["sectionLocator": reference, "focusLocator": reference, "presentationMode": enumeration(["sameTab", "newTab"])], required: ["sectionLocator", "presentationMode"])
    }
}
