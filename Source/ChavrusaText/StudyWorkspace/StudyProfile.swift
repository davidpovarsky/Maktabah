//
//  StudyProfile.swift
//  Maktabah
//
//  Downstream-owned model representing a Torah study profile (e.g., "אישי", "עיון", "דף היומי", "הלכה").
//

import Foundation

/// A persistent study profile that owns an ordered set of `StudyTabGroup` collections.
public struct StudyProfile: Codable, Identifiable, Hashable, Sendable {
    public static let defaultProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let defaultProfileName = "אישי"
    public static let defaultProfileIcon = "person.crop.circle"
    public static let defaultProfileColorName = "accentBlue"

    public let id: UUID
    public var name: String
    public var icon: String
    public var colorName: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var isDefault: Bool

    public init(
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
    public static func makeDefault(now: Date = Date()) -> StudyProfile {
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
