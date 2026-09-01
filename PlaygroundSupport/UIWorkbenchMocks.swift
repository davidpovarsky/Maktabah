import Foundation
import Observation
import SwiftUI
import UIKit

// Playground-only Swift stand-ins for small presentation helpers. Runtime
// services and state live in UIWorkbenchFacades.swift.

extension String {
    func convertToArabicDigits() -> String { self }
}

extension Color {
    static var appBackground: Color { Color(uiColor: .systemBackground) }
    static var appCellBackground: Color { Color(uiColor: .secondarySystemBackground) }
    static var appSecondaryBackground: Color { Color(uiColor: .tertiarySystemBackground) }
}

extension View {
    func themeListRowBackground() -> some View {
        listRowBackground(Color.appCellBackground)
    }

    func themeListBackground() -> some View {
        listRowBackground(Color.appBackground)
    }

    func themeBackground() -> some View {
        background(Color.appBackground)
    }
}
