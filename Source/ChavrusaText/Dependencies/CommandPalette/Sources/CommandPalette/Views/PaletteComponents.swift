import SwiftUI

// MARK: - Background

extension View {
    /// Liquid Glass on macOS 26 and iOS 26, a thick material with a hairline border before.
    /// Every use of a 26 API in CommandPalette goes through here, so the package runs on macOS 14
    /// and iOS 17.
    @ViewBuilder
    func paletteBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, iOS 26.0, *) {
            self
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        } else {
            self
                .clipShape(shape)
                .background(.thickMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

// MARK: - Highlighted title

/// A title with its matched characters in bold and the accent color.
struct HighlightedText: View {
    let text: String
    let highlights: [Range<Int>]

    var body: some View {
        Text(Self.attributed(text, highlights: highlights))
    }

    /// Builds the attributed title piece by piece; ranges are character offsets and may be in any
    /// order. Ranges outside the text or overlapping an earlier one are ignored.
    nonisolated static func attributed(_ text: String, highlights: [Range<Int>]) -> AttributedString {
        let characters = Array(text)
        var result = AttributedString()
        var cursor = 0
        for range in highlights.sorted(by: { $0.lowerBound < $1.lowerBound })
        where range.lowerBound >= cursor && range.upperBound <= characters.count && !range.isEmpty {
            if range.lowerBound > cursor {
                result += AttributedString(String(characters[cursor..<range.lowerBound]))
            }
            var match = AttributedString(String(characters[range]))
            match.inlinePresentationIntent = .stronglyEmphasized
            match.foregroundColor = Color.accentColor
            result += match
            cursor = range.upperBound
        }
        if cursor < characters.count {
            result += AttributedString(String(characters[cursor...]))
        }
        return result
    }
}

// MARK: - Key caps

/// One key of a shortcut hint: "⌘", "N", "esc".
struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, label.count > 1 ? 4 : 0)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
    }
}

/// A shortcut as a row of key caps: ⇧ ⌘ N.
struct ShortcutHint: View {
    let shortcut: CommandShortcut

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(shortcut.keyCaps.enumerated()), id: \.offset) { _, cap in
                KeyCap(label: cap)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Shortcut \(shortcut.displayString)"))
    }
}

// MARK: - Row

/// One command in the list.
struct CommandRowView: View {
    let item: CommandPaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.command.symbol ?? "command")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                .frame(width: 30, height: 30)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                HighlightedText(text: item.command.title, highlights: item.titleHighlights)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle = item.command.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if let shortcut = item.command.shortcut {
                ShortcutHint(shortcut: shortcut)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 46)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A section header in the list.
struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
