//
//  ResultsHandler.swift
//  maktab
//
//  Created by MacBook on 05/12/25.
//

import SQLite
import Foundation

// MARK: - Sync Models

struct SyncFolder {
    var id: Int64?
    var name: String
    var parent: Int64?
    var ckRecordId: String?
    var lastModified: Int64?
    var parentCkRecordId: String?
}

struct SyncResult {
    var id: Int64?
    var folderId: Int64?
    var name: String
    var query: String
    var archive: Int
    var bkId: Int
    var contentId: String
    var ckRecordId: String?
    var lastModified: Int64?
    var folderCkRecordId: String?
}

class ResultsHandler {
    private(set) var db: Connection!
    static var shared: ResultsHandler = .init()

    let foldersTbl = Table("folders")
    let id = Expression<Int64>("id")
    let name = Expression<String>("name")
    let parent = Expression<Int64?>("parent")
    let ckRecordId = Expression<String?>("ckRecordId")
    let lastModified = Expression<Int64?>("lastModified")
    let parentCkRecordId = Expression<String?>("parentCkRecordId")

    let results = Table("results")
    let folderId = Expression<Int64?>("folder_id")
    let query = Expression<String>("query")
    let archive = Expression<Int>("archives")
    let bkId = Expression<Int>("bkId")
    let contentId = Expression<String>("contentId")
    let resCkRecordId = Expression<String?>("ckRecordId")
    let resLastModified = Expression<Int64?>("lastModified")
    let folderCkRecordId = Expression<String?>("folderCkRecordId")

    private init() {}

    func setupResultDatabase(at URL: URL?) throws {
        guard let folderURL = URL else { throw NSError(domain: "maktabah", code: 404) }
        let url = folderURL.appendingPathComponent("SearchResults.sqlite")
        
        let fm = FileManager.default
        let isNewDatabase = !fm.fileExists(atPath: url.path)
        
        db = try Connection(url.path)
        createTables()
        
        if isNewDatabase {
            CloudKitSyncManager.shared.resetChangeToken()
        }
    }

    func createTables() {
        do {
            guard let db else {
                ReusableFunc.showAlert(title: "Database not initialized", message: "")
                return
            }

            // MARK: - folders table
            try db.run(foldersTbl.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(name)
                t.column(parent)
                t.column(ckRecordId)
                t.column(lastModified)
                t.column(parentCkRecordId)
                t.unique(name, parent)
            })

            // MARK: - results table
            try db.run(results.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(folderId)
                t.column(name)
                t.column(query)
                t.column(archive)
                t.column(bkId)
                t.column(contentId)
                t.column(resCkRecordId)
                t.column(resLastModified)
                t.column(folderCkRecordId)
                t.unique(folderId, name, bkId)
            })
            
            // Migration for existing databases
            let folderCols = try db.prepare("PRAGMA table_info(folders)").map { $0[1] as! String }
            if !folderCols.contains("ckRecordId") {
                _ = try? db.run(foldersTbl.addColumn(ckRecordId))
            }
            if !folderCols.contains("lastModified") {
                _ = try? db.run(foldersTbl.addColumn(lastModified))
            }
            if !folderCols.contains("parentCkRecordId") {
                _ = try? db.run(foldersTbl.addColumn(parentCkRecordId))
            }
            
            let resultCols = try db.prepare("PRAGMA table_info(results)").map { $0[1] as! String }
            if !resultCols.contains("ckRecordId") {
                _ = try? db.run(results.addColumn(resCkRecordId))
            }
            if !resultCols.contains("lastModified") {
                _ = try? db.run(results.addColumn(resLastModified))
            }
            if !resultCols.contains("folderCkRecordId") {
                _ = try? db.run(results.addColumn(folderCkRecordId))
            }
            
