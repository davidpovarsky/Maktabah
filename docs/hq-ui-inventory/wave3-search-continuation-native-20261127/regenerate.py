from pathlib import Path
import hashlib, difflib, json

root = Path(__file__).resolve().parent
path = 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift'
base = (root / 'baseline' / path).read_text()
assert hashlib.sha256(base.encode()).hexdigest() == '2d60519f70e47ec00747efa0a6cf967e8ede5129e2c1d351bcc8151d9a911a45'
new = base.replace('import Foundation\n', 'import Foundation\n#if DEBUG\nimport CryptoKit\n#endif\n', 1)
old_kinds = '"journey-commentary-draft", "journey-catalog-stop"].contains(kind) else { return nil }'
new_kinds = '"journey-commentary-draft", "journey-catalog-stop",\n               "search-continuation-hit", "search-continuation-page"].contains(kind) else { return nil }'
assert new.count(old_kinds) == 1
new = new.replace(old_kinds, new_kinds, 1)
entry = '    func runSearchResultsAcceptanceProbe(manager: iOSNavigationManager) async {\n'
assert new.count(entry) == 1
dispatch = '''        for kind in ["search-continuation-hit", "search-continuation-page"] {
            if let probe = MaktabahNativeActionAcceptanceProbe(kind: kind) {
                await runSearchContinuationAcceptanceProbe(probe, manager: manager)
                return
            }
        }
'''
new = new.replace(entry, entry + dispatch, 1)
tail = '\n#endif\n\n#endif\n'
assert new.endswith(tail)
addition = (root / 'DEBUG_PROBE_ADDITION.swift').read_text()
insert = '\n\n' + addition
new = new[:-len(tail)] + insert + tail
inverse = new.replace(insert, '', 1).replace(entry + dispatch, entry, 1).replace(new_kinds, old_kinds, 1).replace('import Foundation\n#if DEBUG\nimport CryptoKit\n#endif\n', 'import Foundation\n', 1)
assert inverse == base
(root / 'candidate' / path).write_text(new)
patch = ''.join(difflib.unified_diff(base.splitlines(True), new.splitlines(True), fromfile='a/' + path, tofile='b/' + path))
(root / 'SEARCH_CONTINUATION_DEBUG.patch').write_text(patch)
native_path = 'Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift'
native_base = (root.parent / 'profile-group-native' / 'candidate' / native_path).read_bytes()
assert len(native_base) == 259080
assert hashlib.sha256(native_base).hexdigest() == '7f735919df764571929bb858dd21e082c7a52b68d01b9e15b65aa738284ee4ad'
native_add = (root / 'NATIVE_HELPER_ADDITION.swift').read_bytes()
(root / 'candidate' / native_path).write_bytes(native_base + native_add)
def pin(data): return {'bytes':len(data), 'sha256': hashlib.sha256(data).hexdigest()}
receipt = {'baseCommit':'ec5385e863a478e368c7de47264474a440fd0734', 'compositionBase':pin(base.encode()),
    'compositionCandidate':pin(new.encode()), 'patch':pin(patch.encode()), 'inverseExact':True,
    'nativeOriginalPrefix':pin(native_base), 'nativeCandidate':pin(native_base + native_add),
    'nativePrefixExact':True, 'sdkTypecheck':'NOT_RUN', 'nativeExecution':'NOT_RUN'}
(root / 'PROBE_PATCH_RECEIPT.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
