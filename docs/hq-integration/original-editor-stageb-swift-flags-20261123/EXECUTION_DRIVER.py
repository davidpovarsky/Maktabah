import pathlib,json,hashlib,subprocess,os,time,signal,traceback
root=pathlib.Path('/mnt/development/projects/diagnostics/otzaria-original-editor-stageb-20261123/swift-flags-repair')
out=root/'actual-controls';out.mkdir(exist_ok=False)
prior=pathlib.Path('/mnt/development/projects/diagnostics/otzaria-original-editor-stageb-20261123/ruby-context-repair/portable-ruby/ADMISSION.json')
admission=json.loads(prior.read_text());ruby=prior.parent/'root/usr/bin/ruby3.2'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(ruby.read_bytes())=='bbea1a842298c961c1ad29d359f2b45eff1b25ae546d59e72590846c039efac2'
env=dict(os.environ);env.update(admission['environment_overrides'])
candidate=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-original-editor-stageb-20261123/Scripts/CI/hq-original-editor-app-target.rb')
assert candidate.read_bytes()==(root/'after.rb').read_bytes()
result={'status':'RUNNING','scope':'ACTUAL_RUBY_3_2_3_EXTRACTED_ORIGINAL_FLAG_BLOCK','ruby':str(ruby),'ruby_sha256':sha(ruby.read_bytes()),'prior_runtime_admission_sha256':sha(prior.read_bytes()),'source_sha256':sha(candidate.read_bytes()),'commands':[],'apple_app_ui':'NOT_RUN','gem_or_runtime_install':False}
def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
def command(label,args,expected):
 a=out/(label+'.stdout');b=out/(label+'.stderr');timed=False;t=time.monotonic()
 with a.open('wb') as f,b.open('wb') as e:
  p=subprocess.Popen([str(ruby),*map(str,args)],stdout=f,stderr=e,env=env,start_new_session=True)
  try:rc=p.wait(timeout=25)
  except subprocess.TimeoutExpired:
   timed=True;os.killpg(p.pid,signal.SIGTERM)
   try:rc=p.wait(timeout=5)
   except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);rc=p.wait(timeout=5)
 try:os.killpg(p.pid,0);drained=False
 except ProcessLookupError:drained=True
 row={'label':label,'argv':[str(ruby),*map(str,args)],'returncode':rc,'expected_returncode':expected,'timed_out':timed,'child_reaped':p.poll() is not None,'owned_group_drained':drained,'elapsed_seconds':time.monotonic()-t,'stdout_sha256':sha(a.read_bytes()),'stderr_sha256':sha(b.read_bytes())}
 result['commands'].append(row);save();assert not timed and drained and p.poll() is not None and rc==expected,repr(row)+' '+b.read_text()[:500]
 return a.read_text(),b.read_text()
save()
try:
 availability,_=command('existing-genuine-xcodeproj-availability',['-e','require "json"; require "rubygems"; specs=Gem::Specification.find_all_by_name("xcodeproj"); puts JSON.generate({ruby:RUBY_DESCRIPTION,xcodeproj_specs:specs.map{|s| {version:s.version.to_s,path:s.full_gem_path}},genuine_available:specs.any?{|s| s.version.to_s != "0.0.1"}})'],0)
 result['existing_xcodeproj']=json.loads(availability)
 command('whole-helper-syntax',['-c',candidate],0)
 _,err=command('original-authentic-flags-refusal',[root/'FlagControls.rb',root/'before.rb',root/'ACTUAL_INPUTS.json','--baseline-only'],1)
 assert 'Unexpected original Swift flag shape' in err
 payload,_=command('candidate-six-focused-cases',[root/'FlagControls.rb',candidate,root/'ACTUAL_INPUTS.json'],0)
 controls=json.loads(payload);assert controls['status']=='PASS' and len(controls['cases'])==6 and controls['assertions']==19
 result.update(status='PASS',controls=controls,old_baseline_refusal_retained=True,original_old_controls='UNCHANGED_NOT_REPLAYED',full_xcodeproj_project_mutation='NOT_RUN_NO_INSTALLED_GENUINE_XCODEPROJ' if not result['existing_xcodeproj']['genuine_available'] else 'AVAILABLE_NOT_YET_EXECUTED')
except BaseException as e:
 result['status']='FAIL';result['error']=type(e).__name__+': '+str(e);(out/'driver-error.log').write_text(traceback.format_exc());save();raise
save();print(json.dumps({'status':result['status'],'cases':len(result['controls']['cases']),'assertions':result['controls']['assertions'],'commands':len(result['commands']),'ruby_sha256':result['ruby_sha256'],'genuine_xcodeproj_available':result['existing_xcodeproj']['genuine_available'],'result_sha256':sha((out/'RESULT.json').read_bytes())},indent=2))
