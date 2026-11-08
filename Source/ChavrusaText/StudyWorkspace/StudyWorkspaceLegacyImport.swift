import Foundation

/// One-time conversion of the inspected baseline schema. Original bytes remain
/// archived by StudyWorkspacePersistence; unknown formats are never interpreted.
enum StudyWorkspaceLegacyImport {
    static func snapshot(data: Data) throws -> StudyWorkspaceSnapshot? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["schemaVersion"] as? Int == 1 else { return nil }
        func uuid(_ value: Any?) throws -> UUID {
            guard let text = value as? String, let id = UUID(uuidString: text) else { throw StudyWorkspaceError.invalidMembership }
            return id
        }
        guard let profiles = object["profiles"] as? [[String: Any]],
              let groups = object["groups"] as? [[String: Any]] else { throw StudyWorkspaceError.invalidMembership }
        var tabs: [String: [String: Any]] = [:]
        if let dictionary = object["tabsByID"] as? [String: [String: Any]] {
            tabs = Dictionary(dictionary.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        } else if let pairs = object["tabsByID"] as? [Any], pairs.count.isMultiple(of: 2) {
            for offset in stride(from: 0, to: pairs.count, by: 2) {
                guard let key = pairs[offset] as? String, let tab = pairs[offset + 1] as? [String: Any],
                      tabs.updateValue(tab, forKey: key.lowercased()) == nil else { throw StudyWorkspaceError.invalidMembership }
            }
        } else { throw StudyWorkspaceError.invalidMembership }
        var result = StudyWorkspaceSnapshot()
        result.migratedLegacySession = true
        result.profiles = try profiles.map { profile in
            guard let name = profile["name"] as? String, let symbol = profile["icon"] as? String else { throw StudyWorkspaceError.invalidMembership }
            return .init(id: try uuid(profile["id"]), name: name, symbol: symbol, order: profile["sortOrder"] as? Int ?? 0)
        }
        result.groups = try groups.map { group in
            guard let name = group["name"] as? String, let ids = group["tabIDs"] as? [String] else { throw StudyWorkspaceError.invalidMembership }
            let documents: [ReaderDocumentTab] = try ids.map { id in
                guard var tab = tabs[id.lowercased()], let raw = tab["backend"] as? String,
                      let backend = BackendID(rawValue: raw) else { throw StudyWorkspaceError.invalidMembership }
                guard try uuid(tab["id"]) == uuid(id) else { throw StudyWorkspaceError.invalidMembership }
                tab["backendLocator"] = tab["sectionLocator"]
                tab["locator"] = tab["focusLocator"] ?? tab["sectionLocator"]
                let session = try JSONDecoder().decode(iOSReaderTabSession.self, from: JSONSerialization.data(withJSONObject: tab))
                return .init(backend: backend, session: session)
            }
            return .init(id: try uuid(group["id"]), profileID: try uuid(group["profileID"]), name: name,
                order: group["sortOrder"] as? Int ?? 0, tabs: documents,
                activeTabID: try group["activeTabID"].map(uuid))
        }
        if let scenes = object["sceneStatesByID"] as? [String: [String: Any]] {
            for (id, value) in scenes {
                result.scenes[id] = .init(profileID: try uuid(value["activeProfileID"]), groupID: try uuid(value["activeGroupID"]))
            }
        }
        if result.scenes.isEmpty {
            result.scenes["legacy-import"] = .init(profileID: try uuid(object["lastActiveProfileID"]), groupID: try uuid(object["lastActiveGroupID"]))
        }
        result.lastActiveSceneID = result.scenes.keys.sorted().first
        try result.validate()
        return result
    }
}
