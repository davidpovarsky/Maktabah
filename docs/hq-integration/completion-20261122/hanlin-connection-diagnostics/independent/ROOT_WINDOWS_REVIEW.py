import pathlib,json,hashlib,zipfile,subprocess,ast,datetime,re,stat
p=pathlib.Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-validation-20261122')
repo=pathlib.Path(r'C:\Users\DAVID\Code\Maktabah-hanlin-diagnostics-20261122')
sha=lambda b:hashlib.sha256(b).hexdigest()
def need(v,m):
 if not v:raise AssertionError(m)
ib=(p/'FILE_INDEX.json').read_bytes();need(sha(ib)=='e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98','index')
idx=json.loads(ib);need(len(idx['files'])==42,'payload count')
seen=set()
for row in idx['files']:
 n=row['path'];x=pathlib.PurePosixPath(n);need(n not in seen and not x.is_absolute() and '..' not in x.parts and '\\' not in n,'path');seen.add(n)
 b=(p/n).read_bytes();need(len(b)==row['bytes'] and sha(b)==row['sha256'],'payload '+n)
need(sum(x['bytes'] for x in idx['files'])==580724,'payload bytes')
need({x.relative_to(p).as_posix() for x in p.rglob('*') if x.is_file()}==seen|{'FILE_INDEX.json'},'frozen extras')
li=json.loads((p/'linux-posix/LINUX_FILE_INDEX.json').read_bytes());need(len(li['files'])==12,'linux payloads')
with zipfile.ZipFile(p/'linux-posix-evidence.zip') as z:
 need(z.testzip() is None,'archive CRC'); names=set()
 for ent in z.infolist():
  n=ent.filename;pp=pathlib.PurePosixPath(n);need(not ent.is_dir() and not pp.is_absolute() and '..' not in pp.parts and '\\' not in n and n not in names and not stat.S_ISLNK(ent.external_attr>>16),'archive safe');names.add(n)
  need(z.read(ent)==(p/'linux-posix'/n).read_bytes(),'archive copy '+n)
 need({r['path'] for r in li['files']} <= names <= {r['path'] for r in li['files']}|{'LINUX_FILE_INDEX.json'},'archive membership')
 zipcount=len(names)
for r in li['files']:
 b=(p/'linux-posix'/r['path']).read_bytes();need(len(b)==r['bytes'] and sha(b)==r['sha256'],'linux index')
