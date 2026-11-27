"""Structural host admission witness, deliberately not SwiftUI/runtime proof."""
import hashlib
import json
import pathlib
import sys

def closing_brace(source, opening):
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == '{':
            depth += 1
        elif source[index] == '}':
            depth -= 1
            if depth == 0:
                return index
    raise ValueError('Unbalanced inspected body')

def inspect(path):
    raw = pathlib.Path(path).read_bytes()
    source = raw.decode()
    body = source[source.index('    var body: some View {'):source.index('\n    @ViewBuilder')]
    visibility = body.index('if viewModel.readerInspectorVisible,')
    visible_end = closing_brace(body, body.index('{', visibility))
    observer = body.index('.onChange(of: backendCoordinator.generation')
    open_action_preserved = 'initial: true) { previous, current in' in body and (
        'if previous != current { viewModel.closeReaderInspector() }' in body)
    return {'path': str(path), 'sha256': hashlib.sha256(raw).hexdigest(),
            'generationObserverOutsideVisibilityBranch': observer > visible_end,
            'initialAdmissionPreservesOpenActionBySource': open_action_preserved,
            'scope': 'structural admission only; whole-source Apple typecheck recorded separately; no UI execution'}

if __name__ == '__main__':
    print(json.dumps({'baseline': inspect(sys.argv[1]), 'candidate': inspect(sys.argv[2])}, indent=2, sort_keys=True))