            if let db = db as Connection? {
                try backfillResultsCloudKitFieldsIfNeeded(in: db)
            }
            
        } catch {
            #if DEBUG
            print("Error creating tables: \(error)")
            #endif
        }

        createUniqueIndex()
    }

    func backfillResultsCloudKitFieldsIfNeeded(in db: Connection) throws {
        let now = Int64(Date().timeIntervalSince1970)
        
        // 1. Backfill Folders (Order by parent to ensure top-down backfill)
        let nullFolders = foldersTbl.filter(ckRecordId == nil).order(parent.asc)
        var foldersToUpload: [SyncFolder] = []
        
        try db.transaction {
            for row in try db.prepare(nullFolders) {
                let fId = row[id]
                let fName = row[name]
                let fParent = row[parent]
                
                // Deterministic ID based on name and parent's ckRecordId
                var parentIdentifier = "root"
                if let pid = fParent {
                    parentIdentifier = try db.pluck(foldersTbl.filter(id == pid))?[ckRecordId] ?? "orphan_\(pid)"
                }
                
                let detId = "folder_\(fName)_\(parentIdentifier)"
                
                try db.run(foldersTbl.filter(id == fId).update(
                    ckRecordId <- detId,
                    lastModified <- now,
                    parentCkRecordId <- (parentIdentifier == "root" ? nil : parentIdentifier)
                ))
                
                if let updated = try db.pluck(foldersTbl.filter(id == fId)) {
                    foldersToUpload.append(makeSyncFolder(from: updated))
                }
            }
        }
        
        // 2. Backfill Results
        let nullResults = results.filter(resCkRecordId == nil)
        var resultsToUpload: [SyncResult] = []
        
        try db.transaction {
            for row in try db.prepare(nullResults) {
                let rId = row[id]
                let rFolderId = row[folderId]
                let rName = row[name]
                let rBkId = row[bkId]
                let rArchive = row[archive]
                
                // Deterministic ID based on properties and folder's ckRecordId
                var folderIdentifier = "root"
                if let fid = rFolderId {
                    folderIdentifier = try db.pluck(foldersTbl.filter(id == fid))?[ckRecordId] ?? "orphan_\(fid)"
                }
                
                let detId = "result_\(folderIdentifier)_\(rName)_\(rBkId)_\(rArchive)"
                
                try db.run(results.filter(id == rId).update(
                    resCkRecordId <- detId,
                    resLastModified <- now,
                    folderCkRecordId <- (folderIdentifier == "root" ? nil : folderIdentifier)
                ))
                
                if let updated = try db.pluck(results.filter(id == rId)) {
                    resultsToUpload.append(makeSyncResult(from: updated))
                }
            }
        }
        
        if !foldersToUpload.isEmpty || !resultsToUpload.isEmpty {
            DispatchQueue.global(qos: .background).async {
                CloudKitSyncManager.shared.uploadResultsData(folders: foldersToUpload, results: resultsToUpload)
            }
        }
    }

    private func makeSyncFolder(from row: Row) -> SyncFolder {
        SyncFolder(
            id: row[id],
            name: row[name],
            parent: row[parent],
            ckRecordId: row[ckRecordId],
            lastModified: row[lastModified],
            parentCkRecordId: row[parentCkRecordId]
        )
    }

    private func makeSyncResult(from row: Row) -> SyncResult {
        SyncResult(
            id: row[id],
            folderId: row[folderId],
            name: row[name],
            query: row[query],
            archive: row[archive],
            bkId: row[bkId],
            contentId: row[contentId],
            ckRecordId: row[resCkRecordId],
            lastModified: row[resLastModified],
            folderCkRecordId: row[folderCkRecordId]
        )
    }

    func createUniqueIndex() {
        do {
            try db.run("CREATE UNIQUE INDEX IF NOT EXISTS idx_folders_parent_name ON folders (COALESCE(parent, 0), name)")
            try db.run("CREATE UNIQUE INDEX IF NOT EXISTS idx_results_folder_name ON results (COALESCE(folder_id, 0), name)")
            // optional: mencegah duplikat konten yang sama di folder yang sama
            try db.run("DROP INDEX IF EXISTS idx_results_folder_name")
            try db.run("CREATE UNIQUE INDEX IF NOT EXISTS idx_results_folder_name_bk ON results (COALESCE(folder_id, 0), name, bkId)")
        } catch {
            #if DEBUG
            print("Create index error:", error)
            #endif
        }
    }
}

extension ResultsHandler {
    func insertRootFolder(name: String) throws -> Int64? {
        let cId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        
        let insert = foldersTbl.insert(
            self.name <- name,
            parent <- nil,
            ckRecordId <- cId,
            lastModified <- now
        )
        let rowId = try db.run(insert)
        
        if let row = try db.pluck(foldersTbl.filter(id == rowId)) {
            CloudKitSyncManager.shared.uploadResultsData(folders: [makeSyncFolder(from: row)], results: [])
        }
        
        return rowId
    }

    func insertSubFolder(parentNode: FolderNode, name: String) throws -> Int64? {
        let cId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        
        // Fetch parent ckRecordId
        let pCkId = try db.pluck(foldersTbl.filter(id == parentNode.id))?[ckRecordId]

        let insert = foldersTbl.insert(
            self.name <- name,
            parent <- parentNode.id,
            ckRecordId <- cId,
            lastModified <- now,
            parentCkRecordId <- pCkId
        )
        let rowId = try db.run(insert)
        
        if let row = try db.pluck(foldersTbl.filter(id == rowId)) {
            CloudKitSyncManager.shared.uploadResultsData(folders: [makeSyncFolder(from: row)], results: [])
        }
        
        return rowId
    }

