import CryptoKit
import Foundation

@_silgen_name("otzaria_search_engine_new")
private func c_engineNew(_ path: UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
@_silgen_name("otzaria_search_engine_free")
private func c_engineFree(_ handle: UnsafeMutableRawPointer?)
@_silgen_name("otzaria_search_engine_search_json")
private func c_search(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_book_counts_json")
private func c_bookCounts(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_facet_counts_json")
private func c_facetCounts(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>, _ prefix: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_add_text_book_json")
private func c_addTextBook(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_add_pdf_book_json")
private func c_addPDFBook(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_set_bulk_indexing")
private func c_setBulkIndexing(_ handle: UnsafeMutableRawPointer?, _ enabled: Bool) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_clear")
private func c_clear(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_commit")
private func c_commit(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_rollback")
private func c_rollback(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_optimize")
private func c_optimize(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_document_count")
private func c_documentCount(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_indexed_file_paths")
private func c_indexedFilePaths(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_book_fingerprints")
private func c_bookFingerprints(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_delete_file_paths_json")
private func c_deleteFilePaths(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_check_compatibility")
private func c_checkCompatibility(_ path: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_build_info")
private func c_buildInfo() -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_set_dictionaries_json")
private func c_setDictionaries(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_helper_json")
private func c_helper(_ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_semantic_json")
private func c_semantic(_ handle: UnsafeMutableRawPointer?, _ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("otzaria_search_engine_free_string")
private func c_freeString(_ value: UnsafeMutablePointer<CChar>?)

final class OtzariaSearchEngineBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.goldcreative.otzaria.search-engine", qos: .userInitiated)
    private var handle: UnsafeMutableRawPointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(indexURL: URL) throws {
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        handle = indexURL.path.withCString(c_engineNew)
        guard handle != nil else { throw OtzariaSearchError.engineNotAvailable }
    }

    deinit { close() }

    func close() {
        queue.sync {
            guard let handle else { return }
            c_engineFree(handle)
            self.handle = nil
        }
    }

    func search(_ request: OtzariaSearchRequest) throws -> OtzariaSearchPage {
        try callJSON(operation: "search", payload: request, c_search)
    }

    func bookCounts(_ request: OtzariaSearchRequest) throws -> OtzariaBookCounts {
        try callJSON(operation: "bookCounts", payload: request, c_bookCounts)
    }

    func facetCounts(_ request: OtzariaSearchRequest, prefix: String) throws -> OtzariaFacetCounts {
        let data = try encoder.encode(request)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OtzariaSearchError.invalidEngineResponse("facetCounts: payload is not UTF-8")
        }
        return try call(operation: "facetCounts") { handle in
            json.withCString { requestPointer in
                prefix.withCString { prefixPointer in
                    c_facetCounts(handle, requestPointer, prefixPointer)
                }
            }
        }
    }

    @discardableResult
    func addTextBookBytes(
        title: String,
        topics: String,
        filePath: String,
        catalogueOrder: UInt32,
        generationOrder: UInt32,
        utf8: Data,
        extraFacets: [String] = []
    ) throws -> UInt32 {
        let input = OtzariaBookIndexInput(
            title: title,
            topics: topics,
            filePath: filePath,
            catalogueOrder: catalogueOrder,
            generationOrder: generationOrder,
            text: nil,
            textBase64: utf8.base64EncodedString(),
            extraFacets: extraFacets.isEmpty ? nil : extraFacets
        )
        return try callJSON(operation: "addTextBookBytes", payload: input, c_addTextBook)
    }

    @discardableResult
    func addTextBook(
        title: String,
        topics: String,
        filePath: String,
        catalogueOrder: UInt32,
        generationOrder: UInt32,
        text: String,
        extraFacets: [String] = []
    ) throws -> UInt32 {
        let input = OtzariaBookIndexInput(
            title: title,
            topics: topics,
            filePath: filePath,
            catalogueOrder: catalogueOrder,
            generationOrder: generationOrder,
            text: text,
            textBase64: nil,
            extraFacets: extraFacets.isEmpty ? nil : extraFacets
        )
        return try callJSON(operation: "addTextBook", payload: input, c_addTextBook)
    }

    @discardableResult
    func addPDFBook(_ input: OtzariaPDFBookIndexInput) throws -> UInt32 {
        try callJSON(operation: "addPDFBook", payload: input, c_addPDFBook)
    }

    func setBulkIndexing(_ enabled: Bool) throws {
        let _: Bool = try call(operation: "setBulkIndexing") { c_setBulkIndexing($0, enabled) }
    }

    func clear() throws { let _: Bool = try call(operation: "clear", c_clear) }
    func commit() throws { let _: Bool = try call(operation: "commit", c_commit) }
    func rollback() throws { let _: Bool = try call(operation: "rollback", c_rollback) }
    func optimize() throws { let _: Bool = try call(operation: "optimize", c_optimize) }
    func documentCount() throws -> UInt64 { try call(operation: "documentCount", c_documentCount) }
    func indexedFilePaths() throws -> [String] { try call(operation: "indexedFilePaths", c_indexedFilePaths) }
    func bookFingerprints() throws -> [String: UInt64] { try call(operation: "bookFingerprints", c_bookFingerprints) }
    func deleteFilePaths(_ filePaths: [String]) throws {
        let _: Bool = try callJSON(operation: "deleteFilePaths", payload: filePaths, c_deleteFilePaths)
    }

    func configureDictionaries(magic: URL?, translation: URL?, acronyms: URL?) throws -> [String: Bool] {
        struct Payload: Encodable { let magic: String?; let translation: String?; let acronyms: String? }
        return try callJSON(
            operation: "setDictionaries",
            payload: Payload(magic: magic?.path, translation: translation?.path, acronyms: acronyms?.path),
            c_setDictionaries
        )
    }

    func semantic<Response: Decodable, Payload: Encodable>(_ payload: Payload, as: Response.Type = Response.self) throws -> Response {
        try callJSON(operation: "semantic", payload: payload, c_semantic)
    }

    func configureSemantic(
        rootDirectory: URL,
        model: URL,
        identity: OtzariaSemanticArtifactIdentity
    ) throws -> OtzariaSemanticStatus {
        let build = try Self.buildInfo()
        guard build.semanticEnabled,
              build.semanticSidecarRevision == identity.sidecarRevision,
              try Self.sha256(model) == identity.modelSHA256 else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Semantic model hash/sidecar identity does not match the registered artifact"
            )
        }
        struct Payload: Encodable {
            let operation = "configure"
            let rootDir: String
            let modelPath: String
            let modelId: String
            let embeddingDim: UInt32
        }
        return try semantic(Payload(
            rootDir: rootDirectory.path,
            modelPath: model.path,
            modelId: identity.modelID,
            embeddingDim: identity.embeddingDimension
        ))
    }

    func semanticStatus() throws -> OtzariaSemanticStatus {
        struct Payload: Encodable { let operation = "status" }
        return try semantic(Payload())
    }

    func disableSemantic() throws -> OtzariaSemanticStatus {
        struct Payload: Encodable { let operation = "disable" }
        return try semantic(Payload())
    }

    func semanticDiff() throws -> OtzariaSemanticDiff {
        struct Payload: Encodable { let operation = "diff" }
        return try semantic(Payload())
    }

    func resetSemanticIndex() throws -> OtzariaSemanticMutationResult {
        struct Payload: Encodable { let operation = "reset" }
        return try semantic(Payload())
    }

    func removeSemanticBooks(_ sourceBookKeys: [String]) throws -> OtzariaSemanticMutationResult {
        struct Payload: Encodable { let operation = "remove"; let sourceBookKeys: [String] }
        return try semantic(Payload(sourceBookKeys: sourceBookKeys))
    }

    func indexSemanticBooks(_ books: [OtzariaSemanticBookInput]) throws -> OtzariaSemanticIndexResult {
        struct Payload: Encodable { let operation = "index"; let books: [OtzariaSemanticBookInput] }
        return try semantic(Payload(books: books))
    }

    func searchSemantic(_ request: OtzariaSemanticSearchRequest) throws -> OtzariaSemanticSearchResponse {
        try semantic(request)
    }

    static func checkCompatibility(indexURL: URL) throws -> OtzariaIndexCompatibility {
        try indexURL.path.withCString { path in
            try decodeStatic(operation: "checkIndexCompatibility", raw: c_checkCompatibility(path))
        }
    }

    static func buildInfo() throws -> OtzariaSearchEngineBuildInfo {
        try decodeStatic(operation: "buildInfo", raw: c_buildInfo())
    }

    static func sanitizeQuery(_ query: String) throws -> String {
        struct Payload: Encodable { let operation = "sanitizeQuery"; let input: String }
        return try helper(Payload(input: query))
    }

    static func splitQueryWords(_ query: String) throws -> [String] {
        struct Payload: Encodable { let operation = "splitQueryWords"; let input: String }
        return try helper(Payload(input: query))
    }

    static func normalizeTextForIndexing(_ text: String) throws -> String {
        struct Payload: Encodable { let operation = "normalizeTextForIndexing"; let input: String }
        return try helper(Payload(input: text))
    }

    static func computeBookFingerprint(
        text: String,
        title: String,
        topics: String,
        catalogueOrder: UInt32,
        generationOrder: UInt32,
        extraFacets: [String]
    ) throws -> UInt64 {
        struct Payload: Encodable {
            let operation = "computeBookFingerprint"
            let input: String
            let title: String
            let topics: String
            let catalogueOrder: UInt32
            let generationOrder: UInt32
            let extraFacets: [String]
        }
        return try helper(Payload(
            input: text, title: title, topics: topics,
            catalogueOrder: catalogueOrder, generationOrder: generationOrder,
            extraFacets: extraFacets
        ))
    }

    private func callJSON<Response: Decodable, Payload: Encodable>(
        operation: String,
        payload: Payload,
        _ function: (UnsafeMutableRawPointer?, UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
    ) throws -> Response {
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OtzariaSearchError.invalidEngineResponse("\(operation): payload is not UTF-8")
        }
        return try call(operation: operation) { handle in
            json.withCString { function(handle, $0) }
        }
    }

    private func call<Response: Decodable>(
        operation: String,
        _ function: (UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>?
    ) throws -> Response {
        try queue.sync {
            guard let handle else { throw OtzariaSearchError.engineNotAvailable }
            return try Self.decodeStatic(operation: operation, raw: function(handle), decoder: decoder)
        }
    }

    private static func helper<Response: Decodable, Payload: Encodable>(_ payload: Payload) throws -> Response {
        let data = try JSONEncoder().encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OtzariaSearchError.invalidEngineResponse("helper payload is not UTF-8")
        }
        return try json.withCString { pointer in
            try decodeStatic(operation: "helper", raw: c_helper(pointer))
        }
    }

    static func highlightPattern(for request: OtzariaSearchRequest) throws -> OtzariaHighlightPattern? {
        struct Payload: Encodable {
            let operation = "highlightPattern"
            let input: String
            let distance: UInt32
            let customSpacing: [String: String]
            let alternativeWords: [String: [String]]
            let searchOptions: [String: [String: Bool]]
        }
        return try helper(Payload(
            input: request.query,
            distance: UInt32(max(0, request.distance)),
            customSpacing: request.customSpacing,
            alternativeWords: request.alternativeWords,
            searchOptions: request.searchOptions
        ))
    }

    private static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_024 * 1_024), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func decodeStatic<Response: Decodable>(
        operation: String,
        raw: UnsafeMutablePointer<CChar>?,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> Response {
        guard let raw else {
            throw OtzariaSearchError.invalidEngineResponse("\(operation): native adapter returned null")
        }
        defer { c_freeString(raw) }
        let response = try decoder.decode(
            OtzariaEngineResponse<Response>.self,
            from: Data(String(cString: raw).utf8)
        )
        guard response.ok, let value = response.value else {
            throw OtzariaSearchError.invalidEngineResponse(response.error ?? "\(operation): unknown native error")
        }
        return value
    }
}
