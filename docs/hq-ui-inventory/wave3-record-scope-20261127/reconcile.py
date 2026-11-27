#!/usr/bin/env python3
"""Immutable source/document reconciliation only. Never builds or grants runtime acceptance."""
from pathlib import Path
import subprocess,json,hashlib,re,collections
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
C=json.loads((OUT/'AUDIT_CONTRACT.json').read_text())
REF=C['audited_source']; CACHE={}
def git(*a):return subprocess.check_output(['git','-C',str(ROOT),*a],text=True)
def blob(p,ref=REF):
 k=(ref,p)
 if k not in CACHE:CACHE[k]=subprocess.check_output(['git','-C',str(ROOT),'show',ref+':'+p])
 return CACHE[k]
def sha(b):return hashlib.sha256(b).hexdigest()
def info(p,ref=REF):
 b=blob(p,ref)
 return dict(path=p,source_ref=ref,sha256=sha(b),git_blob=git('rev-parse',ref+':'+p).strip(),bytes=len(b))
def put(p,x):(OUT/p).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def md(s):return str(s).replace('|','\\|').replace('\n',' ')
assert git('rev-parse',REF).strip()==REF
oldpath='docs/hq-ui-inventory/wave3-20261127/CURRENT_CROSSWALK.json'
old=json.loads(blob(oldpath))
assert len(old['surfaces'])==294 and len({x['id'] for x in old['surfaces']})==294
assert len(old['original_qa_contract']['requirements'])==51
paths=git('ls-tree','-r','--name-only',REF).splitlines()
resolved=json.loads(blob('Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'))
torah=next(x['state']['revision'] for x in resolved['pins'] if x['identity']=='torahinspectorkit')
sefaria=git('ls-tree',REF,'Vendor/SefariaMobile/Upstream').split()[2]
assert torah==old['external_source_proof']['TorahInspectorKit']
assert sefaria==old['external_source_proof']['SefariaMobile']
rows=[];snap={}
for x in old['surfaces']:
 c=x['current_source'];area=x['area'];role='meaningful_original_control_or_state'
 proof={k:c[k] for k in ['path','object_path','source_ref','storage','historical_anchor'] if k in c}
 if c['storage']=='PINNED_APP_GIT_OBJECT':
  p=c['object_path'];b=blob(p);text=b.decode();lines=text.splitlines()
  proof.update(info(p));proof['unchanged_from_prior_crosswalk']=sha(b)==c['current_sha256']
  anchor=c.get('historical_anchor','')
  proof['matching_lines']=[i+1 for i,l in enumerate(lines) if anchor and anchor in l]
  if proof['matching_lines']:proof['anchor_status']='ANCHOR_PRESENT'
  elif c.get('status')=='LOCALIZED_ANCHOR_RECONCILED' and 'Delete Profile' in text:
   proof['anchor_status']='LOCALIZED_ANCHOR_RECONCILED'
   proof['matching_lines']=[i+1 for i,l in enumerate(lines) if 'Delete Profile' in l]
   proof['boundary']='Historical literal reconciled to the existing localized original Delete Profile control.'
  elif x['id']=='inventory.v1.shell.settings-sheet' and '.sheet(isPresented: originalSettingsPresentation)' in text and 'nativeRootPublications.settingsBinding($showSettings)' in text:
   assert sha(b)=='0ae4ebb09ae2e120812ce2199b4a3b61b48be82a3f7653a187c9e45bcc392d93'
   proof['anchor_status']='ORIGINAL_BINDING_WRAPPER_RECONCILED'
   proof['current_anchor']='.sheet(isPresented: originalSettingsPresentation)'
   proof['matching_lines']=[i+1 for i,l in enumerate(lines) if proof['current_anchor'] in l]
   proof['boundary']='The historical raw State Binding is now wrapped by the original scene-lived publication owner. The same original Settings sheet and SettingsView remain; this source reconciliation claims no runtime acceptance.'
  else:proof['anchor_status']='HISTORICAL_ANCHOR_MISSING_REVIEW_REQUIRED'
  snap[p]=info(p)
 else:
  proof.update({k:c[k] for k in ['git_blob','current_sha256','matching_lines','repository','proof_reference'] if k in c})
  proof.update(sha256=c['current_sha256'],anchor_status=c.get('status'),consumer_source_ref=REF,
   method='Preserved immutable external Git proof reused under unchanged independently read consumer pin; no fresh external runtime test.')
 if area=='excluded':role='decorative_not_standalone_action'
 elif area=='inactive':role='historical_alternative_host'
 elif area=='future':role='formerly_missing_infrastructure_now_source_supplied'
 elif area=='embedded_rn':role='original_RN_source_with_installed_host_runtime_pending'
 elif x['id'] in ['inventory.v1.embedded.runtime','inventory.v1.embedded.rpc-data']:role='backend_infrastructure_not_visible_UI'
 elif x['id'] in ['inventory.v1.embedded.surface-host','inventory.v1.embedded.rn-root']:role='original_RN_host_source_wired_native_pending'
 elif x['id'] in ['inventory.v1.settings.data-profile','inventory.v1.settings.accessibility','inventory.v1.settings.language']:role='historical_absent_settings_placeholder_where_existing_scope'
 elif x['id']=='inventory.v1.reader.version-picker':role='declared_version_capability_without_native_chooser'
 elif x['id']=='inventory.v1.widget.configuration':role='original_widget_configuration_not_navigation_intent'
 rows.append(dict(id=x['id'],area=area,label=x['label'],role=role,original_contract=x['original_contract'],
  original_ui_implementation=x['original_ui_implementation'],source=proof,
  current_navigation_binding=C['bindings'].get(x['id']),
  source_coverage_boundary=C['family'][area]['gaps'],original_qa_families=C['family'][area]['qa'],
  native_acceptance_on_audited_source='NOT_RUN',physical_acceptance='NOT_RUN',
  policy='Missing binding or test is not a waiver. User-only mutations/private state do not become GET actions.'))
