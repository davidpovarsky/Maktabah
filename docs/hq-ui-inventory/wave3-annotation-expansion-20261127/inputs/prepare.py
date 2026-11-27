from pathlib import Path
import hashlib, json, difflib, zipfile

ROOT = Path(__file__).parent
PATH = 'Source/Features/Annotations/iOS/iOSAnnotationViewController.swift'
BASE = ROOT.parent / 'annotations-selection-analysis/candidate' / PATH
raw = BASE.read_bytes()
assert hashlib.sha256(raw).hexdigest() == 'bf7bc1ea1bb559e02a7904dad3508fab1c265ecd07e1592365cab045aecbc714'
text = raw.decode()

def method(source, signature):
    start = source.index(signature)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

signature = '    private func setOriginalGroupExpanded('
before = method(text, signature)
after = before.replace('animated: Bool) {', 'animated: Bool,\n                                          validating isCurrent: (@MainActor () -> Bool)? = nil) {\n        guard isCurrent?() ?? true else { return }', 1)
after = after.replace('        if willExpand {\n            sectionSnapshot.expand', '        guard isCurrent?() ?? true else { return }\n        if willExpand {\n            sectionSnapshot.expand', 1)
after = after.replace('        if let indexPath = dataSource.indexPath(for: groupItem),\n           let cell = collectionView.cellForItem(at: indexPath)\n        {', '        guard isCurrent?() ?? true else { return }\n        if let indexPath = dataSource.indexPath(for: groupItem),\n           let cell = collectionView.cellForItem(at: indexPath)\n        {\n            guard isCurrent?() ?? true else { return }', 1)
after = after.replace('                if var config = cell.contentConfiguration as? ListContentConfiguration {\n                    config.isExpanded', '                guard isCurrent?() ?? true else { return }\n                if var config = cell.contentConfiguration as? ListContentConfiguration {\n                    guard isCurrent?() ?? true else { return }\n                    config.isExpanded', 1)
old_call = '            setOriginalGroupExpanded(row.group, willExpand: true, animated: false)'
new_call = '''            setOriginalGroupExpanded(row.group, willExpand: true, animated: false,
                validating: { (try? requireCurrent()) != nil })'''
assert text.count(before) == 1 and text.count(old_call) == 1
candidate = text.replace(before, after).replace(old_call, new_call)
inverse = candidate.replace(after, before).replace(new_call, old_call)
assert inverse.encode() == raw
for directory, data in [('baseline', raw), ('candidate', candidate.encode())]:
    path = ROOT / directory / PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
controls = ROOT / 'controls'; controls.mkdir(exist_ok=True)
for name, fragment in [('OriginalExpansion', before), ('CandidateExpansion', after)]:
    # One access modifier is removed only to call the verbatim private method
    # from the standalone source capsule. All method bodies remain exact.
    source = '@MainActor final class OriginalController {\n' + '''    var expandedGroups: Set<String> = []
    let dataSource = OriginalDataSource()
    let collectionView = OriginalCollection()
''' + fragment.replace('    private func', '    func', 1) + '\n}\n'
    if name == 'OriginalExpansion':
        source += '''extension OriginalController {
    func invoke(_ node: SwiftUIAnnotationNode, native: Bool, validating: @escaping @MainActor () -> Bool) {
        setOriginalGroupExpanded(node, willExpand: true, animated: !native)
    }
}
'''
    else:
        source += '''extension OriginalController {
    func invoke(_ node: SwiftUIAnnotationNode, native: Bool, validating: @escaping @MainActor () -> Bool) {
        setOriginalGroupExpanded(node, willExpand: true, animated: !native, validating: native ? validating : nil)
    }
}
'''
    (controls / (name + '.swift')).write_text(source)
receipt = {'base_commit': '8f7142bba6efb8f4a93c4e325ee6cdb835041bb5', 'path': PATH,
    'before_sha256': hashlib.sha256(raw).hexdigest(), 'after_sha256': hashlib.sha256(candidate.encode()).hexdigest(),
    'before_bytes': len(raw), 'after_bytes': len(candidate.encode()), 'whole_file_inverse': inverse.encode() == raw,
    'helper_before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'helper_after_sha256': hashlib.sha256(after.encode()).hexdigest(),
    'edits': [{'before': before, 'after': after}, {'before': old_call, 'after': new_call}],
    'scope': 'Only original expansion helper and its nativeRoutingReveal call. Nil validation preserves ordinary call arguments and effects. No UIKit/native execution.'}
(ROOT / 'SOURCE_INVERSE.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
(ROOT / 'SOURCE.diff').write_text(''.join(difflib.unified_diff(text.splitlines(True), candidate.splitlines(True), 'a/' + PATH, 'b/' + PATH)))
print(json.dumps({k:v for k,v in receipt.items() if k not in ['edits']}))
