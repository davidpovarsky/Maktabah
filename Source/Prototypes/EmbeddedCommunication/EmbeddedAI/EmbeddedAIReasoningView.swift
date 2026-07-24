import SwiftUI

struct EmbeddedAIReasoningView: View {
    let paragraphs: [String]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Thinking", systemImage: "brain.head.profile")
                .font(.caption.weight(.semibold))
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
    }
}

