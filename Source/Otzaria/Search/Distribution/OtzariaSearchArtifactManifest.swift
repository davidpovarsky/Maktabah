import Foundation

struct OtzariaSearchArtifactManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    var profileID: String? = nil
    var profileVersion: Int? = nil
    let artifactIdentity: String
    let sourceDatabase: SourceDatabase
    let lexicalEngine: LexicalEngine
    let resources: [String: Resource]
    let lexicalArtifact: LexicalArtifact
    let semantic: SemanticArtifact?

    var effectiveProfileID: String { profileID ?? OtzariaDataProfileRegistry.productionID }
    var effectiveProfileVersion: Int { profileVersion ?? 1 }

    struct SourceDatabase: Codable, Equatable, Sendable {
        let repository: String
        let releaseTag: String
        let releaseID: Int64
        let assetID: Int64
        let assetName: String
        let sourceAssetDigest: String
        let compressedBytes: Int64
        let databaseBytes: Int64
        let databaseSHA256: String
        let bookCount: Int
        let documentCount: UInt64
    }

    struct LexicalEngine: Codable, Equatable, Sendable {
        let repository: String
        let commit: String
        let engineVersion: String
        let indexSchemaVersion: UInt32
        let defaultGenerationOrder: UInt32
        let tantivyVersion: String
        let adapterVersion: String
        let semanticSidecarRevision: String
    }

    struct Resource: Codable, Equatable, Sendable {
        let version: String?
        let bytes: Int64
        let sha256: String
    }

    struct LexicalArtifact: Codable, Equatable, Sendable {
        let documentCount: UInt64
        let sourceCount: Int
        let catalogueHash: String
        let extractedBytes: Int64
        let packagedBytes: Int64
        let fileCount: Int
        let segmentsBeforeOptimize: Int
        let segmentsAfterOptimize: Int
        let parts: [Part]
    }

    struct Part: Codable, Equatable, Sendable {
        let assetName: String
        let packagedBytes: Int64
        let sha256: String
        let destinationPath: String
        let destinationOffset: Int64
        let uncompressedBytes: Int64
        let compression: String
    }

    struct SemanticArtifact: Codable, Equatable, Sendable {
        let sidecarRevision: String
        let modelRepository: String
        let modelFilename: String
        let modelSHA256: String
        let modelBytes: Int64
        let embeddingDimension: UInt32
        let recipeIdentity: String
        let storeFormatVersion: String
        let vectorCount: UInt64
        let requiredLexicalArtifactIdentity: String
        let parts: [Part]
    }
}

struct OtzariaResolvedSearchArtifact: Equatable, Sendable {
    let releaseID: Int64
    let releaseTag: String
    let manifest: OtzariaSearchArtifactManifest
    let partURLs: [String: URL]
}

enum OtzariaSearchArtifactError: LocalizedError, Equatable, Sendable {
    case unavailable
    case malformedManifest(String)
    case incompatible(String)
    case missingPart(String)
    case invalidPartPath(String)
    case insufficientStorage(required: Int64, available: Int64)
    case downloadFailed(String)
    case sizeMismatch(asset: String, expected: Int64, actual: Int64)
    case digestMismatch(asset: String)
    case extractionFailed(String)
    case validationFailed(String)
    case activationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return NSLocalizedString("חבילת חיפוש Otzaria תואמת אינה זמינה כעת.", comment: "")
        case .malformedManifest:
            return NSLocalizedString("חבילת חיפוש Otzaria לא תקינה.", comment: "")
        case .incompatible:
            return NSLocalizedString("חבילת חיפוש Otzaria אינה תואמת לספרייה זו.", comment: "")
        case .missingPart(let name):
            return String(format: NSLocalizedString("חלק חסר בחבילת החיפוש: %@.", comment: ""), name)
        case .invalidPartPath(let path):
            return String(format: NSLocalizedString("חבילת החיפוש מכילה נתיב לא בטוח: %@.", comment: ""), path)
        case .insufficientStorage(let required, let available):
            return String(format: NSLocalizedString("אין מספיק מקום פנוי להתקנת אינדקס חיפוש — נדרש %@, זמין %@.", comment: ""), Self.format(required), Self.format(available))
        case .downloadFailed(let detail):
            return String(format: NSLocalizedString("הורדת חבילת החיפוש נכשלה: %@.", comment: ""), detail)
        case .sizeMismatch(let asset, _, _):
            return String(format: NSLocalizedString("גודל שגוי בחלק שהורד: %@.", comment: ""), asset)
        case .digestMismatch(let asset):
            return String(format: NSLocalizedString("אימות SHA-256 נכשל עבור: %@.", comment: ""), asset)
        case .extractionFailed:
            return NSLocalizedString("לא ניתן לחלץ את חבילת החיפוש.", comment: "")
        case .validationFailed:
            return NSLocalizedString("אינדקס החיפוש שהותקן אינו תקין.", comment: "")
        case .activationFailed:
            return NSLocalizedString("לא ניתן להפעיל את אינדקס החיפוש באופן בטוח.", comment: "")
        case .cancelled:
            return NSLocalizedString("הורדת חבילת החיפוש בוטלה. ניתן לחדש מאוחר יותר.", comment: "")
        }
    }

    var failureReason: String? {
        switch self {
        case .malformedManifest(let detail): return detail
        case .incompatible(let detail): return detail
        case .downloadFailed(let detail): return detail
        case .extractionFailed(let detail): return detail
        case .validationFailed(let detail): return detail
        case .activationFailed(let detail): return detail
        default: return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unavailable, .incompatible:
            return NSLocalizedString("נסה לעדכן את האפליקציה לגרסה האחרונה.", comment: "")
        case .insufficientStorage:
            return NSLocalizedString("פנה מקום במכשיר ונסה שוב.", comment: "")
        case .downloadFailed, .sizeMismatch, .digestMismatch:
            return NSLocalizedString("בדוק את חיבור הרשת ונסה שוב.", comment: "")
        case .extractionFailed, .validationFailed, .activationFailed:
            return NSLocalizedString("נסה להוריד מחדש. אם הבעיה נמשכת, פנה לתמיכה.", comment: "")
        case .invalidPartPath:
            return NSLocalizedString("חבילה זו עלולה להיות פגומה. נסה להוריד מחדש.", comment: "")
        case .malformedManifest:
            return NSLocalizedString("חבילה זו אינה תקינה. נסה לעדכן את האפליקציה.", comment: "")
        case .cancelled, .missingPart:
            return nil
        }
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
