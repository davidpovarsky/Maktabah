import SwiftUI

struct OtzariaReaderSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("otsaria.reader.fontSize") private var fontSize = 20.0
    @AppStorage("otsaria.reader.lineSpacing") private var lineSpacing = 6.0
    @AppStorage("otsaria.reader.showHebrewReference") private var showHebrewReference = true

    var body: some View {
        Form {
            Section("טקסט") {
                Slider(value: $fontSize, in: 14...32, step: 1) {
                    Text("גודל אות")
                } minimumValueLabel: {
                    Text("א")
                } maximumValueLabel: {
                    Text("א")
                        .font(.title3)
                }

                Slider(value: $lineSpacing, in: 0...14, step: 1) {
                    Text("ריווח שורות")
                }

                Toggle("הצג מראי מקום בעברית", isOn: $showHebrewReference)
            }

            Section("תצוגה מקדימה") {
                Text("בראשית ברא אלהים את השמים ואת הארץ")
                    .font(.system(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .multilineTextAlignment(.trailing)
            }
        }
        .navigationTitle("הגדרות קריאה")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("סגור") {
                    dismiss()
                }
            }
        }
    }
}
