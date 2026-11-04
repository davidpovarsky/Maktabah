import Foundation

/// Sidecar only. Never opens the canonical reader-session file for writing.
struct StudyWorkspacePersistence {
    let url: URL
    var backupURL: URL { url.appendingPathExtension("bak") }

    func load() throws -> StudyWorkspaceSnapshot? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        do { return try decode(url) }
        catch {
            // Unknown future schemas must never be replaced by an older backup.
            if let error = error as? StudyWorkspaceError, case .unsupportedVersion = error { throw error }
            guard fm.fileExists(atPath: backupURL.path) else { throw error }
            return try decode(backupURL)
        }
    }

    private func decode(_ source: URL) throws -> StudyWorkspaceSnapshot {
        let value = try JSONDecoder().decode(StudyWorkspaceSnapshot.self, from: Data(contentsOf: source))
        try value.validate()
        return value
    }

    func archiveBeforeMigration(canonicalSessionURL: URL) throws {
        let fm = FileManager.default
        let legacyDirectory = canonicalSessionURL.deletingLastPathComponent()
        // Previous experimental builds used these names beside the canonical
        // session. Archive opaque bytes only; do not import an unknown schema
        // or reuse the previous UI/state implementation.
        let sources = [(canonicalSessionURL, "pre-workspace-ios-reader-session.json"),
                       (url, "pre-workspace-sidecar.json"),
                       (legacyDirectory.appendingPathComponent("study_workspace_v1.json"), "pre-rebuild-study-workspace-v1.json"),
                       (legacyDirectory.appendingPathComponent("study_workspace_v1.bak.json"), "pre-rebuild-study-workspace-v1.bak.json")]
        for (source, name) in sources {
            let destination = url.deletingLastPathComponent().appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path), !fm.fileExists(atPath: destination.path) else { continue }
            let bytes = try Data(contentsOf: source)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: destination, options: .atomic)
        }
    }

    func save(_ value: StudyWorkspaceSnapshot) throws {
        try value.validate()
        let fm = FileManager.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(value)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Copy only a validated previous version into .bak; corrupt primary never poisons backup.
        if fm.fileExists(atPath: url.path), (try? decode(url)) != nil {
            try Data(contentsOf: url).write(to: backupURL, options: .atomic)
        }
        try bytes.write(to: url, options: .atomic)
    }
}