    func fetchFolderTree() -> [FolderNode] {
        var nodes: [Int64: FolderNode] = [:]
        var roots: [FolderNode] = []

        do {
            for row in try db.prepare(foldersTbl) {
                let node = FolderNode(id: row[id], name: row[name])
                nodes[row[id]] = node
            }

            // isi children
            for row in try db.prepare(foldersTbl) {
                if let parentId = row[parent], let parentNode = nodes[parentId] {
                    parentNode.children.append(nodes[row[id]]!)
                } else {
                    roots.append(nodes[row[id]]!)
                }
            }
        } catch {
            print("Fetch folder tree error:", error)
        }

        return roots
    }

    func deleteFolder(_ folderId: Int64) {
        do {
            // Collect ckRecordIds for CloudKit deletion
            let allFolderIds = getAllDescendantIds(of: folderId)
            var ckIdsToDelete: [String] = []
            
            for fId in allFolderIds {
                if let ckId = try db.pluck(foldersTbl.filter(id == fId))?[ckRecordId] {
                    ckIdsToDelete.append(ckId)
                }
                // results for this folder
                let resQuery = results.filter(self.folderId == fId)
                for res in try db.prepare(resQuery) {
                    if let rCkId = res[resCkRecordId] {
                        ckIdsToDelete.append(rCkId)
                    }
                }
            }

            try db.transaction {
                // Delete semua results
                for id in allFolderIds {
                    let resultsToDelete = results.filter(self.folderId == id)
                    try db.run(resultsToDelete.delete())
                }

                // Delete semua folders (dari child ke parent)
                for id in allFolderIds.reversed() {
                    let folder = foldersTbl.filter(self.id == id)
                    try db.run(folder.delete())
                }
            }
            
            if !ckIdsToDelete.isEmpty {
                CloudKitSyncManager.shared.delete(ckRecordIds: ckIdsToDelete)
            }
        } catch {
            print("❌ Delete transaction failed:", error)
        }
    }

