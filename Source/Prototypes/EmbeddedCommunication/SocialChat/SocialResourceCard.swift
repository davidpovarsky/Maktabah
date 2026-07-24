import SwiftUI

struct SocialResourceCard: View {
    let kind: PrototypeSocialCardKind
    let onAction: (String) -> Void

    var body: some View {
        Group {
            switch kind {
            case .resource:
                resourceCard
            case .image:
                imageCard
            }
        }
        .frame(maxWidth: 360)
        .padding(.vertical, 4)
    }

    private var resourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 42, height: 42)
                    .background(.tint.opacity(0.12), in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("מסכת שבת כ״א ע״ב")
                        .font(.headline)
                    Text("״מאי חנוכה…״")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Text("Shared from Maktabah")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Open source") {
                    onAction("Would open the shared source in Maktabah.")
                }
                .buttonStyle(.bordered)
                Button("Ask AI") {
                    onAction("Would open AI Assistant with this source attached.")
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary)
        }
    }

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                LinearGradient(
                    colors: [.brown.opacity(0.8), .orange.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(height: 150)
            .clipShape(.rect(cornerRadius: 14))

            Text("Photo from our study table")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mock image from the study table")
    }
}

