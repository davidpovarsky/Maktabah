//
//  StudyTabGroup.swift
//  Maktabah
//
//  Downstream-owned model representing a named group of reader document tabs within a StudyProfile.
//

import Foundation

/// A named collection of `ReaderDocumentTab` identifiers belonging to a specific `StudyProfile`.
public struct StudyTabGroup: Codable, Identifiable, Hashable, Sendable {
    public static let defaultGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    public static let defaultGroupName = "לימוד ראשי"

    public let id: UUID
    public var profileID: UUID
    public var name: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var tabIDs: [UUID]
    public var activeTabID: UUID?
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        name: String,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tabIDs: [UUID] = [],
        activeTabID: UUID? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tabIDs = tabIDs
        self.activeTabID = activeTabID
        self.isPinned = isPinned
    }

    /// Creates the default initial tab group for a profile.
    public static func makeDefault(
        profileID: UUID = StudyProfile.defaultProfileID,
        name: String = StudyTabGroup.defaultGroupName,
        tabIDs: [UUID] = [],
        activeTabID: UUID? = nil,
        now: Date = Date()
    ) -> StudyTabGroup {
        StudyTabGroup(
            id: profileID == StudyProfile.defaultProfileID ? defaultGroupID : UUID(),
            profileID: profileID,
            name: name,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            tabIDs: tabIDs,
            activeTabID: activeTabID ?? tabIDs.first,
            isPinned: false
        )
    }
}
