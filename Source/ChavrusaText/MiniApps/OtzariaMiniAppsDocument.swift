import Foundation
import HanlinMiniAppsBridge

/// A restorable reference to the original annotation. The source book is never edited.
struct OtzariaMiniAppsDocument: Codable, Equatable, Sendable {
    static let metadataKey = "otzaria.annotation.v1"
    let profile: String
    let annotationID: Int64?
    let annotationUUID: String
    let bookID: Int
    let contentID: Int
    let rangeLocation: Int
    let rangeLength: Int
    let diacriticsLocation: Int
    let diacriticsLength: Int
    let context: String
    let page: Int
    let part: Int
    let color: String
    let annotationType: Int
    let createdAt: Int64
    let originalNote: String?
    let draftNote: String
    let tags: [String]
    let locatorJSON: String?
    let title: String
    let isReaderSelection: Bool
    let editorID: UUID?
    let selection: MiniAppTextSelection?

    var metadata: [String: String] {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return [Self.metadataKey: String(decoding: try encoder.encode(self), as: UTF8.self)]
        }
    }

    static func restore(from source: MiniAppSourceContext) throws -> Self {
        guard let value = source.metadata[metadataKey], let data = value.data(using: .utf8) else {
            throw OtzariaMiniAppsError.missingDocument
        }
        return try JSONDecoder().decode(Self.self, from: data)
    }

    func editedText(_ result: MiniAppResult, attachmentURLs: [UUID: URL] = [:]) throws -> String {
        let items = try result.items.map { item -> MiniAppContent in
            if let text = item.text { return .init(kind: .text, text: text) }
            if let url = item.url { return .init(kind: .text, text: url.absoluteString) }
            if let id = item.attachmentID {
                guard let url = attachmentURLs[id] else { throw MiniAppBridgeError.invalidAttachment }
                return .init(kind: .text, text: url.absoluteString)
            }
            return .init(kind: .text, text: "")
        }
        // A transformation of a read-only quotation becomes its attached note.
        // The selection coordinates belong to the quotation, not to the note.
        let operation: MiniAppOperation = isReaderSelection && result.operation == .replaceSelection
            ? .replaceDocument : result.operation
        let normalized = MiniAppResult(requestID: result.requestID, status: result.status,
            operation: operation, items: items, message: result.message, metadata: result.metadata)
        return try MiniAppTextEditing.applying(normalized, to: draftNote, selection: selection)
    }
}

enum OtzariaMiniAppsError: LocalizedError {
    case missingDocument, changedDocument, differentLibrary, unavailable, noResult
    var errorDescription: String? {
        switch self {
        case .missingDocument:
            NSLocalizedString("The original note could not be found.", comment: "MiniApps bridge error")
        case .changedDocument:
            NSLocalizedString("The note changed while the Mini App was open. Your result is kept in MiniApps.", comment: "MiniApps bridge error")
        case .differentLibrary:
            NSLocalizedString("Open the original library to receive this Mini App result.", comment: "MiniApps bridge error")
        case .unavailable:
            NSLocalizedString("Hanlin MiniApps could not be opened.", comment: "MiniApps bridge error")
        case .noResult:
            NSLocalizedString("The Mini App did not return any content.", comment: "MiniApps bridge error")
        }
    }
}