assert set(C['bindings']).issubset({x['id'] for x in rows})
core='Source/Otzaria/Actions/Sources/OtzariaActionCore/Registry/ActionRegistry.swift'
implemented=re.findall(r'"([^"]+)"',re.search(r'implemented: Set<String> = \[(.*?)\]',blob(core).decode(),re.S).group(1))
assert len(implemented)==21
anchors={
 'native.settings':['native.settings.'+x for x in ['backend','offline','databaseMode','history','storage','annotations','cloud','appearance','searchData','searchCredits','searchIndex','optimization','updates','downloads','miniApps']],
 'native.library':['native.library.'+x for x in ['contents','grouping','downloadedFilter','options']],
 'native.reader.toc':['native.reader.toc.'+x for x in ['contents','structure','currentSelection']],
 'native.workspace.profiles':['native.workspace.profiles.'+x for x in ['list','groups','newProfile']],
 'native.workspace.overview':['native.workspace.overview.'+x for x in ['groups','grid','list','layout','actions','profileMenu']],
 'native.search':['native.search.query','native.search.queryEntry']}
assert sum(map(len,anchors.values()))==33
registry={}
for name,presentation,public,actions in [
 ('native.library',['currentTab'],True,[]),('native.reader.toc',['currentTab'],True,[]),
 ('native.history',['currentTab'],True,[]),('native.sefariaEmbedded',['sheet'],True,[]),('native.search',['currentTab'],True,[]),
 ('native.search.results',['currentTab'],False,['search.openResults']),
 ('native.annotations',['currentTab'],True,[]),('native.settings',['sheet'],True,[]),
 ('native.workspace.profiles',['sheet'],True,[]),('native.workspace.overview',['sheet'],True,[]),
 ('native.reader.inspector',['inspector'],True,[]),('native.reader.noteDraft',['sheet'],False,['notes.prepareDraft']),
 ('native.reader',['currentTab','newTab'],True,['reader.open'])]:
 registry[name]=dict(presentation=presentation,public_v2=public,core_actions=actions,anchors=anchors.get(name,[]))
