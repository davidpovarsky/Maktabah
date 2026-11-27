@MainActor struct LegacyIPadHost {
    private func selectedTOCNode(for viewModel: ReaderViewModel) -> TOCNode? {
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }
func select(_ reader: ReaderViewModel) -> TOCNode? { selectedTOCNode(for: reader) }
}
