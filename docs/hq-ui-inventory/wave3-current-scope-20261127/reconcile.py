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
  else:proof['anchor_status']='HISTORICAL_ANCHOR_MISSING_REVIEW_REQUIRED'
  snap[p]=info(p)
 else:
  proof.update({k:c[k] for k in ['git_blob','current_sha256','matching_lines','repository','proof_reference'] if k in c})
  proof.update(sha256=c['current_sha256'],anchor_status=c.get('status'),consumer_source_ref=REF,
   method='Preserved immutable external Git proof reused under unchanged independently read consumer pin; no fresh external runtime test.')
 if area=='excluded':role='decorative_not_standalone_action'
 elif area=='inactive':role='historical_alternative_host'
 elif area=='future':role='formerly_missing_infrastructure_now_source_supplied'
 elif area=='embedded_rn':role='original_RN_source_without_established_live_native_host'
 elif x['id'] in ['inventory.v1.embedded.runtime','inventory.v1.embedded.rpc-data']:role='backend_infrastructure_not_visible_UI'
 elif x['id'] in ['inventory.v1.embedded.surface-host','inventory.v1.embedded.rn-root']:role='declared_RN_host_without_established_active_construction'
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
 'native.search':['native.search.query']}
assert sum(map(len,anchors.values()))==32
registry={}
for name,presentation,public,actions in [
 ('native.library',['currentTab'],True,[]),('native.reader.toc',['currentTab'],True,[]),
 ('native.history',['currentTab'],True,[]),('native.search',['currentTab'],True,[]),
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
 'MaktabahNativeWorkspacePresentationBinding','MaktabahNativePhoneTOCPresentation']:
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
assert len(focused)==31 and len({x['selector'] for x in focused})==31
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
 counting_boundary='294 original semantic rows and 32 current anchors are different sets; neither is a runtime pass count. New anchors remain explicitly accounted for in registry and source snapshot.'))
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
intro="""# Wave3 original UI scope checkpoint

**This is a source-bound checkpoint, not product acceptance.** The audited integration source is REF_TOKEN. All 294 original semantic rows and 51 original QA families are preserved. Original inputs, visible state, security tier and suitability remain attached to each row. No acceptance criteria, tests, selectors or timeouts were weakened.

## Source supplied and work still required

The current registry contains 12 parents and 32 finite anchors: 15 Settings, 4 Library, 3 TOC, 9 Workspace and 1 Search. The 57 historical rows with an explicit current route subset are not 57 accepted tests. The remaining rows are not blanket unsupported cases. A root, an exact current control, an arbitrary entity selection and a confirmed mutation are different capabilities.

1. **Next implementation: cold/warm Search parent then focus.** Current searchFieldAvailable requires an already mounted original Search surface and actual visible UISearchTextField. Prepare and validation reject an unmounted field. Retain the same scene/Core request, source and deadline across original parent presentation and first field mount, then require real first-responder geometry. Do not dismiss unrelated Settings/modal state, clear a query, regrant authority or use another root. Preserve the original already-visible negative assertion.
2. **Separate results-state implementation.** ActionSearchResultsQuery accepts only backend/text/scopeWorkRefs/searchMode/matchMode/wordDistance/sortOrder; each work scope allows backend/workKey/catalogRevision. Native UI supports phrase+exact+distance 0 only. Nonempty scope is accepted only for Otzaria. Offset must be 0 and limit 20; original UI owns subsequent paging. Opaque searchHandle is rejected. There is no selectedHit/cursor field or independent ShowSearchResults AppIntent. Extend original semantics/identity/receipt together; do not simply remove guards.
3. **Exact selections still missing.** History/Favorites/Saved Results records/folders, annotations filter/book/import review, arbitrary profile/group/tab selection, Library category/work-row/info, Inspector tool/group/item, Reader text-range/version/in-book-search/options/popover require their real owner/state bindings. Existing canonical Reader/content and unsaved draft paths already cover their declared subset.
4. **RN surface activation.** Pinned original RN sources are inventoried, but no Source construction of SefariaEmbeddedNativeSurfaceHost was found. Headless Hermes data success is not a visible native RN receipt. The parent explicitly includes meaningful native RN coverage. Auth/account/debug/destructive entries retain original public-action exclusions, not blanket UI acceptance.
5. **Regressions and native acceptance.** Notes has a narrow source candidate, not a native pass. All original feature behavior and final integration tests remain required.

## Original feature families

| Family | Supplied implementation | Remaining state/acceptance |
| --- | --- | --- |
"""
readme=[intro.replace('REF_TOKEN',REF)]
for area,f in C['family'].items():readme.append('| '+' | '.join(map(md,[area,f['supplied'],f['gaps']]))+' |')
readme.append("""
## Original acceptance that must not disappear

**Sidebar:** two actual Library/TOC pages,20× body/dot paging each direction, independent close/page actions, stable original Reader/search/scroll/TOC state,10 reading transitions, no duplicate corpus/TOC work, real keyboard/VoiceOver/Dynamic Type, rotation/narrow/multiscene. Original native tests and older two-direction passes remain scoped to their source.

**Safari Toolbar / CommandPalette / Gelatin:** original code and canonical LibraryViewModel filtered membership/query are used. Current commands project books only; the original explicit category-results requirement is not proved by book rows. Category/recent semantics,100+ results/rapid toggles, Escape/outside/result dismissal, hardware keyboard/pointer, reduced motion, narrow sizing, HE/EN/VoiceOver and Reader/Inspector noninterference remain required. The November 22 owner reference specifies one stable morph shell; do not treat the older Namespace mechanism alone as acceptance. The two exact owner reference files are now recovered under docs, with no demo app copied into production.

**Profiles / groups / tabs / Grid / restoration:** original store/adapter/UI already exist. Retain 3 profiles×at least 3 groups, empty/from-current groups, 30+ tabs, same-book independent locators, create/rename/duplicate/move/delete/reorder, real Grid/List controls, no blank-tab pollution, atomic migration/rollback, per-window restore,100 switches and production-v40 cold restore. New 11 finite routing selectors do not replace these original tests. Phone secondaryAction menu visibility and nested profile presentation remain native risks.

**Native Side Sheet:** original system sheet/placement and TorahInspectorKit exist. Retain 155 pt Peek/Medium/Large, physical right RTL/LTR, same-iPad narrow transition, original Reader interaction behind Peek, child Notes save/edit/delete/cancel, TOC dismissal coordination, sources and owner/selection across detents/books/tabs/backends. Historical detent/notes/TOC passes are not final-candidate or physical passes.

## Evidence and final gates

Original Native116 baseline was 82 passes / 34 failures. Later targeted passes stay source/selector-bound; never add them arithmetically to82 to claim a completed final116. The original D Notes route actually failed after 34.476 s; its 5 s canonical receipt gate remains unchanged. Candidate 53b94583 removes duplicate root mode publication; actual candidate rerun remains required. Two historical D window tests passed 147.461 / 159.633 s with actual HID 7/7, but do not prove final integration.

The 31 new focused selectors are 4 Settings, 8 Library/TOC, 11 Workspace, 2 actual HTTPS delivery, 2 Siri recognized-text delivery and 4 guides. Their exact class/method/file hashes are listed separately. None is executed by this checkpoint. Siri API-only SDK typecheck is not an app/UI-test-target build or actual Siri/microphone acceptance. Authorized origin/Apple-CDN AASA configuration is not actual OS HTTPS delivery.

There are now 3 actual multistep app/search/study guides and the original Hanlin host. The older one-tour/absent-host source conclusion is superseded. Real provider/AI/MCP/guide consent/context/geometry/cancel acceptance remains open.

Original Debug/Release, Native116, Release114+2, production v40 corpus/indices, Anytype, Hanlin Live, MiniApps, iPad+iPhone and owner physical QA remain root gates. No physical test is asserted. The current deployment minimum is iOS/iPadOS 27 only. Q-UI07-049 is preserved as superseded by the explicit November 17 owner tasks 1220542174542004 and 1220636669052920, not an iOS26 build/install blocker.

## Provenance and applicability

All 241 application rows were reconciled against immutable consumer Git blobs. The 53 external rows reuse preserved original Git proofs under independently re-read unchanged Sefaria-Mobile2fd173a5 and TorahInspectorKit23db0f84 pins. All 32 source-port records match the prior audited source; 13 match original upstream bytes, 24 match recorded adaptation bytes. Eight later adaptations remain explicit provenance/owner review work, not falsely untouched originals.

Four decorative rows require no standalone public navigation action but still require visual/accessibility quality. Six historical alternative SwiftUI hosts are not grounds for a second implementation. Three dedicated Settings placeholders (language/accessibility/data profile) are absent and stay recorded: parent scopes them to where existing; actual HE/EN/accessibility/production requirements remain applicable. A missing native version chooser is also retained honestly.

All 55 historical owner signatures stay immutable. The current protected delta requires authentic source-bound review; no signatures, approvals or policy exceptions are generated here.

## Sources and limits

The original task criteria are summarized in AUDIT_CONTRACT.json and SOURCE_PROVENANCE.json. Full original294/51 contracts remain in the earlier immutable crosswalk. Asana task notes were read in full; the connector returns at most50 comments, and UI06 reached that window. This is not a claim that every comment is present in that window.
""")
for t in C['tasks']:readme.append('- ['+t['gid']+' — '+t['name']+']('+t['url']+') — latest notes read; modified '+str(t['modified_at'])+'.')
readme.append('\nRegenerate with python3 docs/hq-ui-inventory/wave3-current-scope-20261127/reconcile.py. This performs documentation/source verification only, no build or product test.\n')
(OUT/'README.md').write_text('\n'.join(readme))
print(json.dumps(summary,ensure_ascii=False))
