import subprocess,json,pathlib,hashlib,datetime,shutil,os
w=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-integration-20261127')
out=w/'build/wave3-selective-intake-20261127-0820'; assert out.exists()
gprefix=['git','-C',str(w),'-c','gc.auto=0','-c','maintenance.auto=false']
def g(*a):return subprocess.check_output(gprefix+list(a))
assert g('rev-parse','HEAD').decode().strip()=='206d52b644daf93781611ef1f62bf6b29c2400fe'
assert not g('status','--porcelain=v1')
additions=[{"en":"Search book filter","he":"סינון החיפוש לפי ספר"},{"en":"Search mode","he":"מצב חיפוש"},{"en":"Exact phrase","he":"ביטוי מדויק"},{"en":"Search order","he":"סדר התוצאות"},{"en":"Relevance","he":"רלוונטיות"},{"en":"Book order","he":"סדר הספרים"},{"en":"Chronological","he":"סדר כרונולוגי"},{"en":"Show search results","he":"הצגת תוצאות חיפוש"},{"en":"Search for an exact phrase in the current library and display its results in the selected Maktabah window. Book filters are available in the Otzaria library. Sorting choices depend on the selected library.","he":"חיפוש ביטוי מדויק בספרייה הפעילה והצגת התוצאות בחלון אוצריא שנבחר. סינון לפי ספרים זמין בספריית אוצריא. אפשרויות המיון תלויות בספרייה שנבחרה."},{"en":"Search phrase","he":"ביטוי לחיפוש"},{"en":"Books (optional)","he":"ספרים (רשות)"},{"en":"Sort results","he":"מיון תוצאות"},{"en":"Window","he":"חלון"},{"en":"Search","he":"חיפוש"}]
p=w/'Source/Localizable.xcstrings';before=p.read_bytes();c=json.loads(before)
original=json.loads(before);added=[];reused=[]
for item in additions:
 k=item['en']
 if k in c['strings']:
  reused.append(k);continue
 c['strings'][k]={'extractionState':'manual','localizations':{lang:{'stringUnit':{'state':'translated','value':value}}for lang,value in [('en',k),('he',item['he'])]}}
 added.append(k)
assert len(original['strings'])==703 and len(added)==10
assert all(c['strings'][k]==v for k,v in original['strings'].items())
p.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
short=w/'Source/ChavrusaText/UIRoutingHost/Integration/AppShortcuts.xcstrings';shortbefore=short.read_bytes();s=json.loads(shortbefore);olds=json.loads(shortbefore)
key='Show search results in ${applicationName}'
assert key not in s['strings']
s['strings'][key]={'localizations':{'he':{'stringUnit':{'state':'translated','value':'הצג תוצאות חיפוש באפליקציה ${applicationName}'}}}}
assert len(olds['strings'])==2 and all(s['strings'][k]==v for k,v in olds['strings'].items())
assert s['strings'][key]['localizations']['he']['stringUnit']['value'].count('${applicationName}')==1
short.write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n')
sha=lambda b:hashlib.sha256(b).hexdigest()
localization={'schema':1,'sourceHead':'206d52b644daf93781611ef1f62bf6b29c2400fe','localizable':{'beforeSHA256':sha(before),'afterSHA256':sha(p.read_bytes()),'preservedOriginalEntries':703,'addedEntries':added,'reusedUnmodifiedEntries':reused,'finalEntries':713},'appShortcuts':{'beforeSHA256':sha(shortbefore),'afterSHA256':sha(short.read_bytes()),'preservedOriginalEntries':2,'addedKey':key,'placeholderBasis':'Both existing original AppShortcuts keys use the literal ${applicationName}; the fixed new Swift provider phrase uses the same original interpolation.','metadataExtraction':'NOT_RUN'},'parameterSummary':'Await original Apple metadata extraction for exact dynamic query/window placeholders; no guessed catalog key.','nativeHE_EN_Siri':'NOT_RUN'}
(out/'LOCALIZATION.json').write_text(json.dumps(localization,ensure_ascii=False,indent=2)+'\n')
sourcepaths=['Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift','Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeIntents.swift','Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSearchIntentService.swift','Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSearchIntents.swift','Source/Features/History/ViewModel/Extensions/History+Database.swift','Source/Features/History/ViewModel/HistoryViewModel.swift','Source/LibraryBackend/QualifiedLocatorStore.swift']
swift=shutil.which('swiftc');assert swift
parse=[]
for i,path in enumerate(sourcepaths):
 cmd=[swift,'-frontend','-parse','-target','arm64-apple-ios27.0-simulator',str(w/path)]
 r=subprocess.run(cmd,capture_output=True,timeout=30)
 (out/f'integrated-ios-conditional-{i}.stdout').write_bytes(r.stdout);(out/f'integrated-ios-conditional-{i}.stderr').write_bytes(r.stderr)
 parse.append({'path':path,'sha256':sha((w/path).read_bytes()),'exit':r.returncode,'command':cmd})
assert all(x['exit']==0 for x in parse),parse
(out/'INTEGRATED_SYNTAX_ONLY.json').write_text(json.dumps({'compiler':subprocess.check_output([swift,'--version']).decode(),'host':'Oracle Linux','typecheck':False,'sdkAvailable':False,'nativeAcceptance':False,'files':parse},indent=2)+'\n')
r=subprocess.run(gprefix+['diff','--check','--','Source'],capture_output=True);(out/'source-diff-check.stdout').write_bytes(r.stdout);(out/'source-diff-check.stderr').write_bytes(r.stderr);assert r.returncode==0
print(json.dumps({'localization':localization,'syntaxFiles':len(parse),'syntaxFailures':sum(x['exit']!=0 for x in parse),'diffStat':g('diff','--stat','--','Source').decode(),'freeBytes':os.statvfs(w).f_bavail*os.statvfs(w).f_frsize}))
