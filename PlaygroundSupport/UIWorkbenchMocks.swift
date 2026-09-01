import Foundation
import Observation
import SwiftUI
import UIKit

// Playground-only Swift stand-ins for application services/data. The goal is
// to let the real production Views compile and render without databases,
// downloaders, native search engines, CloudKit, or other runtime backends.

extension String {
    var localized: String { self }
    func convertToArabicDigits() -> String { self }
}

extension Color {
    static var appBackground: Color { Color(uiColor: .systemBackground) }
    static var appCellBackground: Color { Color(uiColor: .secondarySystemBackground) }
}

extension View {
    func themeListRowBackground() -> some View {
        listRowBackground(Color.appCellBackground)
    }

    func themeListBackground() -> some View {
        listRowBackground(Color.appBackground)
    }
}
