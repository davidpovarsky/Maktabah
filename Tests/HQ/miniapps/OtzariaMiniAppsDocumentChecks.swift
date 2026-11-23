import Foundation
import HanlinMiniAppsBridge

@main
enum OtzariaMiniAppsDocumentChecks {
    static func main() throws {
        var passed = 0
        func check(_ value: @autoclosure () throws -> Bool, _ name: String) throws {
            guard try value() else { throw NSError(domain: name, code: 1) }
            passed += 1
            print("PASS " + name)
        }
        func document(reader: Bool = false, text: String = "שלום 🌟 עולם",
                      selection: MiniAppTextSelection? = .init(location: 5, length: 2, text: "🌟")) -> OtzariaMiniAppsDocument {
            .init(profile: "/original/Annotations.sqlite", annotationID: reader ? nil : 37,
                annotationUUID: "A200F438-6170-4BBD-8CFC-5803B7C26F1D", bookID: -23, contentID: 51,
                rangeLocation: 91, rangeLength: 12, diacriticsLocation: 102, diacriticsLength: 14,
                context: "מקור עברי", page: 4, part: 1, color: "#FFFFFF", annotationType: 0,
                createdAt: 1740000000, originalNote: reader ? nil : text, draftNote: reader ? "" : text,
                tags: ["מקור", "study"], locatorJSON: "{\"workKey\":\"Berakhot\"}", title: "ברכות",
                isReaderSelection: reader, editorID: nil, selection: reader ? nil : selection)
        }
        let note = document()
        let source = MiniAppSourceContext(appID: "com.davidpovarsky.chavrusatext", displayName: "Otzaria",
            metadata: try note.metadata)
        try check(try OtzariaMiniAppsDocument.restore(from: source) == note, "cold_capture_roundtrip_hebrew_anchor_profile")
        let replace = MiniAppResult(requestID: UUID(), operation: .replaceSelection,
            items: [.init(kind: .text, text: "חדש")])
        try check(try note.editedText(replace) == "שלום חדש עולם", "actual_note_utf16_selection_replacement")
        try check(try document(reader: true).editedText(replace) == "חדש",
            "read_only_reader_selection_returns_annotation_not_book")
        let insert = MiniAppResult(requestID: UUID(), operation: .insert, items: [.init(kind: .text, text: "!")])
        try check(try note.editedText(insert) == "שלום 🌟! עולם", "insertion_uses_original_note_selection")
        let clear = MiniAppResult(requestID: UUID(), operation: .replaceDocument, items: [.init(kind: .text, text: "")])
        try check(try note.editedText(clear).isEmpty, "empty_document_replacement_is_retained")
        let url = URL(string: "https://example.org/source")!
        let linked = MiniAppResult(requestID: UUID(), operation: .replaceDocument, items: [.init(kind: .url, url: url)])
        try check(try note.editedText(linked) == url.absoluteString, "url_result_is_preserved_in_plain_note")
        let attachmentID = UUID(), localFile = URL(fileURLWithPath: "/Documents/MiniApps/file.pdf")
        let file = MiniAppResult(requestID: UUID(), operation: .replaceDocument,
            items: [.init(kind: .file, attachmentID: attachmentID, name: "file.pdf")])
        try check(try note.editedText(file, attachmentURLs: [attachmentID: localFile]) == localFile.absoluteString,
            "attachment_result_references_host_retained_file")
        do {
            _ = try note.editedText(file)
            throw NSError(domain: "missing_file_should_fail", code: 1)
        } catch MiniAppBridgeError.invalidAttachment {
            passed += 1; print("PASS missing_file_never_becomes_empty_note")
        }
        do {
            _ = try document(selection: .init(location: 5, length: 2, text: "X")).editedText(replace)
            throw NSError(domain: "changed_selection_should_fail", code: 1)
        } catch MiniAppBridgeError.selectionChanged {
            passed += 1; print("PASS changed_original_selection_preserved")
        }
        let display = MiniAppResult(requestID: UUID(), operation: .display, items: [.init(kind: .text, text: "view")])
        try check(try note.editedText(display) == note.draftNote, "display_operation_does_not_edit_document")
        print("RESULT \(passed) PASS / 0 FAIL")
    }
}
