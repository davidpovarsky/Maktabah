import SwiftUI

struct EmbeddedAIContextHeader: View {
    let context: PrototypeHostContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(context.compactTitle, systemImage: "book.closed")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if let excerpt = context.excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                Text("Book #\(context.identifier)")
                if let detail = context.detail {
                    Text(detail)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(context.accessibilitySummary)
    }
}
