#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

@_silgen_name("otzaria_search_engine_new")
private func c_engineNew(_ path: UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
@_silgen_name("otzaria_search_engine_new_with_error")
private func c_engineNewWithError(_ path: UnsafePointer<CChar>, _ outError: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> UnsafeMutableRawPointer?
@_silgen_name("otzaria_search_engine_last_init_error")
private func c_lastInitError() -> UnsafeMutablePointer<CChar>?
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

enum OtzariaSearchExecutionPreparationError: Error, Sendable {
    case unavailable, sourceBusy, sourceChanged, deadlineExceeded
}

final class OtzariaSearchEngineBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.goldcreative.otzaria.search-engine", qos: .userInitiated)
    private var handle: UnsafeMutableRawPointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queueIdentity = DispatchSpecificKey<UInt8>()
    private let occurrenceLock = NSLock()
    private var occurrenceClosing = false
    private var occurrenceOperations: [UInt64: OtzariaExactOccurrenceOperation] = [:]
    #if OTZARIA_OCCURRENCE_TESTING
    private var occurrenceAfterNativeCount: (@Sendable () -> Void)?
    #endif

    convenience init(indexURL: URL) throws {
        try self.init(indexURL: indexURL, requiresExistingCompatibleIndex: false)
    }

    /// Cooperative app cold-open only. The caller owns the original storage
    /// mutation locks. The unchanged native constructor is still writer-capable;
    /// this is not a globally read-only filesystem or native-engine contract.
    convenience init(existingIndexURL: URL) throws {
        try self.init(indexURL: existingIndexURL, requiresExistingCompatibleIndex: true)
    }

    private init(indexURL: URL, requiresExistingCompatibleIndex: Bool) throws {
        queue.setSpecific(key: queueIdentity, value: 1)
        if requiresExistingCompatibleIndex {
            try Self.validateExistingCompatibleIndex(indexURL)
        } else {
            try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        }
        var errorPtr: UnsafeMutablePointer<CChar>? = nil
        let handle = indexURL.path.withCString { cPath in
            c_engineNewWithError(cPath, &errorPtr)
        }
        if let handle {
            self.handle = handle
            return
        }
        var errorCode = "UNKNOWN_INIT_ERROR"
        var errorMessage = "Unknown search engine initialization failure"
        let cErr = errorPtr ?? c_lastInitError()
        if let cErr {
            let jsonString = String(cString: cErr)
            c_freeString(cErr)
            if let data = jsonString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let code = parsed["code"] as? String { errorCode = code }
                if let message = parsed["message"] as? String { errorMessage = message }
            } else {
                errorMessage = jsonString
            }
        }
        throw OtzariaSearchError.engineInitializationFailed(code: errorCode, message: errorMessage)
    }

    deinit { close() }

    func close() {
        // Register/enqueue and close are ordered by the same short lock.
        // Native cancellation must never wait behind the engine queue.
        let pending = occurrenceLock.withLock {
            occurrenceClosing = true
            return Array(occurrenceOperations.values)
        }
        pending.forEach { $0.cancel(.engineClosed) }
        let freeHandle = {
            guard let handle = self.handle else { return }
            c_engineFree(handle)
            self.handle = nil
        }
        // A new async worker can own the final Bridge retain. Its cleanup may
        // therefore run deinit on this queue; self-sync would deadlock.
        if DispatchQueue.getSpecific(key: queueIdentity) != nil {
            freeHandle()
        } else {
            queue.sync(execute: freeHandle)
        }
    }

    func countExactTokenOccurrences(
        request: OtzariaExactOccurrenceRequest,
        expectedSource: OtzariaExactOccurrenceSource
    ) async throws -> OtzariaExactOccurrenceResult {
        guard !Task.isCancelled else { throw OtzariaExactOccurrenceError.cancelled }
        guard !occurrenceLock.withLock({ occurrenceClosing }) else {
            throw OtzariaExactOccurrenceError.engineClosed
        }
        let (deadlineNanos, overflow) = DispatchTime.now().uptimeNanoseconds
            .addingReportingOverflow(request.timeoutMs * 1_000_000)
        guard !overflow else { throw OtzariaExactOccurrenceError.invalidLimits }
        let deadline = DispatchTime(uptimeNanoseconds: deadlineNanos)
        let build: OtzariaSearchEngineBuildInfo
        do { build = try Self.buildInfo() }
        catch { throw OtzariaExactOccurrenceError.invalidResponse }
        try expectedSource.validate(buildInfo: build)
        // C captures its own absolute deadline before any queue/mutex wait.
        // The Swift deadline starts even earlier and guards await publication.
        let operation = try OtzariaExactOccurrenceOperation.create(
            request: request, expectedSource: expectedSource, deadline: deadline
        )
        let value = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.install(continuation)
                operation.startDeadlineTimer()
                let accepted = occurrenceLock.withLock {
                    guard !occurrenceClosing else { return false }
                    occurrenceOperations[operation.token] = operation
                    // Enqueue inside the registration lock, so close cannot
                    // submit its synchronous free ahead of an accepted worker.
                    queue.async { [self, operation] in
                        defer {
                            _ = occurrenceLock.withLock {
                                occurrenceOperations.removeValue(forKey: operation.token)
                            }
                            operation.releaseAfterWorker()
                        }
                        guard !operation.isComplete else { return }
                        guard let handle else {
                            operation.cancel(.engineClosed)
                            return
                        }
                        do {
                            let result = try operation.execute(handle: handle)
                            #if OTZARIA_OCCURRENCE_TESTING
                            let hook = occurrenceLock.withLock { occurrenceAfterNativeCount }
                            hook?()
                            #endif
                            operation.complete(.success(result))
                        } catch let failure as OtzariaExactOccurrenceError {
                            operation.complete(.failure(failure))
                        } catch {
                            operation.complete(.failure(.invalidResponse))
                        }
                    }
                    return true
                }
                if !accepted {
                    operation.cancel(.engineClosed)
                    operation.releaseAfterWorker()
                }
            }
        } onCancel: {
            operation.cancel(.cancelled)
        }
        guard !Task.isCancelled else { throw OtzariaExactOccurrenceError.cancelled }
        guard DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds else {
            throw OtzariaExactOccurrenceError.deadlineExceeded
        }
        guard !occurrenceLock.withLock({ occurrenceClosing }) else {
            throw OtzariaExactOccurrenceError.engineClosed
        }
        return value
    }

    #if OTZARIA_OCCURRENCE_TESTING
    // Scheduling/observation only. No raw handle, result, query or provider is
    // exposed or substituted by these whole-file runtime acceptance hooks.
    func occurrenceTestEnqueue(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }

    func occurrenceTestAfterCount(_ hook: (@Sendable () -> Void)?) {
        occurrenceLock.withLock { occurrenceAfterNativeCount = hook }
    }

    var occurrenceTestPendingCount: Int {
        occurrenceLock.withLock { occurrenceOperations.count }
    }

    var occurrenceTestIsClosing: Bool {
        occurrenceLock.withLock { occurrenceClosing }
    }
    #endif

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

    static func checkExecutionPreparationDeadline(_ deadline: UInt64) throws {
        try Task.checkCancellation()
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw OtzariaSearchExecutionPreparationError.deadlineExceeded
        }
    }

    /// Reject a missing/legacy/corrupt index before the original C constructor.
    /// In particular, legacy-compatible metadata would cause its sidecar repair.
    static func validateExistingCompatibleIndex(_ indexURL: URL) throws {
        let manager = FileManager.default
        let directory = try manager.attributesOfItem(atPath: indexURL.path)
        guard directory[.type] as? FileAttributeType == .typeDirectory else {
            throw OtzariaSearchExecutionPreparationError.unavailable
        }
        for name in ["meta.json", "otzaria_index_meta.json"] {
            let attributes = try manager.attributesOfItem(atPath: indexURL.appendingPathComponent(name).path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let bytes = attributes[.size] as? NSNumber,
                  bytes.uint64Value > 0, bytes.uint64Value <= 1_048_576 else {
                throw OtzariaSearchExecutionPreparationError.unavailable
            }
        }
        let compatibility = try checkCompatibility(indexURL: indexURL)
        guard compatibility.compatible, compatibility.status == "compatible" else {
            throw OtzariaSearchExecutionPreparationError.unavailable
        }
    }

    static func validateExecutionDictionary(_ url: URL, expectedSHA256: String, deadline: UInt64) throws {
        try checkExecutionPreparationDeadline(deadline)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let maximum: UInt64 = 67_108_864
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let bytes = attributes[.size] as? NSNumber,
              bytes.uint64Value > 0, bytes.uint64Value <= maximum else {
            throw OtzariaSearchExecutionPreparationError.unavailable
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = SHA256(), consumed: UInt64 = 0
        while let chunk = try file.read(upToCount: 1_048_576), !chunk.isEmpty {
            try checkExecutionPreparationDeadline(deadline)
            consumed += UInt64(chunk.count)
            guard consumed <= maximum else { throw OtzariaSearchExecutionPreparationError.unavailable }
            hasher.update(data: chunk)
        }
        let observed = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard consumed == bytes.uint64Value, observed == expectedSHA256 else {
            throw OtzariaSearchExecutionPreparationError.unavailable
        }
        try checkExecutionPreparationDeadline(deadline)
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
