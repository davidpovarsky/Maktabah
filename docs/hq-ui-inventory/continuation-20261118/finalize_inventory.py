"""Complete the immutable source inventory; never execute a route or read a user DB."""
import argparse, collections, copy, hashlib, importlib.util, json, re, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
SIGNALS=re.compile(r"\b(?:NavigationLink|NavigationStack|NavigationSplitView|WindowGroup|TabView|ToolbarItem|Menu|Picker|Slider|Toggle|TextField|TextEditor|AppIntent|AppShortcutsProvider)\b|\.(?:sheet|popover|fullScreenCover|inspector|navigationDestination|onOpenURL|accessibilityIdentifier|focused)\s*\(|\b(?:struct|class)\s+\w+[^\n]*(?::\s*.*\b(?:View|UIViewController|UIViewControllerRepresentable|NSViewController|App)\b)")
OWNER="Sole owner-authorized continuation agent; source/semantic self-review, no independent reviewer"
def write(name,value):
    (HERE/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
def main(source):
    sp=importlib.util.spec_from_file_location("reconcile_current",HERE/"reconcile.py")
    m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
    m.main(source)
    d=json.loads((HERE/"UI01_CURRENT_HANDOFF.json").read_text(encoding="utf-8"))
    assert d["source_sha"]==source
    old=m.original("SOURCE_SCAN.json")
    local=d["source_census"]["current_local_file_blobs"]
    cache=m.blobs(local.values())
    files=[]
    for path,blob in sorted(local.items()):
        raw=cache[blob];lines=raw.decode("utf-8-sig").splitlines()
        hits=[{"line":i,"text":l.strip()[:500]} for i,l in enumerate(lines,1) if SIGNALS.search(l)]
        files.append(dict(path=path,git_blob=blob,sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),
            lines=len(lines),availability="IMMUTABLE_GIT_OBJECT",source_revision=source,
            ui_candidate=bool(hits),signals=hits,declarations=[]))
    files.extend(copy.deepcopy(f) for f in old["files"] if "git_object_path" in f)
    byfile={f["path"]:f for f in files}
    rows=d["semantic_surfaces"];byid={r["id"]:r for r in rows}
    def ref(path,anchor,occurrence=1):
        raw=cache[local[path]];lines=raw.decode("utf-8-sig").splitlines()
        found=[i for i,l in enumerate(lines,1) if anchor in l]
        assert len(found)>=occurrence,(path,anchor)
        line=found[occurrence-1]
        return dict(path=path,line=line,anchor=anchor,occurrence=occurrence,source_line=lines[line-1].strip(),
            git_blob=local[path],sha256=hashlib.sha256(raw).hexdigest(),source_revision=source,storage="immutable_git_object")
    comp="Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"
    routes=[
        ("library","Native original Library/current tab",'.init(id: id("native.library")',"currentTab","v1_and_v2","Original same scene Library page on iPad or original compact NavigationStack root on iPhone; retains existing Reader/tab and private library query; no search submission or data write",["inventory.v1.tab.library","inventory.v1.library.catalog"]),
        ("reader.toc","Native original TOC/current tab",'.init(id: id("native.reader.toc")',"currentTab","v1_and_v2","iPad only; exact selected original Reader, matching active backend/book section, loaded nonempty original TOC with no failure; same original sidebar coordinator and independent visible witness; private TOC filter retained",["inventory.v1.toc.contents"]),
        ("history","Native History/current tab",'.init(id: id("native.history")',"currentTab","v1_and_v2","Current backend, foreground exact scene, empty global History search, no implicit backend switch",["inventory.v1.tab.history","inventory.v1.history.list"]),
        ("search","Native Global Search/current tab",'.init(id: id("native.search")',"currentTab","v1_and_v2","Original Search root, original capability availability and current foreground scene; retains private query, never submits it or encodes it in a public URL",["inventory.v1.tab.search"]),
        ("annotations","Native Annotations/current tab",'.init(id: id("native.annotations")',"currentTab","v1_and_v2","Original Annotations root in current foreground scene; no draft/import/export/delete or annotation write action",["inventory.v1.tab.annotations","inventory.v1.annotations.list"]),
        ("settings","Native Settings/sheet",'.init(id: id("native.settings")',"sheet","v2","Current backend, foreground exact scene; root sheet only, no subsection mutation",["inventory.v1.shell.settings-sheet","inventory.v1.settings.root"]),
        ("reader","Native Reader/current phone or iPad book",'.init(id: id("native.reader")',"currentTab","v2","Original phone/iPad workspace owner, active tab/current book, current backend, Core validated section/focus and original TextKit visible glyph; sameTab cross-book refused; separate R-owned newTab rule installed; compact phone owner uses original NavigationStack witness",["inventory.v1.reader.content","inventory.v1.reader.viewport"])
    ]
    for dest,title,anchor,presentation,version,limits,aliases in routes:
        row=copy.deepcopy(byid[aliases[0]])
        row.update(id="inventory.v1.native."+dest,area="native-routing",screen_section_component=title,
            source=ref(comp,anchor),owning_view_model="MaktabahNativeRoutingComposition / NativeSceneNavigationOrchestrator / original scene and workspace owners",
            inputs=["canonical public "+version+" intent", "backend-qualified content identity if Reader", "fresh trusted context issued locally"],
            visible_state="Exact native "+presentation+" after original UI acknowledgement",
            dependencies_and_requirements=limits,status="supported",ui_implementation="implemented_source",
            route_implementation="SOURCE_WIRED_NATIVE_ACCEPTANCE_PENDING",
            note=limits,independent_review="NOT_CLAIMED_SOLE_AGENT_OWNER_INSTRUCTION")
        row["installed_registry_id"]="native."+dest
        row["public_versions"]=version
        row["linked_semantic_action"]=({"id":"reader.open","catalog_present":True,"core_v1_implemented":True,"note":"Original ActionExecutor and canonical resolver; native completion required"} if dest=="reader" else None)
        row["tests"]={"case_plan_id":"UI01.native."+dest,"source_validation":"immutable source anchors and real registry declarations",
            "candidate_existing_suite":{"path":"Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift",
            "sha256":hashlib.sha256(m.git("show",source+":Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift")).hexdigest(),
            "relationship":"real Native acceptance source; exact execution remains separately reported","execution":"NOT_RUN_ON_THIS_SOURCE"},
            "required":["iOS/iPadOS27 exact scene/backend/visible state/receipt","cancel/stale ownership/refusal"],"runtime":"NOT_RUN_ON_THIS_SOURCE"}
        for backend,b in row["backends"].items():
            b.update(route="SOURCE_WIRED_CONDITIONAL",native_receipt="NOT_RUN_ON_THIS_SOURCE",reason=limits)
        row["suitability"].update(app_intent="installed_foreground_gated" if dest!="reader" else "source_wired_core_reader_intent_native_pending",
            deep_link="canonical_"+version+"_identity_only",hanlin="thin_existing_SDK_adapter_only_not_app_registered")
        rows.append(row)
        for alias in aliases:
            r=byid[alias];r.update(route_implementation="SOURCE_WIRED_CONDITIONAL",installed_registry_id="native."+dest,
                status="supported",note=limits+"; inventory support describes code wiring, not a native PASS")
            for b in r["backends"].values():b.update(route="SOURCE_WIRED_CONDITIONAL",reason=limits)
    newtab=copy.deepcopy(next(r for r in rows if r["id"]=="inventory.v1.native.reader"))
    newtab.update(id="inventory.v1.native.reader-new-tab",screen_section_component="Native Reader/new phone or iPad tab",
        source=ref("Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift","func reserveNativeReader("),
        owning_view_model="Original R StudyWorkspaceNavigationAdapter reservation / original ReaderTab and ReaderViewModel / original Core",
        visible_state="Original new tab is active with actual focused TextKit glyph and full Core receipt",
        dependencies_and_requirements="Actual attached phone/iPad scene owner, exact new UUID/Reader object, original Core grant; append and selection checked through actual native setters; arbitrary mapping changes revoke; exact committed checkpoint only",
        note="newTab may open another real known book or a distinct tab of the same book without replacing any existing tab. Native acceptance pending.",
        inputs=["Canonical v2 backend/section/focus with presentation newTab", "Original Core context and exact R reservation generated locally"])
    newtab["tests"]["case_plan_id"]="UI01.native.reader-new-tab"
    newtab["tests"]["required"] += ["Other-book and same-book exact new owner, all previous tab identities retained, return using native original tab control"]
    for b in newtab["backends"].values(): b["reason"]=newtab["dependencies_and_requirements"]
    rows.append(newtab)
    for kind,path,anchor,title in [
        ("foreground-intent","Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeDestinationIntents.swift","public struct OpenNativeDestinationIntent: AppIntent","Foreground App Intent"),
        ("shortcut","Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeIntents.swift","struct MaktabahNativeShortcuts: AppShortcutsProvider","Native destination App Shortcut")]:
        r=copy.deepcopy(next(r for r in rows if r["id"]=="inventory.v1.native.history"))
        r.update(id="inventory.v1.native."+kind,screen_section_component=title,source=ref(path,anchor),
            owning_view_model="NativeIntentService / original registered NativeDestinationEntityQuery",
            installed_registry_id=None,linked_semantic_action=None,
            inputs=["fresh registered backend-qualified root entity", "exact foreground scene"],
            visible_state="The chosen original native root is independently visible and acknowledged",
            public_versions="NOT_APPLICABLE_SYSTEM_INTENT",
            note="App metadata and foreground service installed for eligible Library/TOC/History/Search/Annotations/Settings; actual Siri/Shortcuts invocation NOT_RUN; separate source-wired Book/Location intent uses original Core and Reader owner")
        rows.append(r)
    reader_intent=copy.deepcopy(newtab)
    reader_intent.update(id="inventory.v1.native.reader-intent",screen_section_component="Open source book at chapter or passage / original Reader",
        source=ref("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderIntents.swift","public struct OpenBookAtLocationIntent: AppIntent"),
        owning_view_model="NativeReaderIntentService / original ActionExecutor catalog resolver / original source TOC / original R reader owner",
        inputs=["Stable backend-qualified NativeBookEntity and NativeBookLocationEntity", "Exact user-selected existing Library window", "Explicit newTab or currentTab"],
        public_versions="NOT_APPLICABLE_SYSTEM_INTENT",
        dependencies_and_requirements="Original Core resolves source work and section; all ambiguity remains selectable; cached IDs revalidated; backend/generation/RPC epoch checked through original binder; original Native reader.open alone commits; no source title is used as permission",
        note="AppIntent source and original composition installed; Apple SDK/actual system UI tests pending; spoken Siri, Spotlight and physical device acceptance remain separate")
    reader_intent["tests"]["case_plan_id"]="UI01.native.reader-intent"
    reader_intent["tests"]["required"]=["Named original TOC chapter through system resolution", "Cached source after background and original tab return", "Wrong-book/missing-source refusal", "Original compact phone owner"]
    rows.append(reader_intent)
    byid={r["id"]:r for r in rows}
    focus=byid["inventory.v1.search.input-focus"]
    focus_limits="Only the already visible original UISearchTextField in the exact foreground/key scene; original Core guard and retained control identity; actual UIKit responder plus original surface receipt; open Search root first; no queued focus, query edit or search submission"
    focus.update(owning_view_model="UnifiedSearchSessionController.query / original UISearchTextField / MaktabahNativeSceneSession retained field",
        inputs=["Canonical public v2 component native.search.query or current live NativeDestinationEntity"],
        visible_state="Original visible field is UIKit first responder; actual keyboard input without another tap",
        installed_registry_id="native.search",installed_component_id="native.search.query",public_versions="v2",
        dependencies_and_requirements=focus_limits,status="supported",route_implementation="SOURCE_WIRED_NATIVE_ACCEPTANCE_PENDING",
        note=focus_limits+"; Native execution NOT_RUN on this source")
    focus["supporting_sources"]=[
        ref(comp,'components: [id("native.search.query")]'),
        ref("Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift","field.isFirstResponder || field.becomeFirstResponder()")]
    focus["suitability"].update(app_intent="same_original_intent_live_component_entity_foreground_gated",
        deep_link="canonical_v2_registered_component_already_visible_only",
        guide="same_registry_named_component_focus_no_coordinate_taps_no_guide_engine_claim")
    for b in focus["backends"].values():b.update(route="SOURCE_WIRED_CONDITIONAL",native_receipt="NOT_RUN_ON_THIS_SOURCE",reason=focus_limits)
    focus["tests"]={"case_plan_id":"UI01.native.search-query-focus","source_validation":"Original control and fixed registry anchor; no runtime class discovery",
        "candidate_existing_suite":{"path":"Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift",
            "sha256":hashlib.sha256(m.git("show",source+":Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift")).hexdigest(),
            "relationship":"Five real native cases, execution pending","execution":"NOT_RUN_ON_THIS_SOURCE"},
        "required":["Actual keyboard input without tap on iPad and iPhone","Unknown/absent control refusal and prior Reader preservation","Existing out-of-process system App Intent","RTL/LTR and accessibility"],
        "runtime":"NOT_RUN_ON_THIS_SOURCE"}
    for key in ["inventory.v1.native.foreground-intent","inventory.v1.native.shortcut"]:
        byid[key]["inputs"]=["Fresh backend/scene-qualified root or currently eligible component entity","Exact foreground scene"]
        byid[key]["note"] += "; visible Search query component is source-wired through the same existing intent and public binder; native/system acceptance pending"
    byid["inventory.v1.app.scene"]["note"]="Real MaktabahNativeRoutingHost mounts using actual UIKit scene identity and original workspace lifecycle; exact target is retained by NativeSceneDirectory. Root Library/TOC/History/Search/Annotations/Settings and current/new-tab Reader on original phone/iPad owners; native validation remains pending."
    for r in rows:
        r["independent_review"]="NOT_CLAIMED_SOLE_AGENT_OWNER_INSTRUCTION"
        r["source_review_owner"]=OWNER
        for k,v in list(r["tests"].items()):
            if isinstance(v,list):r["tests"][k]=[x.replace("iOS26/27","iOS/iPadOS27") if isinstance(x,str) else x for x in v]
    alias=next(c for c in d["source_caveats"] if c["id"]=="embedded-inspector-backend-alias")
    alias.update(status="SOURCE_FIXED_NATIVE_PROVIDER_FOCUS_ACCEPTANCE_PENDING",
        source=ref("Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift","providerID: locator.backend.rawValue",2),
        detail="Current-unit and segment selections now preserve the actual backend; segment selection requires matching work and section backend. The old Legacy-only alias has been removed in source. Real Embedded provider/focus Native acceptance remains pending.",
        supporting_sources=[ref("Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift","locator.backend == coordinator.activeBackendID,",1),
            ref("Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift","providerID: section.locator.backend.rawValue")])
    # Preserve prior meaningful classifications, then explicitly cover every new
    # lexical candidate and every newly introduced nonvisual file.
    dispositions={x["path"]:copy.deepcopy(x) for x in d["file_dispositions"] if x["path"] in byfile}
    rows_by_path=collections.defaultdict(list)
    for r in rows:rows_by_path[r["source"]["path"]].append(r["id"])
    candidate_paths={f["path"] for f in files if f.get("ui_candidate")}
    review_paths=candidate_paths|set(d["source_census"]["added_paths"])|set(rows_by_path)
    for path in sorted(review_paths):
        f=byfile[path];ids=rows_by_path[path]
        if path not in dispositions:
            if ids:
                category="mapped_semantic_surfaces";reason="Source-declared meaningful controls/destinations mapped below; no inferred public registration"
            elif "/Tests/" in path:
                category="test_fixture_not_app_route";reason="Assertions, doubles or test fixtures; never an app destination"
            elif path.endswith("/Package.swift"):
                category="package_manifest_not_app_route";reason="Package/module membership declaration, no native destination"
            elif path.endswith("NativeSurfaceWitness.swift"):
                category="implementation_child_or_support";reason="Passive UIKit visibility witness for existing surfaces, not independently navigable"
            elif "/HanlinHostAdapter/" in path:
                category="host_adapter_not_app_route";reason="Thin adapter to frozen existing Hanlin SDK; no Chat/Composer UI and not yet app registered"
            elif "/UIRoutingHost/" in path or "/UIRouting/" in path or "/Actions/" in path or path.endswith("StudyWorkspaceMappingOwnership.swift"):
                category="routing_or_action_support_not_public_destination";reason="Codec, authority, binding, observation, ownership or canonical Core plumbing; installed roots recorded separately"
            elif "/Search/UI/" in path:
                category="implementation_child_or_support";reason="Presentation or UIKit field implementation for existing Search semantics; source controls mapped in Search rows"
            else:raise AssertionError("Unreviewed new candidate: "+path)
            dispositions[path]=dict(path=path,disposition=category,reason=reason,semantic_ids=ids)
        q=dispositions[path]
        q.update(git_blob=f["git_blob"],sha256=f["sha256"],source_revision=f.get("source_revision",source),
            review="SOLE_AGENT_SOURCE_REVIEW_COMPLETED_NO_NATIVE_CLAIM")
        q["semantic_ids"]=sorted(set(q.get("semantic_ids",[])+ids))
    d["file_dispositions"]=list(dispositions.values())
    d["coverage_review"]={"owner":OWNER,"scope":"G0 source inventory; not Core or native product acceptance",
        "current_lexical_candidates":len(candidate_paths),"unclassified_lexical_candidates":sorted(candidate_paths-set(dispositions)),
        "all_new_paths_classified":set(d["source_census"]["added_paths"])<=set(dispositions),
        "semantic_areas":dict(collections.Counter(r["area"] for r in rows)),
        "status_meaning":"supported means source-wired only; runtime_evidence and native_receipt remain authoritative for execution"}
    d["summary"].update(semantic_surfaces=len(rows),new_native_contract_surfaces=9,
        source_coverage_review="EXECUTED_PASS_SOLE_AGENT",lexical_candidates=len(candidate_paths),
        file_dispositions=len(dispositions),new_paths_classified=len(d["source_census"]["added_paths"]))
    examples=m.original("UI_ROUTE_EXAMPLES.json")
    for e in examples["examples"]:
        r=byid[e["destination_id"]]
        e.update(expected_now=r["route_implementation"]+"; "+r.get("note",""),
            source_sha=source,execution="MANUAL_PLAN_NOT_EXECUTED")
    examples["source_sha"]=source
    examples["registered"]=False
    examples["current_native_examples"]=[
        {"case":"Library public root and private query","registry_id":"native.library","presentation":"currentTab","input":"Canonical v2 root with current backend; no private query or tab/scene fields","expected":"Original Library visible and canonical receipt; original Reader/workspace and private Library query survive History/back"},
        {"case":"TOC original selected Reader","registry_id":"native.reader.toc","presentation":"currentTab","input":"Canonical v2 root while the exact original iPad Reader has loaded matching TOC","expected":"Original TOC rows and actual receipt; Reader/locator and private TOC filter survive Library/back"},
        {"case":"TOC no-reader refusal","registry_id":"native.reader.toc","presentation":"currentTab","input":"Same canonical root without an original selected Reader/TOC","expected":"Explicit refusal; no receipt or substitute Reader; original Library preserved"},
        {"case":"Phone original Library","registry_id":"native.library","presentation":"currentTab","input":"Canonical v2 root from original compact Reader","expected":"Actual Library NavigationStack root; original selected workspace Reader owner/tab/book preserved"},
        {"case":"History public v1/v2","registry_id":"native.history","presentation":"currentTab","input":"Use canonical original NativeRouteURL or NativePublicNavigationURLV2 encoder and active backend; no private search text","expected":"Exact foreground History visible plus original native receipt"},
        {"case":"Search root","registry_id":"native.search","presentation":"currentTab","input":"Canonical public v1/v2 root with current backend, no query payload","expected":"Original Search root and exact native receipt; original private query retained without submitting"},
        {"case":"Annotations root","registry_id":"native.annotations","presentation":"currentTab","input":"Canonical public v1/v2 root with current backend, no note/draft/mutation payload","expected":"Original Annotations root and exact native receipt; no import/export/delete request"},
        {"case":"Settings public v2","registry_id":"native.settings","presentation":"sheet","input":"Use canonical NativePublicNavigationURLV2 encoder; current backend; root only","expected":"Actual Settings sheet visible; no backend/settings writes"},
        {"case":"Reader positive","registry_id":"native.reader","presentation":"currentTab","input":"Current phone/iPad active book, known source line from independently hashed fixture, explicit section and focus, sameTab; use canonical v2 codec","expected":"Original TextKit glyph at exact source line and original full Core completion receipt"},
        {"case":"Reader other-book/current-only refusal","registry_id":"native.reader","presentation":"currentTab","input":"A different known fixture book while current-only binding is installed","expected":"No acknowledgement or mutation; explicit unsupported route"},
        {"case":"Reader other-book newTab","registry_id":"native.reader","presentation":"newTab","input":"Independent known other fixture book and exact source line, same original v2 codec","expected":"Exactly one new original tab, exact rendered line/highlight, full Core receipt, prior tabs retained and native return restores original locator"},
        {"case":"Reader same-book distinct newTab","registry_id":"native.reader","presentation":"newTab","input":"Current known fixture book and exact source line; newTab explicitly requested","expected":"Distinct original UUID/Reader owner, existing same-book tab retained, exact rendered line and full Core receipt"},
        {"case":"Phone current Reader","registry_id":"native.reader","presentation":"currentTab","input":"Original compact owner, real source section/focus, same canonical v2 codec","expected":"Actual NavigationStack reader and exact rendered source line, full Core receipt"},
        {"case":"Phone new Reader tab","registry_id":"native.reader","presentation":"newTab","input":"Known different source book, original phone owner reservation","expected":"New original tab with all prior identities retained; original overview cell returns to previous exact locator"},
        {"case":"Phone cross-book sameTab refusal","registry_id":"native.reader","presentation":"currentTab","input":"Known different source book while currentTab is explicitly requested","expected":"No replacement or acknowledgement; original compact Reader retained"},
        {"case":"Stale scene/owner/backend","registry_id":"native.reader","input":"Invoke after actual owner or backend changes; never inject authority fields into public JSON","expected":"Original live-ownership fence rejects, no success receipt"}
    ]
    examples["current_native_examples"] += [
        {"case":"System book/named chapter","registry_id":"native.reader","presentation":"newTab","input":"Original Core book entity, actual source TOC title and exact Library window through Apple AppIntentsTesting","expected":"Exact independent SQL text/locator, original new tab and canonical receipt; return to retained original Reader"},
        {"case":"System cached source/background","registry_id":"native.reader","presentation":"newTab","input":"Stable source-qualified location ID revalidated by Core after background","expected":"Exact original source TextKit text and selection; prior tab identities and original reading position retained"},
        {"case":"System wrong-book refusal","registry_id":"native.reader","input":"Location belonging to another selected book","expected":"System refuses without native receipt, tab or original Reader change"},
        {"case":"System missing-source refusal","registry_id":"native.reader","input":"Canonical-shaped ID with a nonexistent source line","expected":"Original Core source validation refuses; no invented location, successful intent or tab mutation"},
        {"case":"Phone system Reader ownership","registry_id":"native.reader","presentation":"newTab","input":"Real system book/location intent after background on compact phone","expected":"Original phone Reader and exact source; original overview returns to retained prior tab"}
    ]
    examples["current_native_examples"] += [
        {"case":"Visible Search query component on iPad and iPhone","registry_id":"native.search","component":"native.search.query","presentation":"currentTab","input":"Canonical v2 component after original Search root is visibly mounted; no private query","expected":"Same original UIKit field becomes first responder, private input unchanged, real keyboard typing without another tap and canonical component receipt"},
        {"case":"Unavailable or unknown Search component","registry_id":"native.search","component":"native.search.query","input":"Known component outside visible Search, or unknown component in Search","expected":"Refusal with no native receipt, no query submission or replacement of original Reader"},
        {"case":"System Search field focus","registry_id":"native.search","component":"native.search.query","input":"Live NativeDestinationEntity for Search field through existing OpenNativeDestinationIntent and Apple AppIntentsTesting","expected":"Original field receives real keyboard input and same Core-validated native component receipt; a stale entity cannot reuse a root's eligibility"}
    ]
    examples["current_native_execution"]="NOT_RUN_ON_THIS_SOURCE"
    scan=dict(schema_version=1,source_sha=source,embedded_source=old["embedded_source"],
        inspector_dependency=old["inspector_dependency"],kind="immutable_source_census_not_native_acceptance",
        files=files,file_count=len(files),ui_candidate_count=len(candidate_paths))
    # Validate actual immutable references and all semantic cross-links, not just counts.
    assert len({r["id"] for r in rows})==len(rows)
    assert not d["coverage_review"]["unclassified_lexical_candidates"]
    assert d["coverage_review"]["all_new_paths_classified"]
    assert all(set(r["backends"])=={"otzaria","sefaria","sefariaEmbedded"} for r in rows)
    for r in rows:
        sr=r["source"];f=byfile[sr["path"]]
        assert sr["git_blob"]==f["git_blob"] and sr["sha256"]==f["sha256"],r["id"]
        assert 1<=sr["line"]<=f["lines"],r["id"]
        assert sr["anchor"] in sr["source_line"],r["id"]
        assert r["runtime_evidence"]=="NOT_RUN",r["id"]
    for q in dispositions.values():
        assert q["sha256"]==byfile[q["path"]]["sha256"],q["path"]
        assert all(i in byid for i in q["semantic_ids"]),q["path"]
    assert len(examples["examples"])==27
    assert {x["backend"] for x in examples["examples"]}=={"otzaria","sefaria","sefariaEmbedded"}
    assert not any("independent_review_PENDING" in str(q) for q in dispositions.values())
    write("SOURCE_SCAN.json",scan);write("UI_ROUTE_COVERAGE.json",d)
    write("UI01_CURRENT_HANDOFF.json",d);write("UI_ROUTE_EXAMPLES.json",examples)
    def cell(v):return str(v).replace("|","/").replace("\n"," ")
    lines=["# UI surface inventory — continuation 2026-11-18","",
        "Source: "+source+". This is the G0 source inventory. A supported row means source wiring, never a native PASS.","",
        "Owner/review: "+OWNER+". The owner explicitly requested solo execution; no independent QA was represented.","",
        f"{len(rows)} semantic rows, {len(files)} immutable source files, {len(candidate_paths)} lexical candidates, {len(dispositions)} file dispositions, 27 retained manual scenarios and {len(examples['current_native_examples'])} current native scenarios.","",
        "## Installed native scope","",
        "Library/TOC/History/Search/Annotations/current tab and Settings/root sheet are connected to the original foreground scene orchestrator. Phone roots pop the original selectedBook presentation while retaining its tab/model. Reader/public-v2 is connected to the original ActionCore for the current phone/iPad book and tab, with original TextKit visibility. An R-owned newTab reservation now opens an original additional Reader tab, with canonical Core and actual TextKit visibility; sameTab cross-book remains refused. Phone content uses the original compact owner and passive NavigationStack witness. Rich component destinations and Siri Reader invocation remain unfinished. Inventory IDs are not installed registry IDs.","",
        "Native, Siri and physical-device execution is reported separately against the exact tested commit; this document does not award any native pass.","",
        "## Registry maintenance","",
        "1. On every UI or navigation change, run reconcile.py followed by finalize_inventory.py against the full immutable code SHA.","2. Review new/removed source paths, changed anchors, native descriptor rules, backend capability conditions and privacy fields. Add or migrate stable IDs only for meaningful destinations.","3. Every new lexical UI candidate must have a semantic mapping or a reviewed non-route disposition. Decorative components and test fixtures must never become public actions.","4. Public changes must use the existing Core/UI Registry versioned codecs, resolver and native authority. Do not encode scene/workspace identifiers, grants, queries, drafts or selection text in a public link.","5. Retain historic inventories. Record exact compile/native/device receipts separately and re-run affected real acceptance before marking runtime support.","",
        "## Semantic rows","",
        "All rows include explicit Otzaria, Sefaria Legacy and Sefaria Embedded variants in UI_ROUTE_COVERAGE.json; conditional assets/readiness and trusted host context remain separate from code presence.",""]
    for area in sorted({r["area"] for r in rows}):
        lines+=["### "+area,"","| Stable ID | Destination/control; owner | Source | Inputs; visible state | Dependencies; suitability; security | Status / test |","|---|---|---|---|---|---|"]
        for r in [x for x in rows if x["area"]==area]:
            sr=r["source"]
            values=[r["id"],r["screen_section_component"]+"; "+r["owning_view_model"],
                sr["path"]+":"+str(sr["line"]),", ".join(r["inputs"])+"; "+r["visible_state"],
                r["dependencies_and_requirements"]+"; "+json.dumps(r["suitability"],ensure_ascii=False)+"; security "+str(r["security_tier"]),
                r["status"]+" / "+r["route_implementation"]+" / "+r["tests"]["case_plan_id"]+" / Native NOT_RUN"]
            lines.append("| "+" | ".join(cell(v) for v in values)+" |")
        lines.append("")
    lines+=["## Source caveats",""]
    for c in d["source_caveats"]:lines+=["- "+c["id"]+": "+c["status"]+". "+c["detail"]]
    lines+=["","## Manual examples","", "UI_ROUTE_EXAMPLES.json retains all 27 per-backend manual plans and adds canonical Library/TOC roots, unavailable TOC refusal, compact Library preservation, History, Search, Annotations, Settings, current-book Reader, sameTab other-book refusal, two newTab ownership scenarios, three phone content scenarios and stale-owner scenarios. They are plans, not execution evidence.",""]
    (HERE/"UI_SURFACE_INVENTORY.md").write_text("\n".join(lines),encoding="utf-8")
    report=dict(source_sha=source,source_files_verified=len(files),semantic_anchors_verified=len(rows),
        lexical_candidates=len(candidate_paths),file_dispositions=len(dispositions),unclassified_candidates=0,
        new_paths_classified=len(d["source_census"]["added_paths"]),manual_semantic_examples=27,current_native_plans=len(examples['current_native_examples']),
        status="SOURCE_DOCUMENT_VALIDATION_PASS",review_owner=OWNER,native_runtime_tests_executed=0,
        physical_device_tests_executed=0,scope_exclusion="No source-document check certifies app/provider/UI/Siri/physical runtime")
    report["artifact_sha256"]={n:hashlib.sha256((HERE/n).read_bytes()).hexdigest() for n in ["SOURCE_SCAN.json","UI_ROUTE_COVERAGE.json","UI_SURFACE_INVENTORY.md","UI_ROUTE_EXAMPLES.json"]}
    write("VALIDATION_REPORT.json",report)
    print(json.dumps(report,ensure_ascii=False))
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--source",required=True);main(ap.parse_args().source)
