import Foundation

enum SefariaPackagePolicy {
    static func resolve(_ ids: Set<String>, from packages: [OfflinePackage]) -> [OfflinePackage] {
        OfflinePackageSelection.resolve(ids, from: packages)
    }
}

enum SefariaFileTransaction {
    static func atomicReplace(_ staged: URL, target: URL, manager: FileManager = .default) throws {
        if manager.fileExists(atPath: target.path) {
            #if os(Windows)
            let backup = target.deletingLastPathComponent()
                .appendingPathComponent(".backup-\(UUID().uuidString)")
            try manager.moveItem(at: target, to: backup)
            do {
                try manager.moveItem(at: staged, to: target)
                try manager.removeItem(at: backup)
            } catch {
                if manager.fileExists(atPath: target.path) { try? manager.removeItem(at: target) }
                try? manager.moveItem(at: backup, to: target)
                throw error
            }
            #else
            _ = try manager.replaceItemAt(target, withItemAt: staged, backupItemName: nil, options: [])
            #endif
        } else {
            try manager.moveItem(at: staged, to: target)
        }
    }
}