for name in ['MaktabahNativeRoutingComposition','MaktabahNativeRoutingHost','MaktabahNativePublicBindingAdapter',
 'MaktabahNativeSceneSession','MaktabahNativeSceneProjection','MaktabahNativeSceneBindings',
 'MaktabahNativeComponentBinding','MaktabahNativeSettingsComponents','MaktabahNativeLibraryComponents',
 'MaktabahNativeTOCComponents','MaktabahNativeWorkspaceComponents',
 'MaktabahNativeWorkspacePresentationBinding','MaktabahNativePhoneTOCPresentation',
 'MaktabahNativeSearchEntry','MaktabahNativeSefariaSurfaceBinding','MaktabahNativeSefariaSurfacePresentation']:
 p='Source/ChavrusaText/UIRoutingHost/Integration/'+name+'.swift';snap[p]=info(p)
for p in [
 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeDestinationIntents.swift',
 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderIntents.swift',
 'Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionSearchResults.swift',core,
 'Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift',
 'Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift',
 'Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift',
 'Source/ChavrusaText/ToolbarSearch/SafariToolbarSourcePort.swift','Source/Localizable.xcstrings',
 'docs/otzaria/ui-prototypes/library-search-morph-20261122/MorphingSearchPlaygrounds.swift',
 'docs/otzaria/ui-prototypes/library-search-morph-20261122/SafariToolbarSearch-Playgrounds.zip']:
 snap[p]=info(p)
ports=[]
for x in old['original_source_ports']:
 p=x['destination'];a=info(p)
 ports.append({**{k:x[k] for k in ['repo','original','destination','sha256','reason','destinationSHA256','historical_record']},
  'current':a,'same_as_prior_crosswalk':a['sha256']==x['current_destination_sha256'],
  'same_as_original_bytes':a['sha256']==x['sha256'],'same_as_recorded_port_bytes':a['sha256']==x['destinationSHA256']})
tests=[];focused=[]
for p in paths:
 if p.startswith('Maktabah-iOSUITests/') and p.endswith('.swift'):
  owner=None;entries=[]
  for line in blob(p).decode().splitlines():
   m=re.match(r'^(?:@MainActor\s+)?(?:final\s+)?(?:class|extension)\s+(\w+)',line)
   if m:owner=m.group(1)
   f=re.search(r'\bfunc (test\w+)\s*\(',line)
   if f:
    entries.append(dict(test_class=owner,method=f.group(1)))
    if f.group(1) in C['focused_names']:
     assert owner,(p,f.group(1))
     focused.append(dict(selector=owner+'/'+f.group(1),file=p,source=info(p),execution='NOT_RUN'))
  if entries:tests.append(dict(source=info(p),declared_methods=entries))
assert len(focused)==len(C['focused_names']) and len({x['selector'] for x in focused})==len(C['focused_names'])
qmap={1:'library',2:'reader',3:'reader',4:'toc',5:'inspector',6:'search',7:'search',8:'search',
 9:'notes',10:'bookmarks',11:'settings',12:'workspace',13:'shell'}
qa=[]
for q in old['original_qa_contract']['requirements']:
 n=int(q['id'].split('-')[-1]);family=qmap.get(n)
 item={**q,'source_state':'SOURCE_CONTRACTS_PRESENT_FINAL_ACCEPTANCE_REQUIRED','native_on_audited_source':'NOT_RUN',
  'physical':'NOT_RUN','boundary':'Prior actual evidence retains its source. This audit neither runs nor aggregates a final gate.'}
 if family:item.update(family=family,supplied=C['family'][family]['supplied'],remaining=C['family'][family]['gaps'])
 if n==49:item.update(source_state='SUPERSEDED_BY_OWNER_IOS27_ONLY',native_on_audited_source='NOT_APPLICABLE_TO_CURRENT_OWNER_MINIMUM',
  remaining='Historical iOS26 row retained. Owner tasks 1220542174542004 and 1220636669052920 require iOS/iPadOS 27 only.')
 if n==51:item['remaining']='Origin/Apple-CDN AASA configuration is not OS delivery. Two additive actual HTTPS selectors remain NOT_RUN.'
 if n==39:item['remaining']='Three actual multistep guide definitions (app/search/study) exist. Four additive native selectors remain NOT_RUN.'
 qa.append(item)
