import pathlib,subprocess,json,datetime,hashlib,gzip,re,sys
root=pathlib.Path.cwd();package=root/'Source/Otzaria/Actions'
label=sys.argv[1];out=root/'build/occurrence-core-20261120'/label;out.mkdir(parents=True,exist_ok=False)
def hashes():
 return {p.relative_to(package).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for top in ['Sources','Tests'] for p in sorted((package/top).rglob('*')) if p.is_file()}
before=hashes()
command=['swift','test','--package-path',str(package),'--scratch-path',str(root/'build/occurrence-core-20261120/swift-build'),'--jobs','4']
if label.startswith('baseline'):command+=['--filter','OccurrenceActionTests']
inputs={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'label':label,'started_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':command,'sources':before,'fixture_boundary':'Actual Core package with explicit port doubles; no actual engine/Apple/UI count. Baseline keeps original executor/registry plus identical additive contract and tests.'}
(out/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n',encoding='utf-8')
p=subprocess.run(command,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=450)
raw=p.stdout;gzip.open(out/'raw.log.gz','wb').write(raw)
text=raw.decode('utf-8',errors='replace');(out/'readable.log').write_text(text,encoding='utf-8')
cases=re.findall(r"Test Case '([^']*OccurrenceActionTests[. ]test[^']*)' (passed|failed)",text)
result={'label':label,'head':inputs['head'],'exit_code':p.returncode,'finished_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_hashes_unchanged':before==hashes(),'raw_log_sha256':hashlib.sha256(raw).hexdigest(),'occurrence_case_results':cases,'summary_lines':[line for line in text.splitlines() if 'Executed ' in line or ("Test Suite " in line and ('passed' in line or 'failed' in line))],'native_executed':0}
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
if not cases:print(text[-9000:])
assert before==hashes(),'Inputs changed during run'
