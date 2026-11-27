#if os(iOS)
import SwiftUI

/// The original scene installs this downstream sheet beside its existing modal
/// presenters. It does not change a Reader, tab selection or original workspace.
struct MaktabahNativeSefariaSurfacePresentation: ViewModifier {
    let binding: MaktabahNativeSefariaSurfaceBinding?
    let session: MaktabahNativeSceneSession?
    @ObservedObject private var backend = BackendCoordinator.shared

    private struct Item: Identifiable {
        let identity: SefariaEmbeddedSurfaceIdentity
        let binding: MaktabahNativeSefariaSurfaceBinding
        let session: MaktabahNativeSceneSession
        var id: UUID { identity.id }
    }
    private var item: Item? {
        guard let binding, let session, session.mounted, session.sceneID == binding.sceneID,
              let identity = binding.presentation else { return nil }
        return .init(identity: identity, binding: binding, session: session)
    }
    func body(content: Content) -> some View {
        let original = item
        content
            .sheet(item: Binding(get: { item }, set: { next in
                // A delayed dismissal from an older sheet cannot close a newer
                // original mount. The controller also verifies its own token.
                if next == nil, let original { original.binding.dismiss(identity: original.id) }
            })) { mounted in
                OriginalSefariaSheet(identity: mounted.identity, binding: mounted.binding)
                    .environment(\.maktabahNativeRoutingSession, mounted.session)
            }
            .onChange(of: backend.activeBackendID) { _, value in
                guard value != .sefariaEmbedded, let original = item else { return }
                original.binding.dismiss(identity: original.id)
            }
    }

    private struct OriginalSefariaSheet: View {
        let identity: SefariaEmbeddedSurfaceIdentity
        let binding: MaktabahNativeSefariaSurfaceBinding
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                SefariaEmbeddedNativeSurfaceHost(identity: identity, observer: binding)
                    .modifier(MaktabahNativeRoutingSurface(kind: .sefariaEmbedded))
                    .navigationTitle(String(localized: "bootstrap.source.sefaria.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Close")) { dismiss() }
                                .accessibilityIdentifier("sefaria-original-surface-close")
                                .keyboardShortcut(.cancelAction)
                        }
                    }
            }
        }
    }
}
#endif
