import Foundation

struct SefariaNetworkConfiguration: Sendable {
    let apiBaseURL: URL
    let readonlyBaseURL: URL
    let requestTimeout: TimeInterval

    static let production = SefariaNetworkConfiguration(
        apiBaseURL: URL(string: "https://www.sefaria.org")!,
        readonlyBaseURL: URL(string: "https://readonly.sefaria.org")!,
        requestTimeout: 30
    )

    func apiURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        try url(base: apiBaseURL, path: path, queryItems: queryItems)
    }

    func apiURL(pathPrefix: String, pathComponent: String, queryItems: [URLQueryItem] = []) throws -> URL {
        try url(base: apiBaseURL, pathPrefix: pathPrefix, pathComponent: pathComponent, queryItems: queryItems)
    }

    func readonlyURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        try url(base: readonlyBaseURL, path: path, queryItems: queryItems)
    }

    private func url(base: URL, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw LibraryBackendError.invalidResponse("invalid base URL")
        }
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw LibraryBackendError.invalidLocator }
        return url
    }

    private func url(
        base: URL,
        pathPrefix: String,
        pathComponent: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw LibraryBackendError.invalidResponse("invalid base URL")
        }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        guard let encoded = pathComponent.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw LibraryBackendError.invalidLocator
        }
        let prefix = pathPrefix.hasPrefix("/") ? pathPrefix : "/\(pathPrefix)"
        components.percentEncodedPath = prefix + encoded
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw LibraryBackendError.invalidLocator }
        return url
    }
}
