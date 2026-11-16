import SwiftUI

struct GlobalSearchAdvancedOptionsContent: View {
    @Bindable var session: UnifiedSearchSessionController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ThemeForm {
                if session.supportsSefariaOptions, session.scope == .advanced {
                    Section("התאמת מילים וטווח") {
                        Picker("התאמת מילים", selection: $session.sefariaMatchMode) {
                            Text("מדויק").tag(LibrarySearchMatchMode.exact)
                            Text("צורות דקדוקיות בעברית").tag(LibrarySearchMatchMode.hebrewLemmatized)
                        }
                        .accessibilityIdentifier("global-search-sefaria-match")
                        Stepper("מרחק מילים: \(session.sefariaWordDistance)", value: $session.sefariaWordDistance, in: 0...50)
                            .accessibilityIdentifier("global-search-sefaria-distance")
                    }
                } else if !session.isSefaria, session.scope == .advanced {
                    otzariaOptions
                } else if !session.isSefaria, session.scope == .zayit {
                    Section("זית") {
                        GlobalSearchZayitMatchPicker(session: session, model: session.zayitSession.model)
                        Text("החיפוש משתמש באינדקס זית ובספרים שנבחרו. אין כאן אפשרויות לשוניות של אוצריא.")
                    }
                } else {
                    Section {
                        Text(session.isSefaria && !session.supportsSefariaOptions
                             ? "מקור ספריא זה תומך בחיפוש טקסט מדויק ובמיון לפי רלוונטיות בלבד."
                             : "במצב זה אין הגדרות מתקדמות. לאפשרויות התאמת מילים וטווח בחרו במצב מתקדם.")
                    }
                }
                if let validation = session.optionsValidationMessage {
                    Section { Text(validation).foregroundStyle(.red) }
                        .accessibilityIdentifier("global-search-options-validation")
                }
            }
            .accessibilityIdentifier("global-search-options-content")
            .navigationTitle("אפשרויות חיפוש")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סיום") { dismiss() }
                        .accessibilityIdentifier("global-search-options-done")
                }
            }
        }
    }

    private var otzariaOptions: some View {
        Group {
            Section("התאמת מילים וטווח") {
                scopePicker("טווח חיובי", selection: $session.otzariaScope)
                    .accessibilityIdentifier("global-search-positive-scope")
                if session.otzariaScope == .wordDistance {
                    Stepper("מרחק מילים: \(session.otzariaDistance)", value: $session.otzariaDistance, in: 0...50)
                        .accessibilityIdentifier("global-search-distance")
                }
                Picker("התאמת מילים", selection: $session.otzariaWordMatchMode) {
                    ForEach(OtzariaWordMatchMode.allCases) { mode in Text(mode.label).tag(mode) }
                }
                .accessibilityIdentifier("global-search-word-match")
                if session.otzariaWordMatchMode == .atLeast {
                    Stepper("מילים להתאמה: \(session.otzariaWordMatchCount)", value: $session.otzariaWordMatchCount, in: 1...50)
                        .accessibilityIdentifier("global-search-word-count")
                }
            }
            Section("מילים להחרגה") {
                TextField("מילים להחרגה", text: $session.otzariaNegativeQuery)
                    .accessibilityIdentifier("global-search-negative-query")
                if !session.otzariaNegativeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scopePicker("טווח שלילה", selection: $session.otzariaNegativeScope)
                        .accessibilityIdentifier("global-search-negative-scope")
                    if session.otzariaNegativeScope == .wordDistance {
                        Stepper("מרחק שלילה: \(session.otzariaNegativeDistance)", value: $session.otzariaNegativeDistance, in: 0...50)
                            .accessibilityIdentifier("global-search-negative-distance")
                    }
                }
            }
            Section("אפשרויות לשוניות") {
                Toggle("קידומות", isOn: $session.otzariaEnablesPrefixes)
                Toggle("סיומות", isOn: $session.otzariaEnablesSuffixes)
                Toggle("כתיב מלא וחסר", isOn: $session.otzariaEnablesSpellingVariants)
                Toggle("ארמית", isOn: $session.otzariaEnablesAramaic)
                Toggle("התעלמות מגרשיים וראשי תיבות", isOn: $session.otzariaIgnoresQuotes)
            }
            Section("ניקוד וטעמים") {
                Toggle("התאמת ניקוד", isOn: $session.otzariaMatchNikud)
                Toggle("התאמת טעמים", isOn: $session.otzariaMatchTaamim)
            }
            Section {
                TextField("מרווחים מותאמים", text: $session.otzariaCustomSpacingText)
                    .accessibilityIdentifier("global-search-spacing")
                TextField("מילים חלופיות", text: $session.otzariaAlternativeWordsText)
                    .accessibilityIdentifier("global-search-alternatives")
            } header: { Text("ביטויים מיוחדים") } footer: {
                Text("מרווחים בין מילים מופרדים בפסיק. חלופות לאותה מילה מופרדות בפסיק, וקבוצות לפי מיקום המילה בנקודה־פסיק. מקומות ריקים נשמרים.")
            }
            Section("קיבוץ תוצאות") {
                Picker("קיבוץ", selection: $session.otzariaGrouping) {
                    Text("ללא קיבוץ").tag(Optional<OtzariaResultGrouping>.none)
                    Text("אותו סעיף").tag(Optional(OtzariaResultGrouping.sameSection))
                    Text("טקסט זהה").tag(Optional(OtzariaResultGrouping.identicalText))
                }
                .accessibilityIdentifier("global-search-grouping")
            }
        }
    }

    private func scopePicker(_ title: String, selection: Binding<OtzariaSearchScope>) -> some View {
        Picker(title, selection: selection) {
            Text("מרחק מילים").tag(OtzariaSearchScope.wordDistance)
            Text("אותה פסקה").tag(OtzariaSearchScope.sameParagraph)
            Text("אותו סעיף").tag(OtzariaSearchScope.sameSection)
        }
    }
}

private struct GlobalSearchZayitMatchPicker: View {
    let session: UnifiedSearchSessionController
    @ObservedObject var model: ZayitSearchViewModel

    var body: some View {
        Picker("התאמת מילים", selection: Binding(
            get: { model.matchMode },
            set: { model.matchMode = $0; session.configurationDidChange() }
        )) {
            ForEach(ZayitSearchMatchMode.allCases) { mode in
                Text(mode == .exact ? "מדויק" : "גמיש — מרחק 5 מילים").tag(mode)
            }
        }
        .accessibilityIdentifier("global-search-zayit-match")
    }
}
