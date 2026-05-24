import SwiftUI

struct ViewOptionsView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var state = TextViewState.shared

    let fontOptions = ArabicFont.allCases.map(\.rawValue)
    let lineHeights = [1.0, 1.1, 1.2, 1.3, 1.4, 1.5]
    let backgroundColors: [Color] = [
        .white,
        .bgSepia,
        .bgSepiaDark,
        .bgGray,
        .bgDark,
    ]

    /// Binding for CoreGraphics to Double/Float conversion
    private var fontSizeBinding: Binding<CGFloat> {
        Binding<CGFloat>(
            get: { state.fontSize },
            set: { state.changeFontSize(by: $0 - state.fontSize) }
        )
    }

    private var fontNameBinding: Binding<String> {
        Binding<String>(
            get: { state.fontName },
            set: { state.setFont($0) }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding<Double>(
            get: { state.lineHeight },
            set: { state.setLineHeight($0) }
        )
    }

    private var showHarakatBinding: Binding<Bool> {
        Binding<Bool>(
            get: { state.showHarakat },
            set: { if state.showHarakat != $0 { state.toggleHarakat() } }
        )
    }

    private var clickableAnnotationBinding: Binding<Bool> {
        Binding<Bool>(
            get: { state.clickableAnnotation },
            set: { state.setClickableAnnotation($0) }
        )
    }

    var body: some View {
        NavigationView {
            ThemeForm {
                ThemeSection("Typography") {
                    Picker("Font", selection: fontNameBinding) {
                        ForEach(fontOptions, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Font Size: \(Int(state.fontSize))")
                        HStack {
                            Text("A").font(.system(size: 12))
                            Slider(value: fontSizeBinding, in: 12 ... 48, step: 2)
                            Text("A").font(.system(size: 24))
                        }
                    }

                    Picker("Line Height", selection: lineHeightBinding) {
                        ForEach(lineHeights, id: \.self) { height in
                            Text(String(format: "%.1f", height)).tag(height)
                        }
                    }
                }

                ThemeSection("Display") {
                    Toggle("Show Harakat", isOn: showHarakatBinding)
                    Toggle("Clickable Annotations", isOn: clickableAnnotationBinding)
                }

                ThemeSection("Background") {
                    HStack(spacing: 20) {
                        ForEach(0 ..< backgroundColors.count, id: \.self) { index in
                            let isSelected = state.backgroundColorIndex == index
                            Circle()
                                .fill(backgroundColors[index])
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? Color.blue : Color.secondary,
                                                lineWidth: isSelected ? 3 : 1)
                                )
                                .onTapGesture {
                                    state.setBackgroundColorIndex(index)
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("View Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .preferredColorScheme(state.isDarkMode ? .dark : .light)
    }
}
