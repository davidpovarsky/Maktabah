"""Read the original source-bound Clang export for schema2 consumers only.

The five Clang reader definitions and product inventory below are retained
verbatim from the exact v13 SDK; this module has no producer/export authority.
"""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat

MANIFEST = 'SourceProvenance/ClangImportContext.json'
TRANSLATION_SUFFIXES = {'.c', '.cc', '.cpp', '.cxx', '.m', '.mm', '.swift', '.s'}
PATH_TOKEN = re.compile(r'(?:[A-Za-z0-9_.+-]+/)*[A-Za-z0-9_.+-]+')

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def relative_path(value):
    require(isinstance(value, str) and PATH_TOKEN.fullmatch(value)
            and not any(part in {'', '.', '..'} for part in value.split('/')),
            'Unsafe relative Clang declaration path')
    return PurePosixPath(value)

def unaliased(path, root, directory):
    path, root = Path(path), Path(root)
    require(path.is_absolute() and path.is_relative_to(root) and '..' not in path.parts,
            'Clang input escapes its owned root')
    current = root
    for part in path.relative_to(root).parts:
        current /= part
        mode = current.lstat().st_mode
        require(not stat.S_ISLNK(mode), 'Clang input has an unexpected alias')
        if current != path:
            require(stat.S_ISDIR(mode), 'Clang input has a non-directory ancestor')
    require(path.is_dir() if directory else path.is_file(), 'Clang input has the wrong kind')
    return path

def stable_bytes(path):
    path = Path(path)
    before = path.stat()
    raw = path.read_bytes()
    after = path.stat()
    identity = lambda value: (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns)
    require(identity(before) == identity(after) and len(raw) == before.st_size,
            'Clang declaration changed during read')
    return raw

def declaration_inventory(exported):
    result = {}
    for name in ('Clang', 'Include'):
        directory = exported / name
        if not os.path.lexists(directory):
            continue
        unaliased(directory, exported, True)
        for relative, item in inventory(directory).items():
            relative_path(relative)
            require(Path(relative).suffix.lower() not in TRANSLATION_SUFFIXES,
                    'Implementation translation unit in exported Clang declarations')
            result[name + '/' + relative] = item
    return result

