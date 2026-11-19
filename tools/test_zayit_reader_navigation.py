#!/usr/bin/env python3
"""Compile the actual Zayit adapter and Reader ID hook with portable boundaries.

This does not render UIKit, invoke native search, or grant Native acceptance.
"""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--adapter-ref', help='Compile the old adapter for a meaningful expected-red regression')
args = parser.parse_args()


def source(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


with tempfile.TemporaryDirectory(prefix='zayit-reader-navigation-') as directory:
    temp = Path(directory)
    models = source('Source/LibraryBackend/LibraryBackendModels.swift')
    (temp / 'Locators.swift').write_text(models[:models.index('/// A navigable unit')], encoding='utf-8')
    registry = source('Source/LibraryBackend/LegacyIdentityRegistry.swift').split('/// Canonical book IDs shared')[0]
    namespace = 'ZayitReaderNavigationFixture.' + str(uuid.uuid4())
    registry = registry.replace('static let shared = LegacyIdentityRegistry()',
        'static let shared = LegacyIdentityRegistry(defaults: UserDefaults(suiteName: "' + namespace + '")!, persistenceDelay: 3600)')
    (temp / 'Registry.swift').write_text(registry, encoding='utf-8')
    navigation = source('Source/Features/Reader/ViewModel/Extensions/Reader+Navigation.swift')
    hook = navigation[navigation.index('    func fetchContentById('):navigation.index('    // MARK: - Navigation Limits')]
    (temp / 'ReaderHook.swift').write_text('import Foundation\nextension FixtureReaderModel {\n' + hook + '}\n', encoding='utf-8')
    adapter_path = 'Source/ZayitSearch/ZayitSearchReaderNavigationAdapter.swift'
    adapter = (subprocess.check_output(['git', 'show', args.adapter_ref + ':' + adapter_path], cwd=ROOT).decode('utf-8')
               if args.adapter_ref else source(adapter_path))
    (temp / 'Adapter.swift').write_text(adapter, encoding='utf-8')
    print('Actual adapter SHA256:', hashlib.sha256(adapter.encode()).hexdigest(), flush=True)
    print('Actual Reader ID hook SHA256:', hashlib.sha256(hook.encode()).hexdigest(), flush=True)
    executable = temp / ('reader-navigation.exe' if os.name == 'nt' else 'reader-navigation')
    command = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library',
               str(temp / 'Locators.swift'), str(temp / 'Registry.swift'), str(temp / 'ReaderHook.swift'),
               str(temp / 'Adapter.swift'), str(ROOT / 'Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift'),
               str(ROOT / 'Source/Features/Reader/Models/OpenBookOptions.swift'),
               str(ROOT / 'Vendor/ZayitSearchPort/Swift/ZayitSearchModels.swift'),
               str(ROOT / 'Tests/HQ/search/ZayitReaderNavigationFixtures.swift'), '-o', str(executable)]
    subprocess.run(command, check=True, cwd=temp)
    subprocess.run([str(executable), namespace], check=True, cwd=temp)
