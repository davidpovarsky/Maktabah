#if MAKTABAH_SWIFTPM_CI || MAKTABAH_PLAYGROUND_STRINGS_SHIM
import Foundation
import SwiftUI
#endif

#if MAKTABAH_SWIFTPM_CI
import UIKit

// MARK: - Xcode generated asset symbol compatibility
//
// Plain `swift build` does not synthesize typed symbols for asset catalogs, so
// CI supplies only the symbols that production source already uses. The real
// App Playground still lets Xcode/Playgrounds synthesize its asset symbols.

private extension UIColor {
    static func playgroundAsset(_ name: String, fallback: UIColor) -> UIColor {
        UIColor(named: name, in: .module, compatibleWith: nil) ?? fallback
    }
}

extension UIColor {
    static let bgSepia = playgroundAsset(
        "BgSepia",
        fallback: UIColor(red: 237.0 / 255.0, green: 217.0 / 255.0, blue: 184.0 / 255.0, alpha: 1)
    )
    static let bgSepiaDark = playgroundAsset(
        "BgSepiaDark",
        fallback: UIColor(red: 76.0 / 255.0, green: 67.0 / 255.0, blue: 56.0 / 255.0, alpha: 1)
    )
    static let bgGray = playgroundAsset("BgGray", fallback: .systemGray5)
    static let bgDark = playgroundAsset("BgDark", fallback: .systemGray)
    static let iosTint = playgroundAsset("iosTint", fallback: .systemBlue)
    static let header = playgroundAsset("HeaderColor", fallback: .label)
    static let highlightBlue = playgroundAsset("HighlightBlue", fallback: .systemBlue)
    static let highlightText = playgroundAsset("HighlightText", fallback: .systemYellow)
}

extension Color {
    static let bgSepia = Color(uiColor: .bgSepia)
    static let bgSepiaDark = Color(uiColor: .bgSepiaDark)
    static let bgGray = Color(uiColor: .bgGray)
    static let bgDark = Color(uiColor: .bgDark)
    static let iosTint = Color(uiColor: .iosTint)
    static let header = Color(uiColor: .header)
    static let highlightBlue = Color(uiColor: .highlightBlue)
    static let highlightText = Color(uiColor: .highlightText)
}
#endif

#if MAKTABAH_SWIFTPM_CI || MAKTABAH_PLAYGROUND_STRINGS_SHIM
// MARK: - Xcode generated String Catalog symbol compatibility
//
// Swift Playgrounds on iPad cannot currently process Localizable.xcstrings in
// this package because it resolves xcstringstool to /xcstringstool. These are
// the same generated member names the production source expects, kept strictly
// in Playground/CI support code rather than copied UI source.

extension LocalizedStringKey {
    static var annotation: Self { "Annotation" }
    static var annotationMoveFolderFileExistsTitle: Self { "A folder with this name already exists." }
    static var annotationsMoveFolderFileExistsDesc: Self { "The annotations will be merged into the existing folder." }
    static var bookMissingOnAnnotationClick: Self { "The book associated with this annotation is missing." }
    static var close: Self { "Close" }
    static var convertImportHelpDesc: Self { "Convert a book database into a format that Maktabah can import." }
    static var convertImportHelpTitle: Self { "Converter Tool & Help" }
    static var exactSearchTitle: Self { "Exact Search" }
    static var filterByBooks: Self { ".filterByBooks" }
    static var importSuccessDesc: Self { "importSuccessDesc" }
    static var keepExistingDeleteOld: Self { "Keep Existing, Delete Old" }
    static var moreOptions: Self { ".moreOptions" }
    static var optimization: Self { "Optimization" }
    static var optimizationIsNeededToReclaimDiskSpaceAfterDeletingBooks: Self {
        "Optimization is needed to reclaim disk space after deleting books."
    }
    static var optimizeDatabase: Self { "Optimize Database" }
    static var overwriteExisting: Self { "Overwrite Existing" }
    static var searchInSelectedBooks: Self { "Search in Selected Books" }
    static var searchInThisBook: Self { "Search in This Book" }
    static var searchOptionsHelp: Self { "Search Options Help" }
    static var separateWordsSearchTitle: Self { "Separate Words Search" }

    static func bookNotFound(bookID: Int) -> Self {
        "Book with ID \(bookID) not found."
    }

    static func bulkBookDownloadAlert(totalBook: Int) -> Self {
        "\(totalBook) books to download."
    }
}

extension String.LocalizationValue {
    static var annotation: Self { "Annotation" }
    static var annotationMoveFolderFileExistsTitle: Self { "A folder with this name already exists." }
    static var annotationsMoveFolderFileExistsDesc: Self { "The annotations will be merged into the existing folder." }
    static var bookMissingOnAnnotationClick: Self { "The book associated with this annotation is missing." }
    static var close: Self { "Close" }
    static var convertImportHelpDesc: Self { "Convert a book database into a format that Maktabah can import." }
    static var convertImportHelpTitle: Self { "Converter Tool & Help" }
    static var exactSearchTitle: Self { "Exact Search" }
    static var filterByBooks: Self { ".filterByBooks" }
    static var importSuccessDesc: Self { "importSuccessDesc" }
    static var keepExistingDeleteOld: Self { "Keep Existing, Delete Old" }
    static var moreOptions: Self { ".moreOptions" }
    static var optimization: Self { "Optimization" }
    static var optimizationIsNeededToReclaimDiskSpaceAfterDeletingBooks: Self {
        "Optimization is needed to reclaim disk space after deleting books."
    }
    static var optimizeDatabase: Self { "Optimize Database" }
    static var overwriteExisting: Self { "Overwrite Existing" }
    static var searchInSelectedBooks: Self { "Search in Selected Books" }
    static var searchInThisBook: Self { "Search in This Book" }
    static var searchOptionsHelp: Self { "Search Options Help" }
    static var separateWordsSearchTitle: Self { "Separate Words Search" }

    static func bookNotFound(bookID: Int) -> Self {
        "Book with ID \(bookID) not found."
    }

    static func bulkBookDownloadAlert(totalBook: Int) -> Self {
        "\(totalBook) books to download."
    }
}
#endif
