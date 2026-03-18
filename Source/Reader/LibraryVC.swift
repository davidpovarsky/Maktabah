//
//  LibraryVC.swift
//  maktab
//
//  Created by MacBook on 30/11/25.
//

import Cocoa

class LibraryVC: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var scrollViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!

    @IBOutlet weak var searchField: DSFSearchField!

    var dataVM: LibraryViewManager!

    var data: LibraryDataManager = .shared

    var searchFieldIsHidden: Bool = true

    weak var delegate: LibraryDelegate?

    var isDataLoaded: Bool = false

    weak var bg: NSView!
    private var filterSegment: NSSegmentedControl?

    override func viewDidLoad() {
        super.viewDidLoad()
        dataVM = LibraryViewManager(
            outlineView: outlineView,
            searchField: searchField
        )
        dataVM.delegate = self
        searchField.focusRingType = .none
        // Do view setup here.
        setupOutlineView()
        ReusableFunc.setupSearchField(
            searchField,
            systemSymbolName: "line.3.horizontal.decrease.circle"
        )

        NotificationCenter.default.addObserver(
            forName: .libraryFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            isDataLoaded = false  // Reset local flag
            setupUI()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        setupUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        guard !isDataLoaded else { return }
        searchField.delegate = dataVM
        ReusableFunc.showProgressWindow(view)
        Task.detached { [weak self] in
            guard let self else { return }
            await data.loadData()
            await MainActor.run { [weak self] in
                guard let self else { return }
                dataVM.prepareData()
                outlineView.reloadData()
                if AppConfig.isUsingBundleMode {
                    setupFilterSegment()
                } else if let filterSegment {
                    filterSegment.removeFromSuperview()
                    self.filterSegment = nil
                    bg?.removeFromSuperview()
                    bg = nil
                }
                updateScrollViewConstraint(filterSegment: filterSegment != nil)
                ReusableFunc.closeProgressWindow(view)
                isDataLoaded = true
            }
        }
    }

    // MARK: - Filter Segment (Bundle Mode only)

    @objc private func filterSegmentChanged(_ sender: NSSegmentedControl) {
        UserDefaults.standard.set(
            sender.selectedSegment,
            forKey: LibraryViewManager.filterSegmentIndexKey
        )
        dataVM.applyDownloadFilter(forSegmentIndex: sender.selectedSegment)
    }

    private func setupFilterSegment() {
        let all = String(localized: "All")
        let downloaded = String(localized: "Downloaded")
        let segment = NSSegmentedControl(
            labels: [all, downloaded],
            trackingMode: .selectOne,
            target: self,
            action: #selector(filterSegmentChanged(_:))
        )

        if #available(macOS 26, *) {
            segment.borderShape = .capsule
            segment.selectedSegmentBezelColor = .systemOrange
                .shadow(withLevel: 0.3) ?? .header
            let glass = NSGlassEffectView()
            glass.cornerRadius = 999
            glass.style = .clear
            glass.addSubview(segment)
            bg = glass
        } else {
            let view = NSView()
            bg = view
            bg.addSubview(segment)
        }

        view.addSubview(bg)

        segment.translatesAutoresizingMaskIntoConstraints = false
        bg.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segment.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 8),
            segment.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -8),
            segment.topAnchor.constraint(equalTo: bg.topAnchor),
            segment.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -8),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        segment.selectedSegment = UserDefaults.standard.integer(
            forKey: LibraryViewManager.filterSegmentIndexKey
        )

        filterSegment = segment
        dataVM.applyDownloadFilter(forSegmentIndex: segment.selectedSegment)
        updateScrollViewConstraint(filterSegment: true)
    }

    private func updateScrollViewConstraint(filterSegment: Bool) {
        // Geser scrollView ke atas agar tidak tertutup segment
        if filterSegment, let segmentedControl = self.filterSegment {
            let inset = segmentedControl.intrinsicContentSize.height + 16
            if #available(macOS 26, *) {
                applyScrollViewInsets(bottom: inset)
            } else {
                scrollViewBottomConstraint.constant = inset
            }
        } else {
            if #available(macOS 26, *) {
                scrollView.automaticallyAdjustsContentInsets = true
            } else {
                scrollViewBottomConstraint.constant = 0
            }
        }
    }

    func updateContentInset() {
        if #available(macOS 26, *) {
            let bottomInset = filterSegment?.intrinsicContentSize.height ?? 0
            applyScrollViewInsets(bottom: bottomInset > 0 ? bottomInset + 16 : 0)
        }
    }

    @available(macOS 26, *)
    private func applyScrollViewInsets(bottom: CGFloat) {
        view.layoutSubtreeIfNeeded()
        scrollView.layoutSubtreeIfNeeded()
        scrollView.automaticallyAdjustsContentInsets = true

        Task { [weak self] in
            guard let self else { return }
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets.bottom = bottom
        }
    }

    func setupOutlineView() {
        outlineView.delegate = dataVM
        outlineView.dataSource = dataVM
        ReusableFunc.registerNib(
            tableView: outlineView,
            nibName: .outlineChildNib,
            cellIdentifier: .resultAndOutlineChild
        )

        ReusableFunc.registerNib(
            tableView: outlineView,
            nibName: .outlineParentNib,
            cellIdentifier: .outlineParent
        )
    }

    func unhideSearchField() {
        ReusableFunc.unhideSearchField(
            searchFieldIsHidden: searchFieldIsHidden,
            searchField: searchField,
            scrollViewTopConstraint: scrollViewTopConstraint)
    }
}

extension LibraryVC: LibraryViewDelegate {
    func didSelectItem(_ row: Int) async {
        if row >= 0 {
            let item = outlineView.item(atRow: row)
            if let book = item as? BooksData {
                print("Buku dipilih: \(book.book) (ID: \(book.id))")
                await delegate?.didSelectBook(for: book)
            } else if let category = item as? CategoryData {
                print("Kategori dipilih: \(category.name)")
            }
        }
    }
}
