import Foundation

enum ZayitSearchDataValidator {
    static func paths(in folder: URL, existingSeforimDB: URL? = nil) throws -> ZayitSearchDataPaths {
        let fm = FileManager.default
        let seforim = existingSeforimDB ?? folder.appendingPathComponent("seforim.db", isDirectory: false)
        let lexical = folder.appendingPathComponent("lexical.db", isDirectory: false)
        let index = folder.appendingPathComponent("zayit-search-index", isDirectory: true)
        let metadata = index.appendingPathComponent("zayit-index-metadata.json", isDirectory: false)

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: seforim.path) else { throw Error.missing("seforim.db") }
        guard fm.fileExists(atPath: lexical.path) else { throw Error.missing("lexical.db") }
        guard fm.fileExists(atPath: index.path, isDirectory: &isDir), isDir.boolValue else {
            throw Error.missing("zayit-search-index/")
        }
        guard fm.fileExists(atPath: metadata.path) else {
            throw Error.missing("zayit-search-index/zayit-index-metadata.json")
        }
        return .init(seforimDb: seforim.path, lexicalDb: lexical.path, indexDir: index.path)
    }

    enum Error: LocalizedError {
        case missing(String)
        var errorDescription: String? {
            if case let .missing(value) = self {
                return "Missing required item: \(value)"
            }
            return nil
        }
    }
}
