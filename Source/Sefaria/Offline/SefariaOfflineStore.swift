import CryptoKit
import Foundation
import ZIPFoundation

actor SefariaOfflineStore: LibraryTextProviding {
    private let paths: SefariaOfflinePaths
    private var archiveByTitle: [String: URL] = [:]
    private var metadataByBook: [String: [SefariaOfflineMetadataDTO]] = [:]

    init(paths: SefariaOfflinePaths = SefariaOfflinePaths()) {
        self.paths = paths
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        guard locator.backend == .sefaria, case .canonicalRef(let requestedRef) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        let bookDirectory = try expandedBook(title: locator.workKey)
        let metadata = try findMetadata(for: requestedRef, title: locator.workKey, in: bookDirectory)
        let versions = try loadVersions(metadata, title: locator.workKey, from: bookDirectory)
        guard !versions.isEmpty else {
            throw LibraryBackendError.corruptData("no readable version for \(metadata.sectionRef)")
        }
        return SefariaSection(
            ref: metadata.ref,
            heRef: metadata.heRef,
            sectionRef: metadata.sectionRef,
            indexTitle: metadata.indexTitle,
            next: metadata.next,
            prev: metadata.prev,
            versions: versions,
            linksBySegment: metadata.links ?? [],
            origin: .offline
        ).asLibrarySection()
    }

    func contains(workKey: String) -> Bool {
        (try? bookArchive(title: workKey)) != nil
    }

    func clearTransientState() {
        archiveByTitle.removeAll()
        metadataByBook.removeAll()
    }

    private func expandedBook(title: String) throws -> URL {
        let manager = FileManager.default
        let target = paths.expandedBooks.appendingPathComponent(SefariaOfflinePaths.safeComponent(title), isDirectory: true)
        if isValidExpandedBook(target, title: title) { return target }

        let archive = try bookArchive(title: title)
        let staging = paths.staging.appendingPathComponent("book-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        try manager.unzipItem(at: archive, to: staging)
        guard isValidExpandedBook(staging, title: title) else {
            throw LibraryBackendError.corruptData("book archive has no matching index")
        }
        try manager.createDirectory(at: paths.expandedBooks, withIntermediateDirectories: true)
        if manager.fileExists(atPath: target.path) {
            _ = try manager.replaceItemAt(target, withItemAt: staging)
        } else {
            try manager.moveItem(at: staging, to: target)
        }
        return target
    }

    private func bookArchive(title: String) throws -> URL {
        if let cached = archiveByTitle[title], FileManager.default.fileExists(atPath: cached.path) { return cached }
        guard let walker = FileManager.default.enumerator(
            at: paths.packages,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw LibraryBackendError.unavailableOffline }
        for case let url as URL in walker
            where url.pathExtension.lowercased() == "zip"
                && url.deletingPathExtension().lastPathComponent == title {
            archiveByTitle[title] = url
            return url
        }
        throw LibraryBackendError.unavailableOffline
    }

    private func isValidExpandedBook(_ directory: URL, title: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(title)_index.json").path)
    }

    private func findMetadata(for requestedRef: String, title: String, in directory: URL) throws -> SefariaOfflineMetadataDTO {
        let all: [SefariaOfflineMetadataDTO]
        if let cached = metadataByBook[title] {
            all = cached
        } else {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            let decoder = JSONDecoder()
            all = files.filter { $0.lastPathComponent.hasSuffix(".metadata.json") }.flatMap { url -> [SefariaOfflineMetadataDTO] in
                guard let data = try? Data(contentsOf: url),
                      let document = try? decoder.decode(SefariaOfflineMetadataDTO.self, from: data) else { return [] }
                return document.flattenedSections
            }
            metadataByBook[title] = all
        }
        guard let result = all.first(where: {
            requestedRef == $0.ref || requestedRef == $0.sectionRef
                || requestedRef.hasPrefix($0.sectionRef + ":")
        }) else { throw LibraryBackendError.unavailableOffline }
        return result
    }

    private func loadVersions(
        _ metadata: SefariaOfflineMetadataDTO,
        title: String,
        from directory: URL
    ) throws -> [SefariaVersion] {
        let indexURL = directory.appendingPathComponent("\(title)_index.json")
        let index = (try? Data(contentsOf: indexURL)).flatMap {
            try? JSONDecoder().decode(SefariaOfflineIndexDTO.self, from: $0)
        }
        var result: [SefariaVersion] = []
        for pointer in metadata.versions {
            let hash = Self.shortMD5(pointer.versionTitle)
            let fileRef = metadata.containerRef ?? metadata.sectionRef
            let filename = "\(fileRef).\(hash).\(pointer.language).json"
            let url = directory.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: url),
                  let document = try? JSONDecoder().decode(SefariaJSONValue.self, from: data) else { continue }
            let text = document.value(inSectionsFor: metadata.sectionRef) ?? document
            let metadataVersion = index?.versions.first {
                $0.versionTitle == pointer.versionTitle && $0.language == pointer.language
            }
            result.append(SefariaVersion(versionTitle: pointer.versionTitle, language: pointer.language,
                actualLanguage: metadataVersion?.actualLanguage, versionSource: metadataVersion?.versionSource,
                license: metadataVersion?.license, versionNotes: metadataVersion?.versionNotes,
                priority: metadataVersion?.priority, isPrimary: metadataVersion?.isPrimary ?? result.isEmpty,
                isSource: metadataVersion?.isSource ?? (pointer.language == "he"),
                direction: metadataVersion?.direction ?? (pointer.language == "he" ? "rtl" : "ltr"), text: text))
        }
        return result
    }

    private static func shortMD5(_ value: String) -> String {
        Insecure.MD5.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined().prefix(8).description
    }
}
