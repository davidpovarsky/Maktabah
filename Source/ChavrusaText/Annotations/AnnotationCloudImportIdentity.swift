import Foundation

/// Limits UUID-less legacy adoption to the same original text identity.
/// The positional SQL prefilter alone cannot distinguish backend work IDs.
enum AnnotationCloudImportIdentity {
    static func matchesLegacy(storedLocatorJSON: String?, incoming: Annotation) -> Bool {
        switch (storedLocatorJSON, incoming.backendLocator) {
        case (nil, nil):
            // Original catalog rows have a nonnegative book ID. An unbound
            // synthetic backend ID is not sufficient evidence for adoption.
            return incoming.bkId >= 0
        case let (raw?, locator?):
            guard let stored = try? JSONDecoder().decode(
                TextLocator.self, from: Data(raw.utf8)
            ) else { return false }
            return stored == locator
        default:
            return false
        }
    }
}
