import Foundation
extension ResultsViewModel {
    func updateFolder(
        _ folder: FolderNode,
        newParent: Int64?
    ) {
        // Single point untuk update semua cache
        folderById[folder.id] = folder
        parentById[folder.id] = newParent
    }
}
