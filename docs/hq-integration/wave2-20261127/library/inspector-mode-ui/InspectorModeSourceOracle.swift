import Foundation
import CryptoKit

// Converts one retained, real default Sefaria response with the unchanged
// production DTO/section/presentation models. This produces a source oracle;
// it does not launch Maktabah or assert any native UI result.
@main
struct InspectorModeSourceOracle {
    static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    static func body(_ text: String) -> [String: Any] {
        ["sha256": hash(Data(text.utf8)), "utf8Bytes": text.utf8.count]
    }
    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let raw = try Data(contentsOf: root.appendingPathComponent("psalms35-default-response.json"))
        let receiptBytes = try Data(contentsOf: root.appendingPathComponent("psalms35-default-response-receipt.json"))
        let receipt = try JSONSerialization.jsonObject(with: receiptBytes) as! [String: Any]
        let url = "https://www.sefaria.org/api/v3/texts/Psalms%2035?version=source&version=translation&fill_in_missing_segments=1&return_format=text_only"
        precondition(receipt["url"] as? String == url && receipt["finalURL"] as? String == url)
        precondition(receipt["status"] as? Int == 200 && receipt["bytes"] as? Int == raw.count)
        precondition(receipt["sha256"] as? String == hash(raw))
        let dto = try JSONDecoder().decode(SefariaTextsV3DTO.self, from: raw)
        precondition(dto.ref == "Psalms 35" && dto.sectionRef == "Psalms 35" && dto.indexTitle == "Psalms")
        let heRef = dto.heRef!
        precondition(heRef == "תהילים ל״ה")
        let source = dto.versions.filter { $0.isSource == true }
        let translated = dto.versions.filter { $0.isSource == false && $0.language == "en" }
        precondition(source.count == 1 && translated.count == 1 && dto.versions.count == 2)
        let section = SefariaSection(ref: dto.ref, heRef: dto.heRef, sectionRef: dto.sectionRef,
            indexTitle: dto.indexTitle, next: dto.next, prev: dto.prev, versions: dto.versions,
            linksBySegment: [], origin: .remote).asLibrarySection()
        precondition(section.segments.count == 28)
        let primary = source[0].text!.segmentStrings
        let translation = translated[0].text!.segmentStrings
        precondition(primary.count == 28 && translation.count == 28)
        var rows: [[String: Any]] = []
        for (index, segment) in section.segments.enumerated() {
            precondition(segment.primaryText == primary[index] && segment.translation == translation[index])
            precondition(!segment.primaryText.readerPlainText.isEmpty && !(segment.translation ?? "").readerPlainText.isEmpty)
            var mapped: [String: Any] = [:]
            for mode in LibraryReaderTextMode.allCases {
                mapped[mode.rawValue] = body(LibraryPresentationPolicy.text(
                    source: segment.primaryText, translation: segment.translation, mode: mode).readerPlainText)
            }
            rows.append(["canonicalRef": "Psalms 35:\(index + 1)", "locator": segment.locator.persistenceKey,
                         "heRef": segment.heRef!, "bodies": mapped])
        }
        var modes: [String: Any] = [:]
        for mode in LibraryReaderTextMode.allCases {
            let bodies = section.segments.map {
                LibraryPresentationPolicy.text(source: $0.primaryText, translation: $0.translation, mode: mode).readerPlainText
            }
            let version = mode == .translation ? translated[0] : source[0]
            let rendered = LibraryReaderRenderModel(section: section, preferredMode: mode)
            precondition(rendered.mode == mode && rendered.renderedSegments.count == 28)
            modes[mode.rawValue] = [
                "displayReferenceInHebrewUI": mode == .translation ? dto.sectionRef : heRef,
                "selectedUnitQuote": body(bodies.joined(separator: "\n")),
                "readerModelBody": body(rendered.text),
                "sourceVersionTitle": version.versionTitle,
                "sourceVersionLanguage": version.language,
                "sourceVersionLicense": version.license ?? "",
                "versionScope": "qualified-source-metadata; Kit has no displayed version field"
            ]
        }
        let oracle: [String: Any] = [
            "schema": 1, "status": "ACTUAL_DEFAULT_SEFARIA_SOURCE_ORACLE_ONLY_NOT_UI", "uiExecuted": false,
            "sourceContractRevision": "991526228533d6689c4ad9da8dbd3e9f82a7bea1",
            "kitRevision": "23db0f84e88d9ee9c7053c49de86903fc7bb5785",
            "requestURL": url, "canonicalReference": dto.sectionRef, "hebrewReference": heRef,
            "workKey": dto.indexTitle, "canonicalLocator": section.locator.persistenceKey,
            "response": ["relativePath": "psalms35-default-response.json", "bytes": raw.count, "sha256": hash(raw)],
            "responseReceipt": ["relativePath": "psalms35-default-response-receipt.json", "bytes": receiptBytes.count, "sha256": hash(receiptBytes)],
            "sourceReceipt": receipt,
            "sourceVersionTitle": source[0].versionTitle, "translationVersionTitle": translated[0].versionTitle,
            "segments": rows, "modes": modes,
            "uiScope": "future original selected-unit quote accessibility label is complete; its visual Text is capped at two lines; no invisible version-field claim"
        ]
        let bytes = try JSONSerialization.data(withJSONObject: oracle, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        precondition(!FileManager.default.fileExists(atPath: output.path))
        try bytes.write(to: output, options: .withoutOverwriting)
        print("ORACLE_BYTES \(bytes.count) SHA256 \(hash(bytes))")
    }
}
