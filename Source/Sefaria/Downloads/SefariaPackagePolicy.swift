import Foundation

enum SefariaPackagePolicy {
    static func resolve(_ ids: Set<String>, from packages: [OfflinePackage]) -> [OfflinePackage] {
        OfflinePackageSelection.resolve(ids, from: packages)
    }
}

enum SefariaFileTransaction {
    static func atomicReplace(_ staged: URL, target: URL, manager: FileManager = .default) throws {
        if manager.fileExists(atPath: target.path) {
            _ = try manager.replaceItemAt(target, withItemAt: staged, backupItemName: nil, options: [])
        } else {
            try manager.moveItem(at: staged, to: target)
        }
    }
}
