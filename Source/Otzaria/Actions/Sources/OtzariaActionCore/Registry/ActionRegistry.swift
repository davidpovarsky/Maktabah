import Foundation

public struct ActionDescriptor: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let riskTier: Int
    public let requiredCapabilities: [String]
    public let stage: String
    public let mutatesUserData: Bool
    public let execution: String
    public let argumentsSchema: ActionJSON
}

public struct ActionRegistry: Sendable {
    public static let implemented: Set<String> = ["system.listBackends", "catalog.resolveWork", "catalog.resolveReference", "search.query", "search.countOccurrences", "search.openResults", "reader.getTOC", "reader.getSection", "reader.getNavigationStructures", "reader.listVersions", "reader.open", "reader.openCommentary", "notes.prepareDraft"]
    public let descriptors: [ActionDescriptor]
    private let byID: [String: ActionDescriptor]
    public init() throws {
        struct Catalog: Decodable { let apiVersion: Int; let actionCount: Int; let actions: [ActionDescriptor] }
        let catalog = try JSONDecoder().decode(Catalog.self, from: Self.resource("action-catalog.v1.json"))
        guard catalog.apiVersion == 1, catalog.actionCount == 29, catalog.actions.count == 29,
              Set(catalog.actions.map(\.id)).count == 29 else { throw ActionContractError.invalid("catalog") }
        descriptors = catalog.actions
        byID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
    }
    public func descriptor(for action: String) -> ActionDescriptor? { byID[action] }
    public static func resource(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw ActionContractError.invalid("bundled_contract")
        }
        return try Data(contentsOf: url)
    }
    public static func schema(_ name: String) throws -> ActionJSON {
        try JSONDecoder().decode(ActionJSON.self, from: resource(name))
    }
}