summary=dict(audited_source=REF,previous_observed_source=C['prior_observed'],
 source_delta_since_previous=git('diff','--name-only',C['prior_observed'],REF,'--','Source').splitlines(),
 original_semantic_rows=len(rows),unique_original_ids=len({x['id'] for x in rows}),
 source_anchor_statuses=dict(collections.Counter(x['source']['anchor_status'] for x in rows)),
 roles=dict(collections.Counter(x['role'] for x in rows)),original_qa_families=len(qa),
 registered_native_parents=len(registry),registered_finite_component_anchors=sum(map(len,anchors.values())),
 old_rows_with_explicit_current_subset_mapping=sum(x['current_navigation_binding'] is not None for x in rows),
 implemented_core_actions=len(implemented),source_guided_journeys=3,new_focused_selectors=len(focused),
 new_native_tests_executed_by_audit=0,product_passes_claimed=0,physical_passes_claimed=0,
 source_port_records=len(ports),source_ports_unchanged_from_prior_audit=sum(x['same_as_prior_crosswalk'] for x in ports),
 source_ports_identical_to_original=sum(x['same_as_original_bytes'] for x in ports),
 source_ports_identical_to_recorded_adaptation=sum(x['same_as_recorded_port_bytes'] for x in ports),
 authentic_owner_gate='Root/owner authentic source-bound review required. No approval or signature generated.',
 root_runtime_boundary=C['root_report'])
put('COMPONENT_RECONCILIATION.json',dict(summary=summary,original_inventory=info(oldpath),families=C['family'],
 registry=registry,rows=rows,
 counting_boundary='294 original semantic rows and 33 current anchors are different sets; neither is a runtime pass count. New anchors remain explicitly accounted for in registry and source snapshot.'))
put('QA_51_RECONCILIATION.json',dict(audited_source=REF,original_contract=old['original_qa_contract'],rows=qa))
put('SOURCE_PROVENANCE.json',dict(audited_source=REF,source_files=list(snap.values()),original_ports=ports,
 external_proof_reuse=dict(TorahInspectorKit=torah,SefariaMobile=sefaria,
 boundary='Immutable external Git proofs retained under independently re-read unchanged consumer pins; no fresh external runtime claim.'),
 task_reads=C['tasks'],ui03_07_contracts=C['contract'],
 notes=['November 22 owner morph references are now recovered byte-identically under docs; the older prototype is preserved.',
 'Toolbar labels now reuse original scene locale/helper/catalog; EN/HE/VoiceOver runtime still NOT_RUN.',
 'Adapted original-source ports retain their provenance. Do not call all32 untouched upstream files.']))
put('NATIVE_FOCUSED_SELECTION.json',dict(audited_source=REF,selectors=focused,
 boundary='Separate additive selection only. Original Native116/Release114+2 manifests, selectors, counts and timeouts remain unchanged. No listed selector was executed by this checkpoint.'))
put('DECLARED_NATIVE_TESTS.json',dict(audited_source=REF,files=tests,
 boundary='Lexical source declarations only. Inherited/overridden methods are not a unique/executed runner case count.'))
put('SUMMARY.json',summary)
table=['# Original294 component reconciliation','',
 'Audited source: '+REF+'. No product/runtime PASS is asserted.','',
 '| Original ID | Meaning | Current role | Supplied route subset | Original QA |',
 '| --- | --- | --- | --- | --- |']
for x in rows:
 b=x['current_navigation_binding'];route='—' if b is None else b['destination']+(' / '+', '.join(b['components']) if b['components'] else '')
 table.append('| '+' | '.join(map(md,[x['id'],x['label'],x['role'],route,', '.join(x['original_qa_families'])+'; native NOT_RUN']))+' |')
(OUT/'COMPONENTS.md').write_text('\n'.join(table)+'\n')

