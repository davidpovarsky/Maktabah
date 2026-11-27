import Foundation
import ChavrusaUIRoutingHost

@MainActor
final class MaktabahNativeRootPublicationSource {
    let nativePublication = NativeComponentSourcePublication()
    private(set) var selectionRevision: UInt64? = 0
    private(set) var settingsRevision: UInt64? = 0

    func selectionBinding(_ original: Binding<iOSTab>) -> Binding<iOSTab> {
        Binding(get: { original.wrappedValue }, set: { [self] value, transaction in
            nativePublication.invalidateRetainedSources()
            selectionRevision = Self.advanced(selectionRevision)
            original.transaction(transaction).wrappedValue = value
        })
    }
    func settingsBinding(_ original: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { original.wrappedValue }, set: { [self] value, transaction in
            nativePublication.invalidateRetainedSources()
            settingsRevision = Self.advanced(settingsRevision)
            original.transaction(transaction).wrappedValue = value
        })
    }
    private static func advanced(_ revision: UInt64?) -> UInt64? {
        guard let revision, revision < .max else { return nil }
        return revision + 1
    }
}
