import Foundation

final class OtzariaSecurityScopedAccess {
    enum AccessError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "The selected Otzaria database is no longer accessible. Choose it again."
            }
        }
    }

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
        guard url.startAccessingSecurityScopedResource() else {
            throw AccessError.permissionDenied
        }
        return OtzariaSecurityScopedAccess(url: url, isActive: true)
    }

    func stop() {
        if isActive {
            url.stopAccessingSecurityScopedResource()
            isActive = false
        }
    }
}