result=json.loads((p/'linux-posix/python-result.json').read_bytes());execution=json.loads((p/'linux-posix/PYTHON_EXECUTION.json').read_bytes())
need(result['status']=='PASS' and (result['namedTests'],result['failures'],result['errors'],result['skipped'])==(34,0,0,0),'python counts')
need(execution['exitCode']==0 and execution['timedOut'] is False and result['pid']==execution['childPID']==5,'actual command')
testtree=ast.parse((p/'linux-posix/diagnostic_boundary_controls.py').read_bytes())
testclass=next(n for n in testtree.body if isinstance(n,ast.ClassDef) and n.name=='DiagnosticBoundaryTests')
expected={n.name for n in testclass.body if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
need(len(expected)==34 and len(result['cases'])==34 and {r['name'].rsplit('.',1)[1] for r in result['cases']}==expected and all(r['status']=='PASS' for r in result['cases']),'exact case identities')
stderr=(p/'linux-posix/python.stderr').read_bytes();stdout=(p/'linux-posix/python.stdout').read_bytes()
need(sha(stderr)==execution['stderrSHA256'] and sha(stdout)==execution['stdoutSHA256'],'streams')
need(b'Ran 34 tests' in stderr and stderr.rstrip().endswith(b'OK'),'raw unittest result')
for r in result['inputs']:
 b=(p/'linux-posix'/r['path']).read_bytes();need(sha(b)==r['sha256'] and len(b)==r['bytes'],'python executed input')
need(len(result['observations'])==97 and set(result['unchangedInputs'])=={x['path'] for x in result['inputs']},'observed inputs')
swift=json.loads((p/'windows-syntax/RESULT.json').read_bytes());sx=json.loads((p/'windows-syntax/EXECUTION.json').read_bytes())
need(swift['status']=='PASS' and swift['completeSwiftFiles']==4 and swift['sourceUnchanged'] is True and swift['commands']==sx['commands'],'swift commands')
need(len(swift['commands'])==5 and all(r['exitCode']==0 for r in swift['commands']),'swift exits')
for item in sx['environment'].values():
 if isinstance(item,dict) and 'path' in item and 'sha256' in item:
  b=pathlib.Path(item['path']).read_bytes();need(sha(b)==item['sha256'] and len(b)==item['bytes'],'current compiler bytes')
for row in swift['commands']:
 for stream in ['stdout','stderr']:
  b=(p/'windows-syntax'/(row['name']+'.'+stream)).read_bytes();need(sha(b)==row[stream+'SHA256'],'Swift raw stream')
 if row['name'].startswith('parse-'):
  need('-parse' in row['command'] and 'DEBUG' in row['command'] and 'arm64-apple-ios27.2-simulator' in row['command'],'parse-only target')
  need(b"using sysroot for 'Windows' but targeting 'iPhone'" in (p/'windows-syntax'/(row['name']+'.stderr')).read_bytes(),'retained platform warning')
inputs=json.loads((p/'INPUTS.json').read_bytes())['files'];need(len(inputs)==5,'five source files')
def git(*a):return subprocess.check_output(['git','-c','core.autocrlf=false',*a],cwd=repo,timeout=60)
source='6aa953048453b64a0013621ce76e095770eb7e7d';base='4287063689fb2f17ea9a8fcd436ed98e6985f21f'
need(git('rev-parse',source+'^').decode().strip()==base,'source parent')
need(set(git('diff','--name-only',base,source).decode().splitlines())=={r['path'] for r in inputs},'five-file source scope')
for row in inputs:
 old=git('show',base+':'+row['path']);new=git('show',source+':'+row['path'])
 need(sha(old)==row['preimageSHA256'] and sha(new)==row['sha256'] and len(new)==row['bytes'] and new==(p/'inputs'/row['path']).read_bytes(),'immutable source '+row['path'])
trees={'Source':'91c1adf6c97cd8676e8b2c76860a40f78924b1ec','Vendor':'4065c0e62af325e83a65fe0c70270985229807ae','Maktabah.xcodeproj':'8c0fa1ccfbcfae01fae3c267512864e00efcf078','Maktabah-iOSUITests':'24345d612f8c70398f4590977f8b4696021ae413'}
for n,w in trees.items():need(git('rev-parse',source+':'+n).decode().strip()==w,'tree '+n)
out=pathlib.Path(r'C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\live_diagnostic_root_review.json');need(not out.exists(),'review exists')
proof={'status':'PASS','scope':'Read-only independent source/evidence verification. No test, parse, build, credential, download or CI replay','createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'parent':base,'packetIndexSHA256':sha(ib),'payloadsVerified':42,'payloadBytes':580724,'linuxIndexedPayloads':12,'safeCRCZIPFiles':zipcount,'pythonCasesVerified':34,'pythonFailuresErrorsSkips':0,'pythonObservations':97,'pythonWholeModuleAndRealPOSIXFiles':True,'threeMainCasesBoundary':'Explicit external source/matrix dependency probes; no Native execution','swiftCompleteFileSyntaxParses':4,'swiftBoundary':'Windows frontend parse with DEBUG+Simulator target only, both sysroot warnings retained, no Apple SDK typecheck/link/runtime','currentWindowsCompilerFilesMatched':2,'fiveProductInputsExact':True,'fourProductTrees':trees,'oldSuitesReplayed':False,'credentialAction':False,'scriptSHA256':sha(pathlib.Path(__file__).read_bytes())}
out.write_bytes((json.dumps(proof,indent=2)+'\n').encode());print(json.dumps({'status':'PASS','path':str(out),'sha256':sha(out.read_bytes()),'script':str(pathlib.Path(__file__)),'scriptSHA256':proof['scriptSHA256'],'payloads':42,'pythonCases':34,'swiftParseFiles':4}))
