import SwiftUI
import Combine

enum iOSRowiDisplayMode: Int, CaseIterable, Identifiable {
    case tilmidz = 0
    case syaikh
    case takdil
    case mulakhosh

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .tilmidz: "التلاميذ"
        case .syaikh: "الشيوخ"
        case .takdil: "الجرح والتعديل"
        case .mulakhosh: "ملخص"
        }
    }
}

@MainActor
class iOSAuthorViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var tabaqaGroups: [TabaqaGroup] = []

    @Published var selectedRowi: Rowi? {
        didSet {
            if let rowi = selectedRowi {
                dataManager.loadRowiData(rowi)
                updateRowiContent()
            }
        }
    }

    @Published var displayMode: iOSRowiDisplayMode = .mulakhosh {
        didSet {
            updateRowiContent()
        }
    }

    @Published var rowiContentText: AttributedString = ""

    private let dataManager = RowiDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .didChangeHarakat)
            .sink { [weak self] _ in
                self?.updateRowiContent()
            }
            .store(in: &cancellables)
    }

    func loadData() async {
        guard tabaqaGroups.isEmpty else { return }

        isLoading = true
        async let booksData: () = LibraryDataManager.shared.loadData()
        async let rowiData: () = dataManager.loadData()

        _ = await (rowiData, booksData)

        tabaqaGroups = dataManager.tabaqaGroups
        isLoading = false
    }

    func searchRowis(query: String) {
        dataManager.searchRowis(query: query)
        tabaqaGroups = dataManager.tabaqaGroups
    }

    func loadMore(group: TabaqaGroup, completion: @escaping (Int?) -> Void) {
        dataManager.loadMore(group, completion: completion)
    }

    private func renderText(_ text: String) -> AttributedString {
        let renderer = ArabicTextRenderer()
        let state = TextViewState.shared
        let headerColor = UIColor.header

        let renderResult = renderer.render(
            text: text,
            highlightColor: headerColor,
            showHarakat: state.showHarakat,
            isMultiLanguage: false
        )
        
        return (try? AttributedString(renderResult.attributedString, including: \.uiKit)) ?? AttributedString(text)
    }

    func displayAuthor(
        _ rotba: String,
        rZahbi: String,
        for rowi: Rowi
    ) {
        var container = AttributedString()

        /// Helper function di dalam
        func appendLine(label: String, value: String?) {
            guard let value, !value.isEmpty else { return }

            // Buat bagian Label (Bold)
            var labelAttr = AttributedString(label)
            labelAttr.foregroundColor = .header

            // Buat bagian Value (Default), diproses dengan ArabicTextRenderer
            let valueAttr = renderText(value)

            // Gabungkan
            container.append(labelAttr)
            container.append(valueAttr)
            container.append(AttributedString("\n"))
        }

        appendLine(label: "الإسم: ", value: rowi.name)
        appendLine(label: "الطبقة: ", value: rowi.tabaqa?.convertedTabaqa())
        appendLine(label: "الولادة: ", value: rowi.wulida)
        appendLine(label: "الوفاة: ", value: rowi.tuwuffi)
        appendLine(label: "رُوي له: ", value: rowi.who)
        appendLine(label: "رتبة عند ابن حجر: ", value: rotba)
        appendLine(label: "رتبة عند الذهبي: ", value: rZahbi)

        // Simpan ke @Published atau @State property
        rowiContentText = container
    }

    private func updateRowiContent() {
        guard let rowi = selectedRowi else {
            rowiContentText = ""
            return
        }

        let nullText = String("・・・")

        switch displayMode {
        case .tilmidz:
            rowiContentText = renderText(rowi.telmez ?? nullText)
        case .syaikh:
            rowiContentText = renderText(rowi.sheok ?? nullText)
        case .takdil:
            rowiContentText = renderText(rowi.aqual ?? nullText)
        case .mulakhosh:
            if let rotba = rowi.rotba, let rZahbi = rowi.rZahbi {
                displayAuthor(rotba, rZahbi: rZahbi, for: rowi)
            } else {
                rowiContentText = renderText(nullText)
            }
        }
    }
}
