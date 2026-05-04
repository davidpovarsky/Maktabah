import SwiftUI

struct iOSReaderTabView: View {
    @Environment(iOSNavigationManager.self) var bManager
    @State private var showingBookInfo = false

    var textViewState = TextViewState.shared

    var backgroundColor: Color {
        let colors: [Color] = [
            .white,
            .bgSepia,
            .bgSepiaDark,
            .bgGray,
            .bgDark,
        ]
        let index = textViewState.backgroundColorIndex

        if index >= 0, index < colors.count {
            return colors[index]
        }
        return Color(UIColor.systemBackground)
    }

    var isDarkMode: Bool {
        textViewState.backgroundColorIndex > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if bManager.openTabs.count > 0 {
                // Tab Content
                TabView(selection: Binding(
                    get: { bManager.activeTabId },
                    set: { bManager.activeTabId = $0 }
                )) {
                    ForEach(bManager.openTabs) { tab in
                        iOSReaderView(
                            book: tab.book,
                            viewModel: tab.viewModel,
                            initialContentId: tab.initialContentId,
                            ipad: true
                        )
                        .tag(tab.id as UUID?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Select a book to read")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(backgroundColor)
        .toolbar {
            if bManager.openTabs.count > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(Array(bManager.openTabs.enumerated()), id: \.element.id) { index, tab in
                                ReaderTabItemView(
                                    tab: tab,
                                    isActive: bManager.activeTabId == tab.id,
                                    onSelect: { bManager.selectTab(id: tab.id) },
                                    onClose: { bManager.closeTab(id: tab.id) },
                                    darkMode: isDarkMode
                                )

                                if index < bManager.openTabs.count - 1 {
                                    Divider()
                                        .frame(height: 16)
                                }
                            }
                        }
                        .padding(3)
                        .background(Color(.systemFill).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .leftToRight)
                }
            }

            // Untuk title juga, ganti showTitle logic:
            if bManager.openTabs.count == 1,
               let activeTab = bManager.openTabs.first
            {
                ToolbarItem(placement: .principal) {
                    Text(activeTab.book.book)
                        .font(iOSReaderViewModel.kfgqpc)
                        .foregroundStyle(isDarkMode ? .white : .black)
                }
            }

            if let activeTab = bManager.openTabs.first(where: { $0.id == bManager.activeTabId }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingBookInfo = true }) {
                        Image(systemName: "info.circle")
                    }
                    .popover(isPresented: $showingBookInfo) {
                        iOSBookInfoView(book: activeTab.book)
                            .presentationCompactAdaptation(.popover)
                            .frame(maxWidth: 350, maxHeight: 450)
                    }
                }
            }
        }
    }
}

struct ReaderTabItemView: View {
    let tab: iOSNavigationManager.ReaderTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let darkMode: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(
                        isActive
                            ? (darkMode ? Color.white : Color.black)
                            : (darkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.3))
                    )
                    .padding(3)
                    .background(
                        isActive
                            ? (darkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                            : Color.clear
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(tab.book.book)
                .font(.subheadline)
                .fontWeight(.regular)
                .lineLimit(1)
                .foregroundColor(
                    isActive
                        ? (darkMode ? Color.white : Color.black)
                        : (darkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(
            isActive
                ? (darkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                : (darkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

#Preview {
    iOSReaderTabView()
}
