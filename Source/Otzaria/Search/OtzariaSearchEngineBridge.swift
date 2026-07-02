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
        OtzariaIndexFileLogger.log("bridge deinit start hasHandle=\(handle != nil)")
        c_otzaria_search_engine_free(handle)
        OtzariaIndexFileLogger.log("bridge deinit end")
    }

    func addDocuments(_ documents: [OtzariaSearchDocument]) throws {
        OtzariaIndexFileLogger.log("bridge addDocuments start count=\(documents.count)")
        let data = try encoder.encode(documents)
        OtzariaIndexFileLogger.log("bridge addDocuments encoded bytes=\(data.count)")
        guard let json = String(data: data, encoding: .utf8) else {
            OtzariaIndexFileLogger.log("bridge addDocuments failed UTF8 conversion")
            throw OtzariaSearchError.invalidEngineResponse("Failed to encode documents JSON")
        }
        try runBooleanJSON(operation: "addDocuments") { handle in
            OtzariaIndexFileLogger.log("bridge addDocuments FFI start count=\(documents.count) jsonBytes=\(data.count)")
            return json.withCString { c_otzaria_search_engine_add_documents_json(handle, $0) }
        }
        OtzariaIndexFileLogger.log("bridge addDocuments end count=\(documents.count)")
    }

    func search(_ request: OtzariaSearchRequest) throws -> [OtzariaEngineSearchResult] {
        OtzariaIndexFileLogger.log("bridge search start mode=\(request.mode.rawValue) limit=\(request.limit) offset=\(request.offset)")
        let data = try encoder.encode(request)
        guard let json = String(data: data, encoding: .utf8) else {
            OtzariaIndexFileLogger.log("bridge search failed UTF8 conversion bytes=\(data.count)")
            throw OtzariaSearchError.invalidEngineResponse("Failed to encode search JSON")
        }
        return try queue.sync {
            do {
                guard let handle else { throw OtzariaSearchError.engineNotAvailable }
                let responseString = try json.withCString { ptr -> String in
                    OtzariaIndexFileLogger.log("bridge search FFI start jsonBytes=\(data.count)")
                    guard let raw = c_otzaria_search_engine_search_json(handle, ptr) else {
                        throw OtzariaSearchError.invalidEngineResponse("Rust search returned null")
                    }
                    defer { c_otzaria_search_engine_free_string(raw) }
                    let value = String(cString: raw)
                    OtzariaIndexFileLogger.log("bridge search FFI returned rawLength=\(value.utf8.count)")
                    return value
                }
                let response = try decoder.decode(OtzariaEngineResponse<[OtzariaEngineSearchResult]>.self, from: Data(responseString.utf8))
                OtzariaIndexFileLogger.log("bridge search decoded ok=\(response.ok) error=\(response.error ?? "")")
                guard response.ok else {
                    throw OtzariaSearchError.invalidEngineResponse(response.error ?? "Unknown Rust search error")
                }
                let results = response.value ?? []
                OtzariaIndexFileLogger.log("bridge search end resultCount=\(results.count)")
                return results
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
        OtzariaIndexFileLogger.log("bridge optimize start")
        try runBooleanJSON(operation: "optimize") { c_otzaria_search_engine_optimize($0) }
        OtzariaIndexFileLogger.log("bridge optimize end")
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
                OtzariaIndexFileLogger.log("bridge documentCount FFI returned rawLength=\(responseString.utf8.count)")
                let response = try decoder.decode(OtzariaEngineResponse<UInt64>.self, from: Data(responseString.utf8))
                OtzariaIndexFileLogger.log("bridge documentCount decoded ok=\(response.ok) error=\(response.error ?? "")")
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
                OtzariaIndexFileLogger.log("bridge \(operation) FFI returned rawLength=\(responseString.utf8.count)")
                let response = try decoder.decode(OtzariaEngineResponse<Bool>.self, from: Data(responseString.utf8))
                OtzariaIndexFileLogger.log("bridge \(operation) decoded ok=\(response.ok) error=\(response.error ?? "")")
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
