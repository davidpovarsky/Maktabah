import Foundation

enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static let miniTest10ID = "miniTest10"
    static let launchArgument = "-OtzariaDataProfile"
    static let environmentKey = "OTZARIA_DATA_PROFILE"
    static let embeddedDefaultKey = "OtzariaDefaultDataProfile"

    static var activeProfileID: String {
        resolvedProfileID(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            embeddedDefault: Bundle.main.object(forInfoDictionaryKey: embeddedDefaultKey) as? String
        )
    }

    static var activeProfile: OtzariaDataProfile? {
        guard activeProfileID != productionID else { return nil }
        return try? loadProfile(id: activeProfileID)
    }

    static var activeIdentity: (id: String, version: Int) {
        let selected = activeProfileID
        guard selected != productionID else { return (productionID, 1) }
        return (selected, activeProfile?.profileVersion ?? 1)
    }

    static func requireActiveProfile() throws -> OtzariaDataProfile {
        guard activeProfileID != productionID else {
            throw OtzariaDataProfileError.profileNotFound(productionID)
        }
        return try loadProfile(id: activeProfileID)
    }

    static func loadProfile(id: String, bundle: Bundle = .main) throws -> OtzariaDataProfile {
        guard id != productionID,
              let url = bundle.url(forResource: "\(id).profile", withExtension: "json") else {
            throw OtzariaDataProfileError.profileNotFound(id)
        }
        let profile = try JSONDecoder().decode(OtzariaDataProfile.self, from: Data(contentsOf: url))
        try profile.validate()
        guard profile.profileID == id else {
            throw OtzariaDataProfileError.invalidManifest("resource name and profileID differ")
        }
        return profile
    }

    static func resolvedProfileID(
        arguments: [String],
        environment: [String: String],
        embeddedDefault: String?
    ) -> String {
        if let value = launchArgumentValue(arguments: arguments), !value.isEmpty { return value }
        if let value = environment[environmentKey], !value.isEmpty { return value }
        if let value = embeddedDefault?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty, !value.hasPrefix("$(") {
            return value
        }
        return productionID
    }

    private static func launchArgumentValue(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: launchArgument),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
