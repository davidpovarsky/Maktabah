"""Prepare exact owner-file and registration connections without applying them."""
from pathlib import Path
import difflib, hashlib, json, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/hq-ui-routing'
records={}
def proposal(name,path,before,after,gate):
    patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+path,tofile='b/'+path))
    assert patch
    (OUT/name).write_text(patch,encoding='utf-8',newline='\n')
    with tempfile.TemporaryDirectory(prefix='nowner-',dir='C:/Users/DAVID/.codex/tmp') as temp:
        target=Path(temp)/path; target.parent.mkdir(parents=True,exist_ok=True); target.write_text(before,encoding='utf-8',newline='\n')
        check=subprocess.run(['git','apply','--check',str(OUT/name)],cwd=temp,capture_output=True,text=True)
        assert check.returncode==0,check.stderr
    records[name]={'path':path,'before_sha256':hashlib.sha256(before.encode()).hexdigest(),
        'after_sha256':hashlib.sha256(after.encode()).hexdigest(),'patch_sha256':hashlib.sha256(patch.encode()).hexdigest(),
        'check_exit':check.returncode,'applied':False,'gate':gate}

path='Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift'
before=(ROOT/path).read_text(encoding='utf-8'); after=before
anchor='    @State private var workspace: StudyWorkspaceNavigationAdapter?\n'; assert after.count(anchor)==1
after=after.replace(anchor,'    @State private var workspaceOwner = MaktabahNativeWorkspaceOwner()\n    private var workspace: StudyWorkspaceNavigationAdapter? { workspaceOwner.current }\n')
anchor='            .environment(\\.exact9401Workspace, workspace)\n'; assert after.count(anchor)==1
after=after.replace(anchor,anchor+'            .environment(\\.maktabahNativeWorkspaceOwner, workspaceOwner)\n')
anchor='                workspace = adapter\n'; assert after.count(anchor)==1
after=after.replace(anchor,'                do { try workspaceOwner.replace(with: adapter) } catch { return }\n')
assert 'workspace = adapter' not in after
proposal('N_APP_OWNER_ACTUAL_LIFECYCLE_PRODUCER_UNAPPLIED.diff',path,before,after,'Exact downstream owner-file approval/application; replaces canonical State reference, no mirrored workspace storage')
records['N_APP_OWNER_ACTUAL_LIFECYCLE_PRODUCER_UNAPPLIED.diff']['original_git_blob']=subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()

path='Maktabah.xcodeproj/project.pbxproj'; before=(ROOT/path).read_text(encoding='utf-8'); after=before
for filename,label in [('MaktabahNativePublicBindingAdapter.swift','app-public-binding-adapter'),('MaktabahNativeWorkspaceOwner.swift','app-workspace-owner')]:
    fid=hashlib.sha1(('N-'+label+'-file-20261115').encode()).hexdigest()[:24].upper()
    bid=hashlib.sha1(('N-'+label+'-build-20261115').encode()).hexdigest()[:24].upper()
    assert fid not in before and bid not in before
    after=after.replace('/* End PBXBuildFile section */',f'\t\t{bid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {filename} */; }};\n/* End PBXBuildFile section */')
    after=after.replace('/* End PBXFileReference section */',f'\t\t{fid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Source/ChavrusaText/UIRoutingHost/Integration/{filename}; sourceTree = "<group>"; }};\n/* End PBXFileReference section */')
    anchor='\t\t\t\t65F87859DF502D48133E2C6E /* MaktabahNativeSceneSession.swift */,\n'
    after=after.replace(anchor,anchor+f'\t\t\t\t{fid} /* {filename} */,\n')
    anchor='\t\t\t\t4516A179B623B5FC4CBAC1FF /* MaktabahNativeSceneSession.swift in Sources */,\n'
    after=after.replace(anchor,anchor+f'\t\t\t\t{bid} /* {filename} in Sources */,\n')
proposal('N_APP_OWNER_BOTH_SOURCES_REGISTRATION_UNAPPLIED.diff',path,before,after,'Manager project writer; supersedes earlier adapter-only proposal; R policy dependency also required')

path='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift'; before=(ROOT/path).read_text(encoding='utf-8')
anchor='            session = value\n'; assert before.count(anchor)==1
extra='''            if let workspace, MaktabahNativeRoutingComposition.futurePublicBindingsEnabled {
                try MaktabahNativeRoutingComposition.shared.configureFuturePublicBinding(
                    session: value, manager: manager, workspace: workspace, workspaceOwner: workspaceOwner, enabled: true)
            }
'''
proposal('N_APP_OWNER_FUTURE_MOUNT_CONNECTION_UNAPPLIED.diff',path,before,before.replace(anchor,anchor+extra),'After actual owner producer connection; internal switch stays false; no URL/policy enablement')
(OUT/'N-app-owner-proposals.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Exact canonical owner producer, two-source registration and default-off mount proposals check clean; none applied.')
