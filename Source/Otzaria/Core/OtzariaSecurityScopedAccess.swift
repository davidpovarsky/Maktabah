import Foundation

final class OtzariaSecurityScopedAccess {
    let url: URL
    private var isActive: Bool

    private init(url: URL, isActive: Bool) {
        self.url = url
        self.isActive = isActive
    }

    deinit {
        stop()
    }

    static func start(for url: URL) throws -> OtzariaSecurityScopedAccess {
        let didStart = url.startAccessingSecurityScopedResource()
        return OtzariaSecurityScopedAccess(url: url, isActive: didStart)
    }

    func stop() {
        if isActive {
            url.stopAccessingSecurityScopedResource()
            isActive = false
        }
    }
}
