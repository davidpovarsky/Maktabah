"""Prepare the smallest selector-only schema 2 child, preserving schema 1."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
original_path = ROOT / 'original/select-runtime27-toolchain.py'
raw = original_path.read_bytes()
expected_blob = '670b5462928640a20e60373d8cbf5bbfca448d9a'
def git_blob(value):
    return hashlib.sha1(b'blob ' + str(len(value)).encode() + b'\0' + value).hexdigest()
if git_blob(raw) != expected_blob:
    # apply_patch's final empty added line is permitted only when exact inversion
    # reaches the immutable GitHub blob; no newline normalization is performed.
    if raw.endswith(b'\n') and git_blob(raw[:-1]) == expected_blob:
        raw = raw[:-1]
        original_path.write_bytes(raw)
    else:
        raise RuntimeError('Original selector differs from its immutable Git blob')
old = raw.decode()
needle = '    if (config.get("schema") != 1 or config.get("repository") != "davidpovarsky/anytype-swift"\n'
replacement = '''    if config.get("schema") == 2:
        import runpy
        continuation = runpy.run_path(str(Path(__file__).with_name("original_editor_continuation_admission.py")))
        framework, _ = continuation["validate_configuration"](config)
        if config.get("toolchain") != framework["toolchain"]:
            raise RuntimeError("Original SDK toolchain differs from the exact retained framework producer")
    elif (config.get("schema") != 1 or config.get("repository") != "davidpovarsky/anytype-swift"
'''
assert old.count(needle) == 1
new = old.replace(needle, replacement)
assert new.replace(replacement, needle) == old
out = ROOT / 'candidate/Scripts/CI'
out.mkdir(parents=True, exist_ok=True)
(out / 'select-runtime27-toolchain.py').write_bytes(new.encode())
helper = ROOT.parent / 'candidate/Scripts/CI/original_editor_continuation_admission.py'
shutil.copyfile(helper, out / helper.name)
for path in [original_path, out / 'select-runtime27-toolchain.py']:
    ast.parse(path.read_bytes(), filename=str(path))
before_functions = {n.name: ast.dump(n, include_attributes=False) for n in ast.parse(old).body if isinstance(n, ast.FunctionDef)}
after_functions = {n.name: ast.dump(n, include_attributes=False) for n in ast.parse(new).body if isinstance(n, ast.FunctionDef)}
changed = [name for name in before_functions if before_functions[name] != after_functions[name]]
assert changed == ['original_editor_toolchain']
(ROOT / 'SELECTOR.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
    fromfile='a/Scripts/CI/select-runtime27-toolchain.py', tofile='b/Scripts/CI/select-runtime27-toolchain.py')))
def identity(path):
    value = path.read_bytes()
    return dict(path=path.relative_to(ROOT).as_posix(), bytes=len(value), sha256=hashlib.sha256(value).hexdigest(), git_blob=git_blob(value))
manifest = dict(base='b09c95f3eee6aa3b8fe363cfac76a89025c15abe', original=identity(original_path),
    candidate=identity(out / 'select-runtime27-toolchain.py'), unchanged_helper=identity(out / helper.name),
    changed_functions=changed, exact_delta_inverse=True,
    prior_six_selector_controls_replayed=0, prior_version_stream_control_replayed=0,
    prior_twenty_schema2_controls_replayed=0, runtime_input_manifest_changed=False,
    scope='Schema 2 selector admission only. Schema 1 and optional default control flow remain byte-identical after inverting the one guarded branch.')
(ROOT / 'SOURCE_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest))
