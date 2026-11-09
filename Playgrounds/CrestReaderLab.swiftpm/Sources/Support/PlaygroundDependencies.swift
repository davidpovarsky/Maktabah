import SwiftUI
import UIKit
import OSLog
import Foundation

// BACKEND-ONLY FIXTURES. The included Original folders retain upstream UI sources.
extension Logger {
    static let app = Logger(subsystem: "CrestReaderLab", category: "font")
}

struct SpaceBranding {
    let primaryColor: Color
}
struct SpaceLook {
    let shown: SpaceBranding
}
struct SpaceSettings {
    let look: SpaceLook
}
struct SpaceModel: Identifiable {
    let id: UUID
    var name: String
    var accent: Color
    var settings: SpaceSettings {
        SpaceSettings(look: SpaceLook(shown: SpaceBranding(primaryColor: accent)))
    }
}
struct BrowserSpaceBannerBackground: View {
    let branding: SpaceBranding
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.13, blue: 0.18),
                Color(red: 0.15, green: 0.20, blue: 0.27),
                branding.primaryColor.opacity(0.55)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
struct SpaceBackdropBlend<Content: View>: View {
    let spaces: [SpaceModel]
    let selectedSpace: SpaceModel?
    @ViewBuilder let content: (SpaceModel?) -> Content
    var body: some View { content(selectedSpace) }
}
enum CrestOpacity { static let chromeSurface = 0.16 }
extension LayoutDirection {
    func leadingOffset(_ value: CGFloat) -> CGFloat {
        self == .leftToRight ? value : -value
    }
}

enum AnnotationMode { case highlight, underline }
struct Annotation {
    let id: Int64?
    let range: NSRange
    let rangeDiacritics: NSRange
    let type: AnnotationMode
    let colorHex: String
}
enum LibraryReaderTextMode: String { case original }

extension Notification.Name {
    static let didChangeHarakat = Notification.Name("didChangeHarakat")
    static let didChangeLineHeight = Notification.Name("didChangeLineHeight")
    static let didChangeFont = Notification.Name("didChangeFont")
    static let didChangeBackground = Notification.Name("didChangeBackground")
    static let didChangeClickableAnnotation = Notification.Name("didChangeClickableAnnotation")
    static let didChangeEnhancedUnderline = Notification.Name("didChangeEnhancedUnderline")
}
extension NSAttributedString.Key {
    static let enhancedUnderline = NSAttributedString.Key("enhancedUnderline")
}

extension UserDefaults {
    var textViewShowHarakat: Bool {
        get { object(forKey: "textViewShowHarakat") == nil ? true : bool(forKey: "textViewShowHarakat") }
        set { set(newValue, forKey: "textViewShowHarakat") }
    }
    var lineHeight: Double {
        get { let v = double(forKey: "lineHeight"); return v > 0 ? v : 1.2 }
        set { set(newValue, forKey: "lineHeight") }
    }
    var textViewFontSize: Float {
        get { let v = float(forKey: "textViewFontSize"); return v > 0 ? v : 24 }
        set { set(newValue, forKey: "textViewFontSize") }
    }
    var textViewFontName: String {
        get { string(forKey: "textViewFontName") ?? "Arial Hebrew" }
        set { set(newValue, forKey: "textViewFontName") }
    }
    var textViewBackgroundColorLight: Int {
        get { integer(forKey: "backgroundLight") }
        set { set(newValue, forKey: "backgroundLight") }
    }
    var enableAnnotationClick: Bool {
        get { bool(forKey: "enableAnnotationClick") }
        set { set(newValue, forKey: "enableAnnotationClick") }
    }
    var libraryReaderTextMode: LibraryReaderTextMode {
        get { .original }
        set { }
    }
    var textViewEnhancedUnderline: Bool {
        get { bool(forKey: "textViewEnhancedUnderline") }
        set { set(newValue, forKey: "textViewEnhancedUnderline") }
    }
    static let maxRecentColors = 5
    var recentHighlightColors: [UIColor] {
        get { [.yellow, .systemGreen, .systemOrange] }
        set { }
    }
    var recentUnderlineColors: [UIColor] {
        get { [.label] }
        set { }
    }
}

extension UIColor {
    static let header: UIColor = .systemBlue
    static let bgSepia = UIColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1)
    static let bgGray = UIColor(white: 0.90, alpha: 1)
    static let bgSepiaDark = UIColor(red: 0.24, green: 0.21, blue: 0.18, alpha: 1)
    static let bgDark = UIColor(white: 0.10, alpha: 1)
    var accessibilityName: String { hexString() }
}
extension Color {
    static let bgSepia = Color(uiColor: .bgSepia)
    static let bgGray = Color(uiColor: .bgGray)
    static let bgSepiaDark = Color(uiColor: .bgSepiaDark)
    static let bgDark = Color(uiColor: .bgDark)
}

enum TabaqaGroup {
    static let mappingRowiKutub: [String: String] = [:]
    static let replacementRowiMapping: [String: String] = [:]
    static let tabaqaMapping: [String: String] = [:]
    static let replacementSheokMapping: [String: String] = [:]
}
struct CleanedTextResult {
    let text: String
    let coloredRanges: [NSRange]
}
struct TextDeltaEvent {
    let oldOffset: Int
    let delta: Int
    static func mapRange(_ range: NSRange, with events: [Self]) -> NSRange {
        let start = forward(range.location, events: events)
        let end = forward(range.location + range.length, events: events)
        return NSRange(location: start, length: max(0, end - start))
    }
    static func reverseMapOffset(_ displayOffset: Int, with events: [Self]) -> Int {
        var oldDelta = 0
        for event in events {
            let newOffset = event.oldOffset + event.delta
            guard displayOffset >= newOffset else { break }
            oldDelta = event.delta
        }
        return max(0, displayOffset - oldDelta)
    }
    private static func forward(_ sourceOffset: Int, events: [Self]) -> Int {
        var delta = 0
        for event in events {
            if sourceOffset >= event.oldOffset { delta = event.delta }
            else { break }
        }
        return max(0, sourceOffset + delta)
    }
}
final class BookPageCache {
    static let shared = BookPageCache()
    private init() {}
    func getProcessed(bookId: Int, contentId: Int, key: CleanedTextKey) -> ProcessedArabicContent? { nil }
    func setProcessed(bookId: Int, contentId: Int, key: CleanedTextKey, content: ProcessedArabicContent) {}
}
