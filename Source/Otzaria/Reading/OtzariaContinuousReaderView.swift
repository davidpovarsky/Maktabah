import SwiftUI

#if os(iOS)
struct OtzariaContinuousReaderView: View {
    @Bindable var viewModel: ReaderViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 22) {
                ForEach(viewModel.otzariaVisibleUnits) { unit in
                    VStack(alignment: .trailing, spacing: 10) {
                        Button {
                            viewModel.selectOtzariaUnitForLinks(unit)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text(unit.heRef ?? unit.title ?? "\(unit.startLineIndex)")
                                    .lineLimit(1)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text(unit.plainText)
                            .font(ReaderViewModel.kfgqpc)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textSelection(.enabled)
                    }
                    .id(unit.startLineIndex)
                    .padding(.horizontal, 18)
                    .onAppear {
                        viewModel.otzariaContinuousUnitDidAppear(unit)
                    }
                }
            }
            .padding(.vertical, 18)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct OtzariaSourcesPanelView: View {
    let unit: OtzariaReadingUnit?
    let sources: [OtzariaLinkedSource]

    var body: some View {
        NavigationStack {
            Group {
                if let unit {
                    if sources.isEmpty {
                        ContentUnavailableView(
                            unit.heRef ?? unit.title ?? "Sources",
                            systemImage: "link",
                            description: Text("No linked sources are available yet.")
                        )
                    } else {
                        List(sources) { source in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(source.title)
                                    .font(.headline)
                                if let reference = source.reference {
                                    Text(reference)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let snippet = source.snippet {
                                    Text(snippet)
                                        .font(.body)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Sources", systemImage: "link", description: Text("Select a unit to view linked sources."))
                }
            }
            .navigationTitle("Sources")
        }
    }
}
#endif
