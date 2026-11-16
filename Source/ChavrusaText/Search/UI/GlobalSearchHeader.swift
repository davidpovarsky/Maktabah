import SwiftUI

struct GlobalSearchHeader: View {
    @Bindable var session: UnifiedSearchSessionController
    @Environment(\.globalSearchBookChooser) private var showBookSidebar
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Semantic leading/trailing mirrors naturally in RTL: options sit left of the field.
            HStack(spacing: 12) {
                NativeGlobalSearchField(text: $session.query, onSubmit: onSubmit)
                    .frame(maxWidth: .infinity)
                Button {
                    session.showsAdvancedOptions = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("אפשרויות חיפוש")
                .accessibilityIdentifier("global-search-options")
                .popover(isPresented: $session.showsAdvancedOptions) {
                    GlobalSearchAdvancedOptionsContent(session: session)
                        .frame(idealWidth: 420, idealHeight: 620)
                        .presentationCompactAdaptation(.sheet)
                        .presentationDetents([.large])
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Button {
                    if let showBookSidebar { showBookSidebar() }
                    else { session.showsBookFilterSheet = true }
                } label: {
                    Label(session.selectedBookIds.isEmpty ? "כל הספרים" : "\(session.selectedBookIds.count) ספרים נבחרו",
                          systemImage: "book")
                }
                .accessibilityIdentifier("global-search-books")
                Spacer(minLength: 8)
                Menu {
                    ForEach(session.availableScopes) { scope in
                        Button {
                            session.scope = scope
                        } label: {
                            if session.scope == scope { Label(scope.title, systemImage: "checkmark") }
                            else { Text(scope.title) }
                        }
                        .accessibilityIdentifier("global-search-mode-\(scope.rawValue)")
                    }
                } label: {
                    Label(session.scope.title, systemImage: "chevron.down")
                }
                .accessibilityLabel("שיטת חיפוש")
                .accessibilityValue(session.scope.title)
                .accessibilityIdentifier("global-search-mode")
            }
            .font(.subheadline)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .themeTint()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("global-search-header")
    }
}
