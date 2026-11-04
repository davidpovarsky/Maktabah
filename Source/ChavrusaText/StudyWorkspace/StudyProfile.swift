//
//  StudyProfile.swift
//  Maktabah
//
//  Downstream-owned model representing a Torah study profile (e.g., "אישי", "עיון", "דף היומי", "הלכה").
//

import Foundation

/// A persistent study profile that owns an ordered set of `StudyTabGroup` collections.
struct StudyProfile: Codable, Identifiable, Hashable, Sendable {
    static let defaultProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let defaultProfileName = "אישי"
    static let defaultProfileIcon = "person.crop.circle"
    static let defaultProfileColorName = "accentBlue"

    let id: UUID
    var name: String
    var icon: String
    var colorName: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = StudyProfile.defaultProfileIcon,
        colorName: String = StudyProfile.defaultProfileColorName,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
    }

    /// Creates the canonical default "אישי" profile.
    static func makeDefault(now: Date = Date()) -> StudyProfile {
        StudyProfile(
            id: defaultProfileID,
            name: defaultProfileName,
            icon: defaultProfileIcon,
            colorName: defaultProfileColorName,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            isDefault: true
        )
    }
}