readme=[
 '# Original294 / UI-03–07 checkpoint before record routing','',
 '**Source-bound audit, not native acceptance.** Current source: '+REF+'. Prior '+C['prior_observed']+' checkpoint is preserved. All294 original IDs/contracts and51 QA families remain intact.','',
 '## Supplied source and next slice','',
 'The current registry has '+str(len(registry))+' parents and '+str(sum(map(len,anchors.values())))+' component anchors. Neither count is a test result. Additive Search queryEntry opens the original parent before exact-field focus; native.search.query remains already-visible-only. The original Sefaria RN sheet now has source-owned host mounting, structured bridge/host proof, retained root +0 history and independent native-witness gating. Its45 inventoried RN components do not inherit root acceptance.','',
 'Semantic Settings-control, Reader-TOC and History-root App Intents are present. They do not supply arbitrary record targets. ShowSearchResultsIntent is assigned separately and is absent at this immutable checkpoint. The old first-page/search-mode/scope/limit contract remains intact.','',
 'There are '+str(len(focused))+' separately enumerated focused native selectors: prior31 plus4 Search-entry and4 RN. All remain NOT_RUN on this audited source. Source/package controls and old native results do not establish final native acceptance.','',
 'The next authorized slice reveals an exact original History/Favorites record through a typed live entity and actual row witness. The original history.open-entry additionally requires the exact remembered reading position; row reveal cannot close that separate canonical reader.open requirement. No record implementation is asserted by this checkpoint.','',
 'Saved Results has its own original presenter: SearchModeView.showingSavedResults owns iOSSavedResultsView. Its list/folder/query/folder-selection rows require exact original folder/result state. History cannot stand in. Original move/rename/delete/save and favorite-picker confirmation remain user actions.','',
 'PublicNavigationV2 has no private record-ID field. The new record slice must use typed live entities and existing trusted local RouteSpec selectedItemID, without encoding IDs in arbitrary component names, misusing Reader content, expanding the public schema or executing GET writes.','',
 'A fresh read found that History first publishes legacy integer-keyed cards before asynchronous QualifiedLocatorStore publication. The sidecar actor has no synchronous source revision. Full history identity is TextLocator.persistenceKey; original numeric BooksData.id is work-level and can repeat for two remembered positions. A card or numeric ID alone is not backend-qualified authority. The next slice must bind actual published object, locator, section membership and unambiguous original row identity.','',
 '## Original feature families','',
 '| Family | Supplied original source | Remaining implementation or acceptance |',
 '| --- | --- | --- |']
for area,f in C['family'].items():readme.append('| '+' | '.join(map(md,[area,f['supplied'],f['gaps']]))+' |')
readme += [
 '', '## Applicability and original gates', '',
 'Four decorative rows need no standalone public action but retain visual/accessibility acceptance. Six historical inactive alternatives are not a reason to create a second UI. Three absent Settings placeholders retain their original where-existing scope, while real HE/EN/accessibility/production requirements still apply. The missing native version chooser remains explicit. Missing routes/tests do not make required features unsupported.',
 '',
 'Original Sidebar body/dot paging; Toolbar/CommandPalette/Gelatin categories/results and owner morph reference; profile/group/tab/Grid mutations and3×3/30-tab restoration; native Side Sheet detents/Notes/Reader interaction; HE/EN/RTL/VoiceOver/DynamicType; keyboard/pointer; rotation/narrow/multiscene; and all51 families remain required. The preserved prior README contains the exact original counts and acceptance clauses.',
 '',
 'Native116 baseline82/34 and the old Notes failure remain historical exact-source evidence. No successful Notes-candidate rerun is inferred. Final Native116, Release114+2, Debug/Release, original SDKs, production-v40/indices, Anytype, Hanlin Live, MiniApps, iPad+iPhone and physical owner QA remain root gates. The owner minimum is iOS/iPadOS27 only; original Q-UI07-049 remains preserved as superseded.',
 '',
 '## Provenance and limits','',
 'Application anchors are freshly read from immutable Git blobs. External Sefaria-Mobile/TorahInspectorKit proofs are reused only after checking unchanged exact consumer pins. Full original inputs/states/security/suitability remain attached to every row. Original/adapted source-port bytes remain distinct. Every protected delta needs final authentic source-bound review; all55 historical signatures are untouched.',
 '',
 'This update reuses the original Asana requirements snapshot and documented task reads. It does not claim a fresh read of every Asana comment. It executes no app, SDK, native or physical test and changes no acceptance criterion.',
 '',
 'Regenerate: python3 docs/hq-ui-inventory/wave3-record-scope-20261127/reconcile.py.']
(OUT/'README.md').write_text('\n'.join(readme)+'\n')
print(json.dumps(summary,ensure_ascii=False))
