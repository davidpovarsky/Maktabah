import SwiftUI
import UIKit

// MARK: - View Controller

@MainActor
class iOSLibraryViewController: iOSHierarchicalCollectionViewController {
    var viewModel: iOSLibraryViewModel?
    var onBookSelected: ((BooksData) -> Void)?
    var onSelectionChanged: (() -> Void)?
    var onDeleteBook: ((BooksData) -> Void)?
    var onDownloadBook: ((BooksData) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
    }

    // MARK: - Cell Registrations

    override func makeCategoryCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, CategoryData> {
        UICollectionView.CellRegistration { [weak self] cell, _, category in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = category.name
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1

            if viewModel?.isSelectionMode == true {
                content.image = nil
            } else {
                // Change icon based on view mode
                let isAuthorMode = viewModel?.viewMode == .author
                content.image = UIImage(systemName: isAuthorMode ? "person.fill" : "folder.fill")
                content.imageProperties.tintColor = .tintColor
            }

            cell.contentConfiguration = content

            let disclosure = UICellAccessory.outlineDisclosure(options: .init(style: .header))
            if viewModel?.isSelectionMode == true {
                let isSelected = viewModel?.isCategorySelected(category) == true
                let isPartial = viewModel?.isCategoryPartiallySelected(category) == true
                let imageName = isSelected
                    ? "checkmark.circle.fill"
                    : (isPartial ? "minus.circle.fill" : "circle")
                let checkbox = UIButton(type: .system)
                checkbox.setImage(UIImage(systemName: imageName), for: .normal)
                checkbox.tintColor = isSelected || isPartial ? .tintColor : .secondaryLabel
                checkbox.addAction(UIAction { [weak self] _ in
                    self?.viewModel?.toggleCategorySelection(category)
                    self?.reloadVisibleItems()
                    self?.onSelectionChanged?()
                }, for: .touchUpInside)

                let customAccessory = UICellAccessory.customView(
                    configuration: .init(customView: checkbox, placement: .leading())
                )
                cell.accessories = [customAccessory, disclosure]
            } else {
                cell.accessories = [disclosure]
            }

            cell.applyThemeConfigurationUpdateHandler()
        }
    }

    override func makeBookCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, BooksData> {
        UICollectionView.CellRegistration { [weak self] cell, _, book in
            guard let self else { return }
            var content = cell.defaultContentConfiguration()
            content.text = book.book
            content.textProperties.font = font
            content.textProperties.numberOfLines = 1

            let isDownloaded = viewModel?.isBookDownloaded(book) == true
            if viewModel?.isSelectionMode == true {
                content.image = nil
            } else {
                content.image = UIImage(systemName: isDownloaded ? "book.fill" : "icloud.and.arrow.down")
                content.imageProperties.tintColor = isDownloaded ? .tintColor : .secondaryLabel
            }

            cell.contentConfiguration = content

            if viewModel?.isSelectionMode == true {
                let isSelected = viewModel?.isBookSelected(book) == true
                let checkbox = UIButton(type: .system)
                checkbox.setImage(UIImage(systemName: isSelected ? "checkmark.square.fill" : "square"), for: .normal)
                checkbox.tintColor = isDownloaded
                    ? .tertiaryLabel
                    : (isSelected ? .tintColor : .secondaryLabel)
                checkbox.isEnabled = !isDownloaded
                checkbox.addAction(UIAction { [weak self] _ in
                    self?.viewModel?.toggleBookSelection(book)
                    self?.onSelectionChanged?()
                }, for: .touchUpInside)

                let customAccessory = UICellAccessory.customView(
                    configuration: .init(customView: checkbox, placement: .leading())
                )
                cell.accessories = [customAccessory]
            } else {
                cell.accessories = []
            }

            cell.applyThemeConfigurationUpdateHandler()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension iOSLibraryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        if viewModel?.isSelectionMode == true {
            switch item {
            case let .category(category):
                viewModel?.toggleCategorySelection(category)
            case let .book(book):
                viewModel?.toggleBookSelection(book)
            case .loadMore:
                viewModel?.loadMoreAuthors()
            }
            reloadVisibleItems()
            onSelectionChanged?()
            return
        }

        switch item {
        case let .book(book):
            onBookSelected?(book)
        case .loadMore:
            viewModel?.loadMoreAuthors()
        case .category:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let item = dataSource.itemIdentifier(for: indexPath),
              case let .book(book) = item,
              let viewModel = viewModel
        else {
            return nil
        }

        let isDownloaded = viewModel.isBookDownloaded(book)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let selectAction = UIAction(
                title: String(localized: "Select") + "...",
                image: UIImage(systemName: "checkmark.circle")
            ) { _ in
                viewModel.enterSelectionMode(selecting: book)
                self?.reloadVisibleItems()
                self?.onSelectionChanged?()
            }

            let mainAction: UIAction
            if isDownloaded {
                mainAction = UIAction(
                    title: String(localized: "Delete Download"),
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { _ in
                    self?.onDeleteBook?(book)
                }
            } else {
                mainAction = UIAction(title: String(localized: "Download"), image: UIImage(systemName: "icloud.and.arrow.down")) { _ in
                    self?.onDownloadBook?(book)
                }
            }

            return UIMenu(title: "", children: [mainAction, selectAction])
        }
    }
}
