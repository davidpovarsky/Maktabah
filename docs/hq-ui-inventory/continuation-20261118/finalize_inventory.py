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
        ("history","Native History/current tab",'.init(id: id("native.history")',"currentTab","v1_and_v2","Current backend, foreground exact scene, empty global History search, no implicit backend switch",["inventory.v1.tab.history","inventory.v1.history.list"]),
        ("search","Native Global Search/current tab",'.init(id: id("native.search")',"currentTab","v1_and_v2","Original Search root, original capability availability and current foreground scene; retains private query, never submits it or encodes it in a public URL",["inventory.v1.tab.search"]),
        ("annotations","Native Annotations/current tab",'.init(id: id("native.annotations")',"currentTab","v1_and_v2","Original Annotations root in current foreground scene; no draft/import/export/delete or annotation write action",["inventory.v1.tab.annotations","inventory.v1.annotations.list"]),
        ("settings","Native Settings/sheet",'.init(id: id("native.settings")',"sheet","v2","Current backend, foreground exact scene; root sheet only, no subsection mutation",["inventory.v1.shell.settings-sheet","inventory.v1.settings.root"]),
        ("reader","Native Reader/current iPad book",'.init(id: id("native.reader")',"currentTab","v2","iPad live original workspace/active tab/current book, current backend, Core validated section/focus and original TextKit visible glyph; cross-book/newTab/phone content not implemented",["inventory.v1.reader.content","inventory.v1.reader.viewport"])
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
        row["suitability"].update(app_intent="installed_foreground_gated" if dest!="reader" else "not_advertised_reader_intent_unfinished",
            deep_link="canonical_"+version+"_identity_only",hanlin="thin_existing_SDK_adapter_only_not_app_registered")
        rows.append(row)
        for alias in aliases:
            r=byid[alias];r.update(route_implementation="SOURCE_WIRED_CONDITIONAL",installed_registry_id="native."+dest,
                status="supported",note=limits+"; inventory support describes code wiring, not a native PASS")
            for b in r["backends"].values():b.update(route="SOURCE_WIRED_CONDITIONAL",reason=limits)
    for kind,path,anchor,title in [
        ("foreground-intent","Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeDestinationIntents.swift","public struct OpenNativeDestinationIntent: AppIntent","Foreground App Intent"),
        ("shortcut","Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeIntents.swift","struct MaktabahNativeShortcuts: AppShortcutsProvider","Native destination App Shortcut")]:
        r=copy.deepcopy(rows[-3])
        r.update(id="inventory.v1.native."+kind,screen_section_component=title,source=ref(path,anchor),
            owning_view_model="NativeIntentService / original registered NativeDestinationEntityQuery",
            installed_registry_id=None,linked_semantic_action=None,
            note="App metadata and foreground service installed for eligible History/Search/Annotations/Settings; actual Siri/Shortcuts invocation NOT_RUN; Reader content is not advertised")
        rows.append(r)
    byid={r["id"]:r for r in rows}
    byid["inventory.v1.app.scene"]["note"]="Real MaktabahNativeRoutingHost mounts using actual UIKit scene identity and original workspace lifecycle; exact target is retained by NativeSceneDirectory. Root History/Search/Annotations/Settings and limited iPad Reader only."
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
    d["summary"].update(semantic_surfaces=len(rows),new_native_contract_surfaces=7,
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
        {"case":"History public v1/v2","registry_id":"native.history","presentation":"currentTab","input":"Use canonical original NativeRouteURL or NativePublicNavigationURLV2 encoder and active backend; no private search text","expected":"Exact foreground History visible plus original native receipt"},
        {"case":"Settings public v2","registry_id":"native.settings","presentation":"sheet","input":"Use canonical NativePublicNavigationURLV2 encoder; current backend; root only","expected":"Actual Settings sheet visible; no backend/settings writes"},
        {"case":"Reader positive","registry_id":"native.reader","presentation":"currentTab","input":"Current iPad active book, known source line from independently hashed fixture, explicit section and focus, sameTab; use canonical v2 codec","expected":"Original TextKit glyph at exact source line and original full Core completion receipt"},
        {"case":"Reader other-book/current-only refusal","registry_id":"native.reader","presentation":"currentTab","input":"A different known fixture book while current-only binding is installed","expected":"No acknowledgement or mutation; explicit unsupported route"},
        {"case":"Stale scene/owner/backend","registry_id":"native.reader","input":"Invoke after actual owner or backend changes; never inject authority fields into public JSON","expected":"Original live-ownership fence rejects, no success receipt"}
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
        f"{len(rows)} semantic rows, {len(files)} immutable source files, {len(candidate_paths)} lexical candidates, {len(dispositions)} file dispositions, 27 retained manual scenarios and five current native scenarios.","",
        "## Installed native scope","",
        "History/Search/Annotations/current tab and Settings/root sheet are connected to the original foreground scene orchestrator. Phone roots pop the original selectedBook presentation while retaining its tab/model. Reader/public-v2 is connected to the original ActionCore for the current iPad book and tab, with original TextKit visibility. Reader cross-book/new-tab/phone content, component destinations, and Siri Reader invocation remain unfinished. Inventory IDs are not installed registry IDs.","",
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
    lines+=["","## Manual examples","", "UI_ROUTE_EXAMPLES.json retains all 27 per-backend manual plans and adds canonical History, Settings, current-book Reader, other-book refusal and stale-owner scenarios. They are plans, not execution evidence.",""]
    (HERE/"UI_SURFACE_INVENTORY.md").write_text("\n".join(lines),encoding="utf-8")
    report=dict(source_sha=source,source_files_verified=len(files),semantic_anchors_verified=len(rows),
        lexical_candidates=len(candidate_paths),file_dispositions=len(dispositions),unclassified_candidates=0,
        new_paths_classified=len(d["source_census"]["added_paths"]),manual_semantic_examples=27,current_native_plans=5,
        status="SOURCE_DOCUMENT_VALIDATION_PASS",review_owner=OWNER,native_runtime_tests_executed=0,
        physical_device_tests_executed=0,scope_exclusion="No source-document check certifies app/provider/UI/Siri/physical runtime")
    report["artifact_sha256"]={n:hashlib.sha256((HERE/n).read_bytes()).hexdigest() for n in ["SOURCE_SCAN.json","UI_ROUTE_COVERAGE.json","UI_SURFACE_INVENTORY.md","UI_ROUTE_EXAMPLES.json"]}
    write("VALIDATION_REPORT.json",report)
    print(json.dumps(report,ensure_ascii=False))
if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--source",required=True);main(ap.parse_args().source)
