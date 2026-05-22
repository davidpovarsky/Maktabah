//
//  SavedResults.swift
//  maktab
//
//  Created by MacBook on 05/12/25.
//

import Cocoa

class SavedResults: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var xButton: NSButton!

    var resultsVM: ResultsViewManager!

    weak var delegate: ResultsDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        resultsVM = ResultsViewManager(
            outlineView: outlineView,
            delegate: delegate,
            writer: false
        )
        outlineView.dataSource = resultsVM
        outlineView.delegate = resultsVM
        if #available(macOS 26.0, *) {
            xButton.borderShape = .capsule
        }
        // Do view setup here.
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        ReusableFunc.showProgressWindow(view)
        Task.detached { [weak self] in
            await self?.resultsVM.vm.getFolders()
            await self?.dbLoadResults()
            await MainActor.run { [weak self] in
                guard let self else { return }
                ReusableFunc.closeProgressWindow(self.view)
            }
        }
    }

    @IBAction func search(_ sender: NSSearchField) {
        resultsVM.searchResults(for: sender.stringValue)
    }

    @IBAction func addFolder(_ sender: Any) {
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        let alert = NSAlert()
        alert.messageText = "Create New Folder".localized
        alert.addButton(withTitle: "Save".localized)
        alert.addButton(withTitle: "Cancel".localized)
        alert.accessoryView = textField

        let response = alert.runModal()

        guard response == .alertFirstButtonReturn else { return }

        let name = textField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else { return }

        let row = outlineView.selectedRow

        do {
            if row >= 0,
               let item = outlineView.item(atRow: row) as? FolderNode {
                try resultsVM.vm.addSubFolder(parentNode: item, name: name)
            } else {
                try resultsVM.vm.addRootFolder(name: name)
            }
        } catch {
            ResultsViewManager.showAlertCreateFolderError(subFolder: row >= 0)
        }
    }

    @IBAction func deleteFolder(_ sender: Any) {
        let row = outlineView.selectedRow
        if let item = outlineView.item(atRow: row) as? FolderNode {
            let parentNode = outlineView.parent(forItem: item) as? FolderNode

            // Tentukan parent yang benar (parent jika ada, atau root/nil)
            let parentForViewUpdate: Any? = parentNode ?? nil

            var indexToRemove: Int

            if let parent = parentNode {
                // --- KASUS: Item ada di dalam parent (Child Node) ---
                guard let index = parent.children.firstIndex(where: { $0 === item }) else {
                    print("Error: Item tidak ditemukan di array children parent.")
                    return
                }
                indexToRemove = index
                parent.children.remove(at: indexToRemove)
            } else {
                // --- KASUS: Item adalah Node Level Atas (Root Node) ---
                guard let rootViewModel = resultsVM?.vm else { return }
                guard let index = rootViewModel.folderRoots.firstIndex(where: { $0 === item }) else {
                    print("Error: Item tidak ditemukan di array root.")
                    return
                }
                indexToRemove = index
            }

            // Hapus dari tampilan sebelum deleteFolder (agar animasi mulus)
            outlineView.removeItems(
                at: IndexSet(integer: indexToRemove),
                inParent: parentForViewUpdate
            )
            // deleteFolder memutasikan ViewModel + memanggil onDataChanged
            resultsVM.vm.deleteFolder(node: item)
            return
        }

        if let item = outlineView.item(atRow: row) as? ResultNode {
            let parent = outlineView.parent(forItem: item) as? FolderNode
            resultsVM.vm.deleteResult(parent?.id, name: item.name)
        }
    }
    
    override func dismiss(_ sender: Any?) {
        if let window = view.window {
            window.contentViewController = nil
            window.close()
        }
        super.dismiss(sender)
    }

    deinit {
        #if DEBUG
        print("deinit savedResults")
        #endif
        delegate = nil
        resultsVM = nil
    }
}

extension SavedResults {
    func dbLoadResults() async {
        await resultsVM.vm.dbLoadAllResults()
        // UI reload ditangani oleh onDataChanged callback di ResultsViewManager
    }
}
