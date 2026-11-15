"""Exact unapplied registration/lifecycle/reader-witness proposals only."""
from pathlib import Path
import difflib, hashlib, json, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/hq-ui-routing'
records = {}
def proposal(name, path, before, after, gate):
    assert before != after
    patch = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='a/'+path, tofile='b/'+path))
    (OUT / name).write_text(patch, encoding='utf-8', newline='\n')
    with tempfile.TemporaryDirectory(prefix='nap-', dir='C:/Users/DAVID/.codex/tmp') as temp:
        target = Path(temp) / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_text(before, encoding='utf-8', newline='\n')
        result = subprocess.run(['git','apply','--check',str(OUT/name)], cwd=temp, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
    records[name] = {'path': path, 'original_normalized_sha256': hashlib.sha256(before.encode()).hexdigest(),
        'proposed_normalized_sha256': hashlib.sha256(after.encode()).hexdigest(), 'patch_sha256': hashlib.sha256(patch.encode()).hexdigest(),
        'apply_check_exit': result.returncode, 'gate': gate, 'applied': False}

path = 'Maktabah.xcodeproj/project.pbxproj'; before = (ROOT/path).read_text(encoding='utf-8')
fid = hashlib.sha1(b'N-app-public-binding-adapter-file-20261115').hexdigest()[:24].upper()
bid = hashlib.sha1(b'N-app-public-binding-adapter-build-20261115').hexdigest()[:24].upper()
assert fid not in before and bid not in before
filename = 'MaktabahNativePublicBindingAdapter.swift'
after = before.replace('/* End PBXBuildFile section */', f'\t\t{bid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {filename} */; }};\n/* End PBXBuildFile section */')
after = after.replace('/* End PBXFileReference section */', f'\t\t{fid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Source/ChavrusaText/UIRoutingHost/Integration/{filename}; sourceTree = "<group>"; }};\n/* End PBXFileReference section */')
anchor = '\t\t\t\t65F87859DF502D48133E2C6E /* MaktabahNativeSceneSession.swift */,\n'; assert after.count(anchor)==1
after = after.replace(anchor, anchor+f'\t\t\t\t{fid} /* {filename} */,\n')
anchor = '\t\t\t\t4516A179B623B5FC4CBAC1FF /* MaktabahNativeSceneSession.swift in Sources */,\n'; assert after.count(anchor)==1
after = after.replace(anchor, anchor+f'\t\t\t\t{bid} /* {filename} in Sources */,\n')
proposal('N_APP_BINDING_REGISTRATION_UNAPPLIED.diff',path,before,after,'Manager project writer only; also integrate R44 policy registration/dependency first')
path = 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift'; before=(ROOT/path).read_text(encoding='utf-8')
anchor = '            session = value\n'; assert before.count(anchor)==1
addition = '''            if let workspace, MaktabahNativeRoutingComposition.futurePublicBindingsEnabled {
                try MaktabahNativeRoutingComposition.shared.configureFuturePublicBinding(
                    session: value, manager: manager, workspace: workspace, enabled: true)
            }
'''
proposal('N_APP_BINDING_LIFECYCLE_UNAPPLIED.diff',path,before,before.replace(anchor,anchor+addition),'Manager application after new N sources; internal switch remains false; no public route/registry opt-in')
path='Source/UI/iOS/Views/iPadLayout.swift'; before=(ROOT/path).read_text(encoding='utf-8')
anchor='                .accessibilityIdentifier("reader-detail-column")\n'; assert before.count(anchor)==1
proposal('N_APP_BINDING_LEGACY_READER_WITNESS_UNAPPLIED.diff',path,before,before.replace(anchor,anchor+'                .modifier(MaktabahNativeRoutingSurface(kind: .reader))\n'),'Protected exact one-hunk owner review required; passive witness only; other reader layouts remain unavailable without their own actual witness')
(OUT/'N-app-binding-proposals.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Three exact unapplied proposals check clean; project/upstream/current native run unchanged.')