def read_clang_imports(exported, expected_identity):
    exported = Path(exported)
    require(not exported.is_symlink(), 'Exported Clang root is an alias')
    exported = exported.resolve(strict=True)
    manifest = unaliased(exported / MANIFEST, exported, False)
    raw = stable_bytes(manifest)
    require(len(raw) <= 32 * 1024 * 1024, 'Oversized Clang declaration manifest')
    identity_fields = ('source_sha', 'run_id', 'run_attempt', 'original_package_lock_sha256')
    require(isinstance(expected_identity, dict)
            and set(expected_identity) == {*identity_fields, 'manifest_sha256'}
            and all(isinstance(value, str) for value in expected_identity.values())
            and re.fullmatch(r'[0-9a-f]{40}', expected_identity['source_sha'])
            and re.fullmatch(r'[1-9][0-9]*', expected_identity['run_id'])
            and re.fullmatch(r'[1-9][0-9]*', expected_identity['run_attempt'])
            and re.fullmatch(r'[0-9a-f]{64}', expected_identity['original_package_lock_sha256'])
            and re.fullmatch(r'[0-9a-f]{64}', expected_identity['manifest_sha256']),
            'Missing externally admitted Clang producer identity')
    require(hashlib.sha256(raw).hexdigest() == expected_identity['manifest_sha256'],
            'Clang manifest differs from its externally admitted digest')
    result = json.loads(raw)
    require(isinstance(result, dict) and result.get('schema') == 1
            and result.get('status') == 'ORIGINAL_CLANG_DECLARATIONS_EXPORTED_NOT_QUALIFIED',
            'Unsupported Clang declaration manifest')
    require(all(result.get(key) == expected_identity[key] for key in identity_fields),
            'Clang manifest producer identity differs')
    require(result.get('implementation_translation_units_exported_or_added') is False
            and result.get('consumer_or_native_qualification') is False,
            'Clang declarations cannot claim consumer or native qualification')
    require(isinstance(result.get('files'), dict) and 1 <= len(result['files']) <= 40000,
            'Missing or excessive exported Clang input inventory')
    for relative, expected in result['files'].items():
        relative_path(relative)
        require(relative.startswith(('Clang/', 'Include/')), 'Clang inventory escapes its export namespace')
        require(isinstance(expected, dict) and set(expected) == {'bytes', 'sha256'}
                and type(expected['bytes']) is int and 0 <= expected['bytes'] <= 8 * 1024 * 1024
                and isinstance(expected['sha256'], str) and re.fullmatch(r'[0-9a-f]{64}', expected['sha256']),
                'Invalid Clang declaration file commitment')
        path = unaliased(exported / relative, exported, False)
        require(path.stat().st_size == expected['bytes'] and sha256(path) == expected['sha256'],
                'Exported Clang declaration differs')
    require(sum(item['bytes'] for item in result['files'].values()) <= 64 * 1024 * 1024,
            'Original Clang declaration closure exceeds reviewed size bound')
    require(declaration_inventory(exported) == result['files'],
            'Clang declaration membership or exact bytes changed')
    maps, roots = result.get('module_maps'), result.get('header_search_paths')
    require(isinstance(maps, list) and 1 <= len(maps) <= 128
            and all(isinstance(item, str) for item in maps) and len(maps) == len(set(maps))
            and isinstance(roots, list) and 1 <= len(roots) <= 256
            and all(isinstance(item, str) for item in roots) and len(roots) == len(set(roots)),
            'Missing or duplicate exported Clang import roots')
    provenance = result.get('module_map_provenance')
    require(isinstance(provenance, list) and len(provenance) == len(maps)
            and all(isinstance(item, dict) for item in provenance)
            and [item.get('path') for item in provenance] == maps,
            'Clang module map provenance differs from the exact import order')
    for relative in maps:
        relative_path(relative)
        require(relative in result['files'] and relative.endswith('.modulemap'),
                'Unrecorded exported Clang module map')
    for item in provenance:
        require(item.get('exported_sha256') == result['files'][item['path']]['sha256']
                and item.get('transformation') in {'EXACT_ORIGINAL_TRACKED_BYTES',
                                                  'EXACT_DECLARATION_PATH_RELOCATION'},
                'Clang module map bytes or transformation differ')
    for relative in roots:
        relative_path(relative)
        require(relative == 'Include' or relative.startswith('Clang/Packages/'),
                'Clang include root escapes the original declaration closure')
        unaliased(exported / relative, exported, True)
    return {'module_maps': maps, 'header_search_paths': roots}

def inventory(root):
    root = Path(root).resolve()
    result = {}
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root).as_posix()
        mode = path.lstat().st_mode
        require(not path.is_symlink(), 'Exported acceptance products must contain materialized files: ' + relative)
        if stat.S_ISDIR(mode):
            continue
        require(stat.S_ISREG(mode), 'Special file in product closure: ' + relative)
        result[relative] = {'bytes': path.stat().st_size, 'sha256': sha256(path)}
    return result


def admitted_context(distribution, expected_identity):
    """Bind this schema2 consumer to the actual v13 nineteen-map closure."""
    value = read_clang_imports(distribution, expected_identity)
    require(len(value['module_maps']) == 19 and len(value['header_search_paths']) == 19,
            'The reviewed original v13 Clang import closure differs')
    return {'producer_identity': dict(expected_identity), **value}


def swift_import_arguments(distribution, context):
    """Mirror the successful original consumer's Clang flags, without a fake Include."""
    actual = admitted_context(distribution, context['producer_identity'])
    require(actual == context, 'Admitted Clang context changed before the compiler probe')
    root = Path(distribution).resolve(strict=True)
    return [argument for path in context['header_search_paths'] for argument in
            ['-Xcc', '-I' + str(root / path)]] + [
            argument for path in context['module_maps'] for argument in
            ['-Xcc', '-fmodule-map-file=' + str(root / path)]]
