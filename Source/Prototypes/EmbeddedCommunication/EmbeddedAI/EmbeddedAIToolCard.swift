import SwiftUI

struct EmbeddedAIToolCard: View {
    let action: PrototypeAIToolAction
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(action.title, systemImage: "magnifyingglass")
                .font(.caption.weight(.semibold))
            Text(action.result)
                .font(.subheadline)
            Button(action.buttonTitle, action: onOpen)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
}
