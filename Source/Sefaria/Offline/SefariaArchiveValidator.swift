import Foundation
import ZIPFoundation

enum SefariaArchiveValidator {
    static func validate(_ url: URL) throws {
        let archive: Archive
        do { archive = try Archive(url: url, accessMode: .read) }
        catch { throw LibraryBackendError.corruptData("unreadable ZIP: \(error)") }
        guard archive.first(where: { _ in true }) != nil else {
            throw LibraryBackendError.corruptData("empty or unreadable ZIP")
        }
        for entry in archive {
            let normalized = entry.path.replacingOccurrences(of: "\\", with: "/")
            let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
            if normalized.hasPrefix("/") || components.contains("..") {
                throw LibraryBackendError.corruptData("unsafe ZIP path")
            }
        }
    }

    static func validateBookArchive(_ url: URL, expectedTitle: String) throws {
        try validate(url)
        let archive: Archive
        do { archive = try Archive(url: url, accessMode: .read) }
        catch { throw LibraryBackendError.corruptData("unreadable book ZIP: \(error)") }
        let expectedIndex = "\(expectedTitle)_index.json"
        guard archive.contains(where: {
            $0.path.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last
                == Substring(expectedIndex)
        }) else {
            throw LibraryBackendError.corruptData("book ZIP has no matching index for \(expectedTitle)")
        }
    }

    static func bookArchives(in directory: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        ) else { throw LibraryBackendError.corruptData("bundle produced no files") }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension.lowercased() == "zip" }
        guard !files.isEmpty else { throw LibraryBackendError.corruptData("bundle contains no book archives") }
        try files.forEach {
            try validateBookArchive($0, expectedTitle: $0.deletingPathExtension().lastPathComponent)
        }
        return files
    }
}
