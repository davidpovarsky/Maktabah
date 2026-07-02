import Foundation

@_silgen_name("otzaria_search_engine_new")
private func c_otzaria_search_engine_new(_ indexPath: UnsafePointer<CChar>) -> UnsafeMutableRawPointer?

@_silgen_name("otzaria_search_engine_free")
private func c_otzaria_search_engine_free(_ handle: UnsafeMutableRawPointer?)

@_silgen_name("otzaria_search_engine_add_documents_json")
private func c_otzaria_search_engine_add_documents_json(_ handle: UnsafeMutableRawPointer?, _ documentsJSON: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_search_json")
private func c_otzaria_search_engine_search_json(_ handle: UnsafeMutableRawPointer?, _ requestJSON: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_clear")
private func c_otzaria_search_engine_clear(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_commit")
private func c_otzaria_search_engine_commit(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_optimize")
private func c_otzaria_search_engine_optimize(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_document_count")
private func c_otzaria_search_engine_document_count(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_indexed_file_paths")
private func c_otzaria_search_engine_indexed_file_paths(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("otzaria_search_engine_free_string")
private func c_otzaria_search_engine_free_string(_ value: UnsafeMutablePointer<CChar>?)

final class OtzariaSearchEngineBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.goldcreative.otzaria.tantivy.bridge", qos: .userInitiated)
    private var handle: UnsafeMutableRawPointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(indexURL: URL) throws {
        let path = indexURL.path
        OtzariaIndexFileLogger.log("bridge init start path=\(path)")
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        handle = path.withCString { c_otzaria_search_engine_new($0) }
        guard handle != nil else {
            OtzariaIndexFileLogger.log("bridge init nil handle path=\(path)")
            throw OtzariaSearchError.engineNotAvailable
        }
        OtzariaIndexFileLogger.log("bridge init success path=\(path)")
    }

    deinit {
        c_otzaria_search_engine_free(handle)
    }

    func addDocuments(_ documents: [OtzariaSearchDocument]) throws {
        let data = try encoder.encode(documents)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OtzariaSearchError.invalidEngineResponse("Failed to encode documents JSON")
        }
        try runBooleanJSON(operation: "addDocuments") { handle in
            json.withCString { c_otzaria_search_engine_add_documents_json(handle, $0) }
        }
    }

    func search(_ request: OtzariaSearchRequest) throws -> [OtzariaEngineSearchResult] {
        let data = try encoder.encode(request)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OtzariaSearchError.invalidEngineResponse("Failed to encode search JSON")
        }
        return try queue.sync {
            do {
                guard let handle else { throw OtzariaSearchError.engineNotAvailable }
                let responseString = try json.withCString { ptr -> String in
                    guard let raw = c_otzaria_search_engine_search_json(handle, ptr) else {
                        throw OtzariaSearchError.invalidEngineResponse("Rust search returned null")
                    }
                    defer { c_otzaria_search_engine_free_string(raw) }
                    return String(cString: raw)
                }
                let response = try decoder.decode(OtzariaEngineResponse<[OtzariaEngineSearchResult]>.self, from: Data(responseString.utf8))
                guard response.ok else {
                    throw OtzariaSearchError.invalidEngineResponse(response.error ?? "Unknown Rust search error")
                }
                return response.value ?? []
            } catch {
                OtzariaIndexFileLogger.logError("bridge search threw", error: error)
                throw error
            }
        }
    }

    func clear() throws {
        OtzariaIndexFileLogger.log("bridge clear start")
        try runBooleanJSON(operation: "clear") { c_otzaria_search_engine_clear($0) }
        OtzariaIndexFileLogger.log("bridge clear end")
    }

    func commit() throws {
        OtzariaIndexFileLogger.log("bridge commit start")
        try runBooleanJSON(operation: "commit") { c_otzaria_search_engine_commit($0) }
        OtzariaIndexFileLogger.log("bridge commit end")
    }

    func optimize() throws {
        try runBooleanJSON(operation: "optimize") { c_otzaria_search_engine_optimize($0) }
    }

    func documentCount() throws -> UInt64 {
        OtzariaIndexFileLogger.log("bridge documentCount start")
        return try queue.sync {
            do {
                guard let handle else { throw OtzariaSearchError.engineNotAvailable }
                OtzariaIndexFileLogger.log("bridge documentCount FFI start")
                guard let raw = c_otzaria_search_engine_document_count(handle) else {
                    throw OtzariaSearchError.invalidEngineResponse("Rust documentCount returned null")
                }
                defer { c_otzaria_search_engine_free_string(raw) }
                let responseString = String(cString: raw)
                let response = try decoder.decode(OtzariaEngineResponse<UInt64>.self, from: Data(responseString.utf8))
                guard response.ok else {
                    throw OtzariaSearchError.invalidEngineResponse(response.error ?? "Unknown Rust documentCount error")
                }
                let value = response.value ?? 0
                OtzariaIndexFileLogger.log("bridge documentCount end value=\(value)")
                return value
            } catch {
                OtzariaIndexFileLogger.logError("bridge documentCount threw", error: error)
                throw error
            }
        }
    }

    func indexedFilePaths() throws -> [String] {
        OtzariaIndexFileLogger.log("bridge indexedFilePaths start")
        return try queue.sync {
            do {
                guard let handle else { throw OtzariaSearchError.engineNotAvailable }
                OtzariaIndexFileLogger.log("bridge indexedFilePaths FFI start")
                guard let raw = c_otzaria_search_engine_indexed_file_paths(handle) else {
                    throw OtzariaSearchError.invalidEngineResponse("Rust indexedFilePaths returned null")
                }
                defer { c_otzaria_search_engine_free_string(raw) }
                let responseString = String(cString: raw)
                let response = try decoder.decode(OtzariaEngineResponse<[String]>.self, from: Data(responseString.utf8))
                guard response.ok else {
                    throw OtzariaSearchError.invalidEngineResponse(response.error ?? "Unknown Rust indexedFilePaths error")
                }
                let value = response.value ?? []
                OtzariaIndexFileLogger.log("bridge indexedFilePaths end count=\(value.count)")
                return value
            } catch {
                OtzariaIndexFileLogger.logError("bridge indexedFilePaths threw", error: error)
                throw error
            }
        }
    }

    private func runBooleanJSON(
        operation: String,
        _ call: @escaping (UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
    ) throws {
        try queue.sync {
            do {
                guard let handle else { throw OtzariaSearchError.engineNotAvailable }
                guard let raw = call(handle) else {
                    throw OtzariaSearchError.invalidEngineResponse("Rust command returned null")
                }
                defer { c_otzaria_search_engine_free_string(raw) }
                let responseString = String(cString: raw)
                let response = try decoder.decode(OtzariaEngineResponse<Bool>.self, from: Data(responseString.utf8))
                guard response.ok else {
                    throw OtzariaSearchError.invalidEngineResponse(response.error ?? "Unknown Rust command error")
                }
            } catch {
                OtzariaIndexFileLogger.logError("bridge \(operation) threw", error: error)
                throw error
            }
        }
    }
}
