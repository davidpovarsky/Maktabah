import SwiftUI

struct EmbeddedAICitationView: View {
    let citations: [PrototypeAICitation]
    let onOpen: (PrototypeAICitation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sources", systemImage: "quote.opening")
                .font(.caption.weight(.semibold))

            ForEach(citations) { citation in
                Button {
                    onOpen(citation)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "book.pages")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(citation.title)
                                .font(.subheadline.weight(.medium))
                            Text(citation.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.forward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
}

