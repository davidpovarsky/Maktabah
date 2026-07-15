import Foundation

@_silgen_name("mzayit_engine_create")
private func c_mzayit_engine_create(_ json: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("mzayit_engine_search")
private func c_mzayit_engine_search(
    _ engineID: UInt64,
    _ json: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("mzayit_engine_destroy")
private func c_mzayit_engine_destroy(_ engineID: UInt64)

@_silgen_name("mzayit_string_free")
private func c_mzayit_string_free(_ value: UnsafeMutablePointer<CChar>?)

final class ZayitSearchEngineBridge: @unchecked Sendable {
    private var id: UInt64 = 0

    deinit { close() }

    func open(paths: ZayitSearchDataPaths) throws {
        close()
        let data = try JSONEncoder().encode(paths)
        let json = String(decoding: data, as: UTF8.self)
        let response = try call { c_mzayit_engine_create($0) }(json)
        let object = try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any]
        guard let value = object?["engine_id"] as? NSNumber else {
            throw BridgeError.engine(Self.errorMessage(in: object) ?? response)
        }
        id = value.uint64Value
    }

    func search(_ request: ZayitSearchRequest) throws -> ZayitSearchPage {
        guard id != 0 else { throw BridgeError.notOpen }
        let data = try JSONEncoder().encode(request)
        let json = String(decoding: data, as: UTF8.self)
        let result = try call { pointer in c_mzayit_engine_search(id, pointer) }(json)
        if let object = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any],
           let message = Self.errorMessage(in: object) {
            throw BridgeError.engine(message)
        }
        return try JSONDecoder().decode(ZayitSearchPage.self, from: Data(result.utf8))
    }

    func close() {
        guard id != 0 else { return }
        c_mzayit_engine_destroy(id)
        id = 0
    }

    private func call(_ function: @escaping (UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?) -> (String) throws -> String {
        { input in
            guard let ptr = input.withCString(function) else { throw BridgeError.nullResponse }
            defer { c_mzayit_string_free(ptr) }
            return String(cString: ptr)
        }
    }

    private static func errorMessage(in object: [String: Any]?) -> String? {
        guard object?["ok"] as? Bool == false,
              let error = object?["error"] as? [String: Any] else {
            return nil
        }
        return error["message"] as? String
    }

    enum BridgeError: LocalizedError {
        case notOpen
        case nullResponse
        case engine(String)

        var errorDescription: String? {
            switch self {
            case .notOpen: "Search engine is not open."
            case .nullResponse: "Search engine returned no data."
            case let .engine(value): value
            }
        }
    }
}
