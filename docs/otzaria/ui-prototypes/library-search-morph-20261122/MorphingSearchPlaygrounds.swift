import SwiftUI
import Foundation

// Complete, single-file App Playground demo.
// Replace the contents of your App's only Swift source file with this code.
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

private struct SearchItem: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let symbol: String
}

struct ContentView: View {
    @State private var isExpanded = false
    @State private var searchText = ""
    @State private var selectedTitle: String? = nil
    @FocusState private var isSearchFocused: Bool

    private let morphAnimation = Animation.spring(response: 0.52, dampingFraction: 0.86)

    private let suggestions: [SearchItem] = [
        SearchItem(id: 1, title: "אנימציות SwiftUI", detail: "מעברים חלקים בין מצבי תצוגה", symbol: "sparkles"),
        SearchItem(id: 2, title: "עיצוב ממשק", detail: "רכיבים, צבעים וטיפוגרפיה", symbol: "square.grid.2x2"),
        SearchItem(id: 3, title: "חיפוש חכם", detail: "תוצאות שמתעדכנות בזמן ההקלדה", symbol: "magnifyingglass"),
        SearchItem(id: 4, title: "בועות צפות", detail: "חלוניות ותפריטים מעל התוכן", symbol: "rectangle.on.rectangle"),
        SearchItem(id: 5, title: "ממשק צ'אט", detail: "שדה הקלדה ופעולות מהירות", symbol: "bubble.left.and.bubble.right"),
        SearchItem(id: 6, title: "מחוות מגע", detail: "לחיצות, גרירה ותגובות מיידיות", symbol: "hand.tap")
    ]

    private var filteredSuggestions: [SearchItem] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return suggestions }
        return suggestions.filter {
            $0.title.localizedCaseInsensitiveContains(term) ||
            $0.detail.localizedCaseInsensitiveContains(term)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let expandedWidth = min(580, max(260, geometry.size.width - 36))
            let compactWidth = min(306, expandedWidth)
            // Keep the panel visible when the keyboard reduces the safe area.
            let topOffset: CGFloat = geometry.size.height < 570 ? 112 : 174
            let expandedHeight = min(490, max(200, geometry.size.height - topOffset - 20))

            ZStack(alignment: .top) {
                background

                VStack(spacing: 11) {
                    Text("SWIFTUI  /  MORPHING SEARCH")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2.0)
                        .foregroundStyle(Color.indigo.opacity(0.75))

                    Text("חיפוש שמתרחב לבועה")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.31))

                    Text("הקש על השדה כדי לראות את האנימציה")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 52)

                if isExpanded {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeSearch)
                        .transition(.opacity)
                }

                searchBubble(
                    compactWidth: compactWidth,
                    expandedWidth: expandedWidth,
                    expandedHeight: expandedHeight
                )
                .padding(.top, topOffset)
                .zIndex(1)

                if !isExpanded {
                    VStack {
                        Spacer()

                        HStack(spacing: 8) {
                            Image(systemName: selectedTitle == nil ? "hand.tap" : "checkmark.circle.fill")
                            Text(selectedTitle.map { "נבחר: \($0)" } ?? "אפשר להקליד, לסנן תוצאות ולבחור פריט")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.32, green: 0.37, blue: 0.51))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.7), in: Capsule())
                        .padding(.bottom, 32)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(morphAnimation, value: isExpanded)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.96, blue: 1.00),
                    Color(red: 0.87, green: 0.91, blue: 0.99),
                    Color(red: 0.95, green: 0.92, blue: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 360, height: 360)
                .blur(radius: 24)
                .offset(x: 235, y: -225)

            Circle()
                .fill(Color.purple.opacity(0.09))
                .frame(width: 380, height: 380)
                .blur(radius: 50)
                .offset(x: -210, y: 255)
        }
        .ignoresSafeArea()
    }

    // The outer surface changes size. Its contents keep their natural size
    // and are revealed by clipping instead of being squeezed or reflowed.
    private func searchBubble(
        compactWidth: CGFloat,
        expandedWidth: CGFloat,
        expandedHeight: CGFloat
    ) -> some View {
        let cornerRadius: CGFloat = isExpanded ? 28 : 32

        return ZStack(alignment: .topLeading) {
            expandedPanel(width: expandedWidth, height: expandedHeight)
                .frame(width: expandedWidth, height: expandedHeight, alignment: .topLeading)
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)
                .accessibilityHidden(!isExpanded)

            compactField
                .frame(width: compactWidth, height: 64)
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(!isExpanded)
                .accessibilityHidden(isExpanded)
        }
        .frame(
            width: isExpanded ? expandedWidth : compactWidth,
            height: isExpanded ? expandedHeight : 64,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: Color(red: 0.22, green: 0.29, blue: 0.49).opacity(isExpanded ? 0.24 : 0.15),
            radius: isExpanded ? 32 : 18,
            x: 0,
            y: isExpanded ? 18 : 9
        )
    }

    private var compactField: some View {
        Button(action: openSearch) {
            HStack(spacing: 13) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.indigo)

                Text("חיפוש...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(red: 0.44, green: 0.47, blue: 0.57))

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.indigo.opacity(0.65))
            }
            .padding(.horizontal, 21)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("פתח חיפוש")
    }

    private func expandedPanel(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.indigo)

                TextField("מה תרצה למצוא?", text: $searchText)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.31))
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .accessibilityLabel("שדה חיפוש מורחב")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("נקה חיפוש")
                }

                Button(action: closeSearch) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.34, green: 0.39, blue: 0.51))
                        .frame(width: 37, height: 37)
                        .background(Color(red: 0.94, green: 0.95, blue: 0.98), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("סגור חיפוש")
            }
            .padding(.horizontal, 24)
            .frame(height: 83)

            Rectangle()
                .fill(Color(red: 0.91, green: 0.92, blue: 0.96))
                .frame(height: 1)
                .padding(.horizontal, 24)

            HStack {
                Text(searchText.isEmpty ? "הצעות לחיפוש" : "תוצאות חיפוש")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.17, green: 0.22, blue: 0.37))
                Spacer()
                Text("\(filteredSuggestions.count) תוצאות")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 13)

            ScrollView {
                if filteredSuggestions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 27))
                            .foregroundStyle(Color.indigo.opacity(0.5))
                        Text("לא נמצאו תוצאות")
                            .font(.system(size: 17, weight: .semibold))
                        Text("נסה לחפש מילה אחרת")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 45)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSuggestions) { item in
                            resultRow(item)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                }
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 7) {
                Image(systemName: "hand.tap")
                Text("בחר תוצאה כדי לסגור את הבועה")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(red: 0.43, green: 0.47, blue: 0.59))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color(red: 0.977, green: 0.98, blue: 1.0))
        }
        .frame(width: width, height: height, alignment: .top)
    }

    private func resultRow(_ item: SearchItem) -> some View {
        Button {
            selectedTitle = item.title
            closeSearch()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.indigo)
                    .frame(width: 44, height: 44)
                    .background(
                        Color.indigo.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.31))
                    Text(item.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.indigo.opacity(0.45))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(
                Color(red: 0.972, green: 0.978, blue: 0.994),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func openSearch() {
        withAnimation(morphAnimation) {
            isExpanded = true
        }
    }

    private func closeSearch() {
        isSearchFocused = false
        withAnimation(morphAnimation) {
            isExpanded = false
        }
    }
}
