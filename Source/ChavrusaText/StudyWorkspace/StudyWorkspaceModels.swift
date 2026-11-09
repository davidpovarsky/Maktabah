import Foundation

struct StudyProfile: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var symbol: String
    var order: Int
}

struct ReaderDocumentTab: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { session.id }
    var backend: BackendID
    var session: iOSReaderTabSession

    func reidentified() -> ReaderDocumentTab {
        let s = session
        return .init(backend: backend, session: .init(
            id: UUID(), bookId: s.bookId, bookTitle: s.bookTitle, backendLocator: s.backendLocator,
            contentId: s.contentId, locator: s.locator, page: s.page, part: s.part, scrollPosition: s.scrollPosition,
            selectedRange: s.selectedRange, expandedNodeIDs: s.expandedNodeIDs, sidebarScrollPosition: s.sidebarScrollPosition,
            isSidebarCollapsed: s.isSidebarCollapsed, searchText: s.searchText, searchModeRaw: s.searchModeRaw,
            nearDistance: s.nearDistance, highlightTerms: s.highlightTerms))
    }
}

struct StudyTabGroup: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var profileID: UUID
    var name: String
    var order: Int
    var tabs: [ReaderDocumentTab]
    var activeTabID: UUID?
}

enum StudyWorkspaceProjectionPolicy {
    /// Replace the live backend's slots in order without moving foreign-source
    /// documents to the front whenever a reading checkpoint is saved.
    static func merging(live: [ReaderDocumentTab], into saved: [ReaderDocumentTab], backend: BackendID) -> [ReaderDocumentTab] {
        let liveIDs = Set(live.map(\.id))
        var next = 0
        var result: [ReaderDocumentTab] = []
        for document in saved {
            if document.backend != backend {
                result.append(document)
            } else if liveIDs.contains(document.id), live.indices.contains(next) {
                result.append(live[next])
                next += 1
            }
        }
        result.append(contentsOf: live.dropFirst(next))
        return result
    }

    static func backend(restoring committedBackend: BackendID?, requestedID: UUID?, documents: [ReaderDocumentTab], fallback: BackendID) -> BackendID {
        // Startup respects the canonical backend owner's committed source.
        // An explicit group/document selection may request another source.
        committedBackend ?? documents.first(where: { $0.id == requestedID })?.backend ?? documents.first?.backend ?? fallback
    }
}

struct StudySceneSelection: Codable, Equatable, Sendable {
    var profileID: UUID
    var groupID: UUID
    var activeTabIDsByGroup: [UUID: UUID]? = nil
}

struct StudyWorkspaceSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1
    var version = currentVersion
    var revision: UInt64 = 0
    var migratedLegacySession = false
    var profiles: [StudyProfile] = []
    var groups: [StudyTabGroup] = []
    var scenes: [String: StudySceneSelection] = [:]
    /// Startup fallback for a newly created/restored system scene; an exact
    /// existing scene selection always wins. Optional for existing v1 files.
    var lastActiveSceneID: String? = nil

    func validate() throws {
        guard version == Self.currentVersion else { throw StudyWorkspaceError.unsupportedVersion }
        guard lastActiveSceneID.map({ scenes[$0] != nil }) ?? true else { throw StudyWorkspaceError.invalidMembership }
        guard !profiles.isEmpty, !groups.isEmpty,
              Set(profiles.map(\.id)).count == profiles.count,
              Set(groups.map(\.id)).count == groups.count else { throw StudyWorkspaceError.invalidMembership }
        let profileIDs = Set(profiles.map(\.id))
        guard profiles.allSatisfy({ profile in
            !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && groups.contains(where: { $0.profileID == profile.id })
        }), groups.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw StudyWorkspaceError.invalidMembership
        }
        let allTabIDs = groups.flatMap { $0.tabs.map(\.id) }
        guard Set(allTabIDs).count == allTabIDs.count else { throw StudyWorkspaceError.invalidMembership }
        for group in groups {
            guard profileIDs.contains(group.profileID),
                  Set(group.tabs.map(\.id)).count == group.tabs.count,
                  group.activeTabID.map({ id in group.tabs.contains { $0.id == id } }) ?? true
            else { throw StudyWorkspaceError.invalidMembership }
            for tab in group.tabs {
                guard tab.session.backendLocator.map({ $0.backend == tab.backend }) ?? true,
                      tab.session.locator.map({ $0.backend == tab.backend }) ?? true else { throw StudyWorkspaceError.backendMismatch }
            }
        }
        for selection in scenes.values {
            guard groups.contains(where: { $0.id == selection.groupID && $0.profileID == selection.profileID })
            else { throw StudyWorkspaceError.invalidMembership }
        }
    }
}

enum StudyWorkspaceError: Error, LocalizedError {
    case unsupportedVersion, invalidMembership, unavailableBook, backendMismatch, groupNotEmpty, lastProfile, lastGroup
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "גרסת קובץ סביבת הלימוד אינה נתמכת. הנתונים נשמרו."
        case .invalidMembership: "לא ניתן לקרוא את סביבת הלימוד. הנתונים הקיימים נשמרו."
        case .unavailableBook: "ספר בקבוצה אינו זמין כעת. קבוצת הכרטיסיות הנוכחית נשמרה."
        case .backendMismatch: "זהות הספר אינה תואמת למקור הספרייה המבוקש. סביבת הלימוד נשמרה."
        case .groupNotEmpty: "הקבוצה מכילה כרטיסיות."
        case .lastProfile: "יש להשאיר לפחות פרופיל אחד."
        case .lastGroup: "יש להשאיר לפחות קבוצת כרטיסיות אחת בפרופיל."
        }
    }
}
