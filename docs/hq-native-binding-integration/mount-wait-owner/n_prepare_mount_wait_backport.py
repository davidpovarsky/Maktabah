from pathlib import Path
import difflib,hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/hq-ui-routing'
BASE='0436775d85893225005f29baf0aa3a20d7b88317'
PATH='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift'
original=subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT).decode()
first='                guard let self, mountWaiters[managerID]?.token == token else { return }'
second='                mountWaiters.removeValue(forKey: managerID)?.continuation.resume(throwing: CancellationError())'
assert original.count(first)==1 and original.count(second)==1
fixed=original.replace(first,first.replace('mountWaiters','self.mountWaiters')).replace(second,second.replace('mountWaiters','self.mountWaiters'))
working=(ROOT/PATH).read_text(encoding='utf-8')
def method(text):
    start=text.index('    private func waitForMount(')
    end=text.index('\n    }',start)+len('\n    }')
    return text[start:end]
assert method(fixed)==method(working)
prior=subprocess.check_output(['git','show','d583086f017469a29f698d02d64c8cc66b4fb722:'+PATH],cwd=ROOT).decode()
assert method(prior)==method(original), 'Complete frozen and future methods must have identical original input'
patch=''.join(difflib.unified_diff(original.splitlines(True),fixed.splitlines(True),fromfile='a/'+PATH,tofile='b/'+PATH))
name='N_043_MOUNT_WAIT_EXPLICIT_SELF_UNAPPLIED.diff'
(OUT/name).write_text(patch,encoding='utf-8',newline='\n')
with tempfile.TemporaryDirectory(prefix='nmount043-',dir='C:/Users/DAVID/.codex/tmp') as temp:
    dest=Path(temp)/PATH;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(original,encoding='utf-8',newline='\n')
    check=subprocess.run(['git','apply','--check',str(OUT/name)],cwd=temp,capture_output=True,text=True);assert check.returncode==0,check.stderr
with tempfile.TemporaryDirectory(prefix='nmount98-',dir='C:/Users/DAVID/.codex/tmp') as temp:
    candidate=subprocess.check_output(['git','show','98b575fc2d25f085de69081b445825c677d7b9aa:'+PATH],cwd=ROOT).decode()
    dest=Path(temp)/PATH;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(candidate,encoding='utf-8',newline='\n')
    candidate_check=subprocess.run(['git','apply','--check',str(OUT/name)],cwd=temp,capture_output=True,text=True);assert candidate_check.returncode==0,candidate_check.stderr
changed=[x for x in difflib.ndiff(original.splitlines(),fixed.splitlines()) if x[:2] in ['+ ','- ']]
assert len(changed)==4
manifest={'base':BASE,'base_source_git_blob':subprocess.check_output(['git','rev-parse',BASE+':'+PATH],cwd=ROOT,text=True).strip(),
    'production_path':PATH,'patch':name,'patch_sha256':hashlib.sha256(patch.encode()).hexdigest(),'git_apply_check_exit':check.returncode,
    'separate_candidate_98_apply_check_exit':candidate_check.returncode,
    'changed_lines':2,'only_change':'self. prefix for two mountWaiters accesses inside nested MainActor cancellation Task',
    'before_complete_method_sha256':hashlib.sha256(method(original).encode()).hexdigest(),
    'after_complete_method_sha256':hashlib.sha256(method(fixed).encode()).hexdigest(),
    'complete_future_and_frozen_methods_match_before_and_after':True,'new_public_API_or_v2_in_backport':False,
    'manager_or_frozen_tree_modified':False,'native_SDK_retry':'NOT_REQUESTED_NOT_RUN'}
(OUT/'N-mount-wait-backport.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Exact compatible043 two-line patch checks clean; complete frozen/future method equivalence verified.')