    func deleteResult(_ folderId: Int64?, name: String) {
        let query = results.filter(self.folderId == folderId && self.name == name)
        do {
            var ckIds: [String] = []
            for row in try db.prepare(query) {
                if let ckId = row[resCkRecordId] { ckIds.append(ckId) }
            }
            
            try db.run(query.delete())
            
            if !ckIds.isEmpty {
                CloudKitSyncManager.shared.delete(ckRecordIds: ckIds)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func updateParent(of id: Int64, to newParentId: Int64?) throws {
        let folder = foldersTbl.filter(self.id == id)
        let now = Int64(Date().timeIntervalSince1970)
        
        var pCkId: String? = nil
        if let pid = newParentId {
            pCkId = try db.pluck(foldersTbl.filter(self.id == pid))?[ckRecordId]
        }
        
        try db.run(folder.update(
            parent <- newParentId,
            lastModified <- now,
            parentCkRecordId <- pCkId
        ))
        
        if let row = try db.pluck(folder) {
            CloudKitSyncManager.shared.uploadResultsData(folders: [makeSyncFolder(from: row)], results: [])
        }
    }

    func updateResultParent(newParentId: Int64?, oldParent: Int64?, name: String) throws {
        let query = results.filter(folderId == oldParent && self.name == name)
        let now = Int64(Date().timeIntervalSince1970)
        
        var fCkId: String? = nil
        if let fid = newParentId {
            fCkId = try db.pluck(foldersTbl.filter(self.id == fid))?[ckRecordId]
        }
        
        try db.run(query.update(
            folderId <- newParentId,
            resLastModified <- now,
            folderCkRecordId <- fCkId
        ))
        
        var updated: [SyncResult] = []
        for row in try db.prepare(query) {
            updated.append(makeSyncResult(from: row))
        }
        if !updated.isEmpty {
            CloudKitSyncManager.shared.uploadResultsData(folders: [], results: updated)
        }
    }
}

extension ResultsHandler {
    func insertResult(_ archive: Int, bkId: Int, contentId: String, folderId: Int64?, query: String, name: String) throws {
        let cId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        
        var fCkId: String? = nil
        if let fid = folderId {
            fCkId = try db.pluck(foldersTbl.filter(id == fid))?[ckRecordId]
        }

        let insert = results.insert(
            self.folderId <- folderId,
            self.name <- name,
            self.query <- query,
            self.archive <- archive,
            self.bkId <- bkId,
            self.contentId <- contentId,
            self.resCkRecordId <- cId,
            self.resLastModified <- now,
            self.folderCkRecordId <- fCkId
        )
        let rowId = try db.run(insert)
        
        if let row = try db.pluck(results.filter(id == rowId)) {
            CloudKitSyncManager.shared.uploadResultsData(folders: [], results: [makeSyncResult(from: row)])
        }
    }

    func fetchResults(forFolder folderId: Int64?) -> [ResultNode] {
        var groupedResults: [String: (id: Int64, parentId: Int64?, items: [SavedResultsItem])] = [:]

        do {
            let query = results.filter(self.folderId == folderId)

            for row in try db.prepare(query) {
                let queryName = row[self.query]
                let savedName = row[name]
                let resultId = row[id]
                let parentId = row[self.folderId]   // Int64?

                let contentsId = row[contentId].components(separatedBy: ",")

                for cid in contentsId {
                    guard let idInt = Int(cid),
                          let book = LibraryDataManager.shared.getBook([row[bkId]]).first
                    else { continue }

                    let item = SavedResultsItem(
                        archive: String(row[archive]),
                        tableName: String(row[bkId]),
                        query: queryName,
                        bookId: idInt,
                        bookTitle: book.book
                    )

                    if groupedResults[savedName] == nil {
                        groupedResults[savedName] = (id: resultId, parentId: parentId, items: [])
                    }

                    groupedResults[savedName]?.items.append(item)
                }
            }
        } catch {
            print("Fetch results error:", error)
        }

        return groupedResults.map {
            ResultNode(
                id: $0.value.id,
                parentId: $0.value.parentId, // ResultNode harus menerima Int64?
                name: $0.key,
                items: $0.value.items
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

}


extension ResultsHandler {
    func updateFolderName(id folderId: Int64, newName: String) throws {
        let row = foldersTbl.filter(id == folderId)
        let now = Int64(Date().timeIntervalSince1970)
        try db.run(row.update(
            name <- newName,
            lastModified <- now
        ))
        
        if let updated = try db.pluck(row) {
            CloudKitSyncManager.shared.uploadResultsData(folders: [makeSyncFolder(from: updated)], results: [])
        }
    }

    func updateResultQueryName(folderId: Int64?, oldName: String, newName: String) throws {
        let query = results.filter(self.folderId == folderId && self.name == oldName)
        let now = Int64(Date().timeIntervalSince1970)
        try db.run(query.update(
            self.name <- newName,
            resLastModified <- now
        ))
        
        var updatedResults: [SyncResult] = []
        for row in try db.prepare(query) {
            updatedResults.append(makeSyncResult(from: row))
        }
        if !updatedResults.isEmpty {
            CloudKitSyncManager.shared.uploadResultsData(folders: [], results: updatedResults)
        }
    }

    func updateResultsFolder(oldFolderId: Int64, newFolderId: Int64) {
        do {
            let query = results.filter(folderId == oldFolderId)
            let now = Int64(Date().timeIntervalSince1970)
            
            var fCkId: String? = nil
            if let fid = try? db.pluck(foldersTbl.filter(id == newFolderId))?[ckRecordId] {
                fCkId = fid
            }
            
            try db.run(query.update(
                folderId <- newFolderId,
                resLastModified <- now,
                folderCkRecordId <- fCkId
            ))
            
            var updatedResults: [SyncResult] = []
            for row in try db.prepare(query) {
                updatedResults.append(makeSyncResult(from: row))
            }
            if !updatedResults.isEmpty {
                CloudKitSyncManager.shared.uploadResultsData(folders: [], results: updatedResults)
            }
        } catch {
            print("Update results folder error:", error)
        }
    }

    func getAllDescendantIds(of folderId: Int64) -> [Int64] {
        var ids: [Int64] = [folderId]

        do {
            let children = foldersTbl.filter(parent == folderId)
            for row in try db.prepare(children) {
                let childId = row[id]
                ids.append(contentsOf: getAllDescendantIds(of: childId))
            }
        } catch {
            print("Get descendants error:", error)
        }

        return ids
    }
    
    func fetchAllSyncFolders() -> [SyncFolder] {
        var results: [SyncFolder] = []
        do {
            for row in try db.prepare(foldersTbl) {
                results.append(makeSyncFolder(from: row))
            }
        } catch {
            print("fetchAllSyncFolders error: \(error)")
        }
        return results
    }
    
    func fetchAllSyncResults() -> [SyncResult] {
        var resultsList: [SyncResult] = []
        do {
            for row in try db.prepare(results) {
                resultsList.append(makeSyncResult(from: row))
            }
        } catch {
            print("fetchAllSyncResults error: \(error)")
        }
        return resultsList
    }
}

// MARK: - CloudKit Sync Apply

extension ResultsHandler {
    func applyCloudKitFolderChanges(foldersToSave: [SyncFolder], recordIdsToDelete: [String]) {
        guard let db else { return }
        
        do {
            try db.transaction {
                // 1. Process Deletions
                for ckId in recordIdsToDelete {
                    let query = foldersTbl.filter(ckRecordId == ckId)
                    if let row = try db.pluck(query) {
                        let localId = row[id]
                        
                        // Recursive delete everything locally for this folder
                        let allLocalIds = getAllDescendantIds(of: localId)
                        for fId in allLocalIds {
                            try db.run(results.filter(folderId == fId).delete())
                            try db.run(foldersTbl.filter(id == fId).delete())
                        }
                    }
                }
                
                // 2. Process Saves/Updates (Pass 1: Upsert Folders)
                for folder in foldersToSave {
                    guard let ckId = folder.ckRecordId else { continue }
                    let query = foldersTbl.filter(ckRecordId == ckId)
                    
                    if let row = try db.pluck(query) {
                        let localLastMod = row[lastModified] ?? 0
                        let remoteLastMod = folder.lastModified ?? 0
                        
                        if remoteLastMod >= localLastMod {
                            try db.run(query.update(
                                name <- folder.name,
                                lastModified <- folder.lastModified,
                                parentCkRecordId <- folder.parentCkRecordId
                            ))
                        }
                    } else {
                        try db.run(foldersTbl.insert(
                            name <- folder.name,
                            ckRecordId <- ckId,
                            lastModified <- folder.lastModified,
                            parentCkRecordId <- folder.parentCkRecordId
                        ))
                    }
                }
                
                // 3. Pass 2: Resolve Parent Pointers
                for folder in foldersToSave {
                    guard let ckId = folder.ckRecordId else { continue }
                    if let pCkId = folder.parentCkRecordId {
                        if let pRow = try db.pluck(foldersTbl.filter(ckRecordId == pCkId)) {
                            let pLocalId = pRow[id]
                            try db.run(foldersTbl.filter(ckRecordId == ckId).update(
                                parent <- pLocalId
                            ))
                        }
                    } else {
                        try db.run(foldersTbl.filter(ckRecordId == ckId).update(
                            parent <- nil
                        ))
                    }
                }
            }
            
            // Post notification for UI refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .annotationTreeDidUpdate, object: nil)
            }
        } catch {
            print("ResultsHandler: Failed to apply folder changes - \(error)")
        }
    }
    
    func applyCloudKitResultChanges(resultsToSave: [SyncResult], recordIdsToDelete: [String]) {
        guard let db else { return }
        
        do {
            try db.transaction {
                // 1. Process Deletions
                for ckId in recordIdsToDelete {
                    _ = try? db.run(results.filter(resCkRecordId == ckId).delete())
                }
                
                // 2. Process Saves/Updates
                for res in resultsToSave {
                    guard let ckId = res.ckRecordId else { continue }
                    let recordQuery = results.filter(resCkRecordId == ckId)
                    
                    // Resolve folderId
                    var fLocalId: Int64? = nil
                    if let fCkId = res.folderCkRecordId {
                        fLocalId = try db.pluck(foldersTbl.filter(ckRecordId == fCkId))?[id]
                    }
                    
                    if let row = try db.pluck(recordQuery) {
                        let localLastMod = row[resLastModified] ?? 0
                        let remoteLastMod = res.lastModified ?? 0
                        
                        if remoteLastMod >= localLastMod {
                            try db.run(recordQuery.update(
                                folderId <- fLocalId,
                                name <- res.name,
                                self.query <- res.query,
                                archive <- res.archive,
                                bkId <- res.bkId,
                                contentId <- res.contentId,
                                resLastModified <- res.lastModified,
                                folderCkRecordId <- res.folderCkRecordId
                            ))
                        }
                    } else {
                        try db.run(results.insert(
                            folderId <- fLocalId,
                            name <- res.name,
                            self.query <- res.query,
                            archive <- res.archive,
                            bkId <- res.bkId,
                            contentId <- res.contentId,
                            resCkRecordId <- ckId,
                            resLastModified <- res.lastModified,
                            folderCkRecordId <- res.folderCkRecordId
                        ))
                    }
                }
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .annotationTreeDidUpdate, object: nil)
            }
        } catch {
            print("ResultsHandler: Failed to apply result changes - \(error)")
        }
    }
}
