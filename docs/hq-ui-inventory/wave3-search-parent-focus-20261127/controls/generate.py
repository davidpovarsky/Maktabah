#!/usr/bin/env python3
"""Compile actual Search-entry/owner/latch bodies over named domain doubles.

This does not compile the app or simulate canonical authority/engine/UIKit.
The actual shared setter, two original metadata setters and input read-set run.
"""
import hashlib
import json
import re
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=False)
integration = root / 'Source/ChavrusaText/UIRoutingHost/Integration'
portable = root / 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost'
inputs = {}


def read(path):
    value = path.read_bytes()
    inputs[str(path.relative_to(root))] = hashlib.sha256(value).hexdigest()
    return value.decode()


def block(text, marker):
    start = text.index(marker)
    opening = text.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        if text[end] == '{':
            depth += 1
        elif text[end] == '}':
            depth -= 1
        end += 1
    return text[start:end]


def without_imports(text):
    return '\n'.join(line for line in text.splitlines()
                     if not line.startswith('import ') and line not in ['#if os(iOS)', '#endif']) + '\n'


entry = read(integration / 'MaktabahNativeSearchEntry.swift')
owner = read(portable / 'NativeComponentRevealOwner.swift')
latch = read(portable / 'NativeComponentSourceObservation.swift')
bridge = read(integration / 'MaktabahNativeComponentBinding.swift')
bindings = read(integration / 'MaktabahNativeSceneBindings.swift')
manager = read(root / 'Source/UI/iOS/Managers/iOSNavigationManager.swift')
main = read(root / 'Source/UI/iOS/Views/iOSMainView.swift')
manager_fields = block(manager, '    var currentMode: AppMode') + '\n'
manager_fields += '    private(set) var nativeModePresentationRevision: UInt64? = 0\n'
manager_fields += block(manager, '    var selectedBook: BooksData?') + '\n'
manager_fields += '    private(set) var selectedBookPresentationRevision: UInt64? = 0\n'
manager_fields += '    private(set) var selectedBookPresentationMode: AppMode?\n'
# These declarations are exact original source; initial seeds exist only in the
# explicit boundary initializer to exercise monotonic exhaustion without loops.
assert manager_fields in manager
domain = Path(__file__).with_name('DomainBoundary.swift').read_text()
domain += '''
@MainActor @Observable final class iOSNavigationManager {
    struct ReaderTab {
        let id: UUID
        let book: BooksData
        var viewModel: ReaderViewModel
    }
'''
domain += manager_fields
domain += '''
    var unifiedSearchSession = UnifiedSearchSessionController()
    var searchViewModel = SearchViewModel()
    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?
    var selectedContentId: Int? = 523
    var selectedBookForInfo: BooksData?
    var showingTabsList = false
    var alertMessage: String?
    var activeReaderViewModel: ReaderViewModel? {
        openTabs.first { $0.id == activeTabId }?.viewModel
    }
    init(modeSeed: UInt64? = 0, bookSeed: UInt64? = 0) {
        nativeModePresentationRevision = modeSeed
        selectedBookPresentationRevision = bookSeed
        unifiedSearchSession.searchViewModel = searchViewModel
    }
}
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator? = nil
    let rootPublications: MaktabahNativeRootPublicationSource?
'''
domain += block(bindings, '    var isPresentationReady: Bool') + '\n'
domain += block(bindings, '    func presentOriginalSearchEntry(') + '\n}\n'
(out / 'DomainBoundary.swift').write_text(domain)
(out / 'ActualOwner.swift').write_text('import Foundation\nimport Observation\n' + without_imports(owner))
(out / 'ActualObservation.swift').write_text('import Foundation\nimport Observation\nimport Synchronization\n' + without_imports(latch))
(out / 'ActualBackendObservation.swift').write_text('import Foundation\n'
    + 'typealias MaktabahNativeComponentDescriptor = NativeComponentDescriptor\n'
    + 'typealias MaktabahNativeComponentOwner = NativeComponentRevealOwner\n'
    + block(bridge, '@MainActor final class MaktabahNativeComponentSourceObservation') + '\n')
(out / 'ActualSearchEntry.swift').write_text('import Foundation\n' + without_imports(entry) + '''
// Explicit fixture initialization only. The production source above has no
// seed/reset API; this same-file extension exercises exhaustion without loops.
extension MaktabahNativeRootPublicationSource {
    convenience init(boundarySelection: UInt64?, boundarySettings: UInt64?) {
        self.init()
        selectionRevision = boundarySelection; settingsRevision = boundarySettings
    }
}
''')
# The owning SwiftUI body itself is not compiled by this domain capsule. Seal
# its exact wrapper callsites independently; the wrapper/setter source runs.
assert main.count('selectedTab: originalSelectedTab') == 3
assert main.count('originalSelectedTab.wrappedValue =') == 14
assert main.count('$selectedTab') == 1 and main.count('$showSettings') == 1
assert not re.search(r'(?m)^\s*(?:selectedTab|showSettings)\s*=', main)
assert 'nativeRootPublications.selectionBinding($selectedTab)' in main
assert 'nativeRootPublications.settingsBinding($showSettings)' in main
(out / 'Controls.swift').write_text(Path(__file__).with_name('Controls.swift').read_text())
manifest = {
    'scope': 'Actual app Search entry/parent setter/metadata and generic owner/one-shot latch; explicit UIKit, Combine, app domain and Core lifetime inputs. NOT SDK or native acceptance.',
    'source_inputs': inputs,
    'harness_files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.glob('*.swift'))},
}
(out / 'INPUTS.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'directory': str(out), **manifest}))
