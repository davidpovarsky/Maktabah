import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor SefariaHTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func get<T: Decodable & Sendable>(_ type: T.Type, url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        return try await send(type, request: request)
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ type: T.Type, url: URL, body: Body
    ) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(type, request: request)
    }

    func postData<Body: Encodable & Sendable>(url: URL, body: Body) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        guard let http = response as? HTTPURLResponse else {
            throw LibraryBackendError.invalidResponse("missing HTTP response")
        }
        return (data, http)
    }

    func data(url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return data
    }

    func download(url: URL) async throws -> (URL, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        let (temporary, response) = try await session.download(for: request)
        try validate(response)
        guard let response = response as? HTTPURLResponse else {
            throw LibraryBackendError.invalidResponse("missing HTTP response")
        }
        return (temporary, response)
    }

    private func send<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do { return try decoder.decode(type, from: data) }
        catch { throw LibraryBackendError.invalidResponse(String(describing: error)) }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LibraryBackendError.invalidResponse("missing HTTP status")
        }
        guard (200...299).contains(http.statusCode) else {
            throw LibraryBackendError.httpStatus(http.statusCode)
        }
    }
}
