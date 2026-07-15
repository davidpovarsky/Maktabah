import Foundation

final class ZayitSearchEngineBridge: @unchecked Sendable {
    private var id: UInt64 = 0
    deinit { if id != 0 { mzayit_engine_destroy(id) } }

    func open(paths: ZayitSearchDataPaths) throws {
        let data=try JSONEncoder().encode(paths); let json=String(decoding:data,as:UTF8.self)
        let response=try call { mzayit_engine_create($0) }(json)
        let object=try JSONSerialization.jsonObject(with:Data(response.utf8)) as? [String:Any]
        guard let value=object?["engine_id"] as? NSNumber else { throw BridgeError.engine(response) }
        id=value.uint64Value
    }

    func search(_ request: ZayitSearchRequest) throws -> ZayitSearchPage {
        guard id != 0 else { throw BridgeError.notOpen }
        let data=try JSONEncoder().encode(request); let json=String(decoding:data,as:UTF8.self)
        let result=try call { pointer in mzayit_engine_search(id,pointer) }(json)
        return try JSONDecoder().decode(ZayitSearchPage.self,from:Data(result.utf8))
    }

    private func call(_ function: @escaping (UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?) -> (String) throws -> String {
        { input in
            guard let ptr=input.withCString(function) else { throw BridgeError.nullResponse }
            defer { mzayit_string_free(ptr) }
            return String(cString:ptr)
        }
    }
    enum BridgeError:LocalizedError { case notOpen,nullResponse,engine(String); var errorDescription:String?{switch self{case .notOpen:"Search engine is not open.";case .nullResponse:"Search engine returned no data.";case let .engine(v):v}} }
}
