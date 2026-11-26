#!/usr/bin/env python3
"""Account for every retained UI requirement at a pinned source; never infer runtime PASS."""
import argparse
import collections
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("--repo", type=Path, required=True)
p.add_argument("--source", required=True)
p.add_argument("--upstream", required=True)
p.add_argument("--inspector-repo", type=Path, required=True)
p.add_argument("--sefaria-proof", type=Path, required=True)
p.add_argument("--contracts", type=Path, required=True)
p.add_argument("--output", type=Path, required=True)
a = p.parse_args()
if a.output.exists():
    raise SystemExit("Preserve evidence: output already exists")

def git(repo, *args, required=True):
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True)
    if r.returncode and required:
        raise RuntimeError(r.stderr.decode(errors="replace"))
    return r

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

source = git(a.repo, "rev-parse", a.source + "^{commit}").stdout.decode().strip()
upstream = git(a.repo, "rev-parse", a.upstream + "^{commit}").stdout.decode().strip()
cache = {}

def blob(repo, ref, path, required=True):
    key = (str(repo), ref, path)
    if key not in cache:
        r = git(repo, "show", ref + ":" + path, required=False)
        cache[key] = r.stdout if r.returncode == 0 else None
    value = cache[key]
    if value is None and required:
        raise RuntimeError("Missing pinned source: " + ref + ":" + path)
    return value

def read(path):
    return blob(a.repo, source, path)

def text(path):
    return read(path).decode("utf-8")

def evidence(path):
    raw = read(path)
    return {"path": path, "source_ref": source, "sha256": sha(raw),
            "git_blob": git(a.repo, "rev-parse", source + ":" + path).stdout.decode().strip()}

historical_path = "docs/hq-ui-inventory/continuation-20261118/UI_ROUTE_COVERAGE.json"
prior_path = "docs/hq-ui-inventory/reconciliation-20261120/CROSSWALK.json"
historical_raw = read(historical_path)
historical = json.loads(historical_raw)
prior = json.loads(read(prior_path))
rows = historical["semantic_surfaces"]
ids = {row["id"] for row in rows}
assert len(rows) == len(ids) == 294
assert {r["id"] for r in prior["surfaces"]} == ids

lock_path = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
pins = json.loads(read(lock_path))["pins"]
inspector_pin = next(p["state"]["revision"] for p in pins if p["identity"] == "torahinspectorkit")
embedded_entry = git(a.repo, "ls-tree", source, "--", "Vendor/SefariaMobile/Upstream").stdout.decode().split()
assert embedded_entry[0:2] == ["160000", "commit"]
embedded_pin = embedded_entry[2]
sefaria_raw = a.sefaria_proof.read_bytes()
sefaria = json.loads(sefaria_raw)
assert sefaria["source_ref"] == embedded_pin
assert sefaria["historical_manifest_sha256"] == sha(historical_raw)
sefaria_rows = {r["id"]: r for r in sefaria["rows"]}
expected_sefaria = {r["id"] for r in rows if r["source"]["path"].startswith("Vendor/SefariaMobile/Upstream/")}
assert set(sefaria_rows) == expected_sefaria
assert len(expected_sefaria) == 45
contracts_raw = a.contracts.read_bytes()
contracts = json.loads(contracts_raw)
assert len({t["id"] for t in contracts["tasks"]}) == len(contracts["tasks"]) == 14

# This explicit reconciliation retains the original locator and describes why
# it moved. The user-visible action and its destructive role still exist.
anchor_reconciliations = {
    "inventory.v1.workspace.profile.delete":
        'Button(localized("Delete Profile", "מחיקת פרופיל"), role: .destructive)'
}

def current_anchor(row):
    old = row["source"]; path = old["path"]
    if row["id"] in sefaria_rows:
        proof = sefaria_rows[row["id"]]
        assert proof["path"] == path and proof["historical_anchor"] == old["anchor"]
        assert proof["historical_sha256"] == old["sha256"]
        assert proof["historical_occurrence"] == old.get("occurrence", 1)
        return {**proof, "storage": "PINNED_EXTERNAL_GIT_OBJECT",
                "repository": "https://github.com/Sefaria/Sefaria-Mobile.git",
                "proof_reference": a.sefaria_proof.name}
    repo, ref, object_path = a.repo, source, path
    external = path.startswith("DependencyObjects/TorahInspectorKit/")
    if external:
        repo, ref = a.inspector_repo, inspector_pin
        object_path = path.removeprefix("DependencyObjects/TorahInspectorKit/")
    raw = blob(repo, ref, object_path)
    lines = raw.decode("utf-8").splitlines()
    anchor = old["anchor"]; occurrence = old.get("occurrence", 1)
    hits = [i + 1 for i, line in enumerate(lines) if anchor in line]
    out = {"path": path, "object_path": object_path, "source_ref": ref,
           "storage": "PINNED_EXTERNAL_GIT_OBJECT" if external else "PINNED_APP_GIT_OBJECT",
           "repository": "https://github.com/davidpovarsky/TorahInspectorKit.git" if external else "https://github.com/davidpovarsky/Maktabah.git",
           "git_blob": git(repo, "rev-parse", ref + ":" + object_path).stdout.decode().strip(),
           "historical_anchor": anchor, "historical_occurrence": occurrence,
           "historical_sha256": old["sha256"], "current_sha256": sha(raw),
           "unchanged_file": sha(raw) == old["sha256"], "matching_lines": hits,
           "status": "ANCHOR_PRESENT" if len(hits) >= occurrence else "HISTORICAL_ANCHOR_MISSING"}
    if out["status"] != "ANCHOR_PRESENT" and row["id"] in anchor_reconciliations:
        new_anchor = anchor_reconciliations[row["id"]]
        current_hits = [i + 1 for i, line in enumerate(lines) if new_anchor in line]
        assert len(current_hits) == 1
        out.update(status="LOCALIZED_ANCHOR_RECONCILED", current_anchor=new_anchor,
                   current_matching_lines=current_hits,
                   reconciliation="Original Delete Profile action now uses the existing bilingual localized helper; same .destructive role. No original requirement removed.")
    if not external:
        original = blob(a.repo, upstream, path, required=False)
        out["upstream_comparison"] = {"ref": upstream, "path_present": original is not None,
            "sha256": sha(original) if original is not None else None,
            "same_bytes": raw == original if original is not None else None,
            "boundary": "Path/byte provenance only; this is not owner authorization or upstream synchronization."}
    return out

composition = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"
registry_path = "Source/Otzaria/Actions/Sources/OtzariaActionCore/Registry/ActionRegistry.swift"
hanlin_path = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinHostAdapter.swift"
guide_path = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift"
runtime = text(composition)
implemented = sorted(re.findall(r'"([^"\n]+)"',
    re.search(r"public static let implemented: Set<String> = \[(.*?)\]", text(registry_path), re.S)[1]))
catalog_path = "Source/Otzaria/Actions/Sources/OtzariaActionCore/Resources/action-catalog.v1.json"
catalog_ids = {x["id"] for x in json.loads(read(catalog_path))["actions"]}
assert set(implemented) <= catalog_ids
descriptor_text = runtime.split("registry = try UIDestinationRegistry(descriptors: [", 1)[1].split("\n        ])", 1)[0]
descriptors = {}
for part in re.split(r'(?=\.init\(id: id\("native\.)', descriptor_text):
    match = re.search(r'\.init\(id: id\("([^"]+)"\)', part)
    if not match:
        continue
    descriptors[match[1]] = {
        "presentations": re.findall(r"\.(\w+)", re.search(r"presentations: \[([^]]+)\]", part)[1]),
        "required_core_actions": re.findall(r'"([^"]+)"', re.search(r"requiredCoreActions: \[([^]]*)\]", part)[1]),
        "supported_backend_declaration": ["otzaria", "sefaria", "sefariaEmbedded"] if "ActionBackendID.allCases" in part else [],
        "public_v2_policy": "publicNavigationV2:" in part,
        "requires_content": "requiresContent: true" in part,
        "anchors": re.findall(r'id\("([^"]+)"\)', re.search(r"anchors: \[([^]]*)\]", part)[1]) if "anchors:" in part else [],
        "source_anchor": '.init(id: id("' + match[1] + '")',
        "boundary": "Registry declaration is conditional on current backend, scene, source, authority and actual visible acknowledgement."}
assert len(descriptors) == 10
metadata_actions = sorted(re.findall(r'"([^"]+)"',
    re.search(r"metadataReadActions: Set<String> = \[(.*?)\]", text(hanlin_path), re.S)[1]))
assert "OtzariaHanlinHostAdapter.metadataReadActions" in runtime
assert '.union(readScope == nil ? [] : ["search.query"])' in runtime
hanlin_transport = dict(re.findall(r'"([^"]+)": "([^"]+)"',
    re.search(r"private static let names: \[String: String\] = \[(.*?)\]", text(hanlin_path), re.S)[1]))
guide_definition = text(guide_path).split("static func appTour()", 1)[1].split("\n    }\n}", 1)[0]
guide_destinations = re.findall(r'UIDestinationID\(rawValue: "([^"]+)"\)', guide_definition)
assert guide_destinations == ["native.library", "native.search", "native.history"]
entitlements_path = "Source/ChavrusaText-iOS.entitlements"
entitlements = plistlib.loads(read(entitlements_path))
associated_domains = entitlements.get("com.apple.developer.associated-domains", [])
assert "applinks:davidpovarsky.github.io" in associated_domains

groups = {
    "native.library": ["tab.library", "library.catalog", "native.library"],
    "native.reader.toc": ["toc.contents", "native.reader.toc"],
    "native.history": ["tab.history", "history.list", "native.history"],
    "native.search": ["tab.search", "native.search", "search.input-focus"],
    "native.annotations": ["tab.annotations", "annotations.list", "native.annotations"],
    "native.settings": ["shell.settings-sheet", "settings.root", "native.settings"],
    "native.reader.inspector": ["inspector.panel", "inspector.sheet", "native.reader.inspector"],
    "native.reader": ["reader.content", "reader.viewport", "native.reader", "native.reader-new-tab"],
}
mapped = {"inventory.v1." + ident: dest for dest, names in groups.items() for ident in names}
core_routes = {
    "inventory.v1.notes.draft": ("native.reader.noteDraft", "notes.prepareDraft"),
    "inventory.v1.search.global": ("native.search.results", "search.openResults"),
    "inventory.v1.inspector.related-source": ("native.reader", "reader.openCommentary"),
}
intent_definitions = {"inventory.v1.native.foreground-intent", "inventory.v1.native.shortcut", "inventory.v1.native.reader-intent"}
legacy_links = {"inventory.v1.legacy-link.history", "inventory.v1.legacy-link.annotation"}
assert set(mapped) | set(core_routes) | intent_definitions | legacy_links <= ids

infrastructure = {
    "future.registry": ("Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Registry/UIDestinationRegistry.swift", "UIDestinationRegistry"),
    "future.orchestrator": ("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSceneNavigationOrchestrator.swift", "NativeSceneNavigationOrchestrator"),
    "future.app-intents": ("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderIntents.swift", "OpenBookAtLocationIntent"),
    "future.universal-links": ("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativePublicNavigationURLV2.swift", "davidpovarsky.github.io"),
    "future.guide-spotlight": ("Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Guides/GuidedNavigation.swift", "UIGuideRun"),
    "future.hanlin-host": (hanlin_path, "OtzariaHanlinHostAdapter"),
}
infrastructure = {"inventory.v1." + key: value for key, value in infrastructure.items()}
for path, anchor in infrastructure.values():
    assert anchor in text(path), (path, anchor)

test_paths = [x for x in git(a.repo, "ls-tree", "-r", "--name-only", source,
    "Maktabah-iOSUITests", "Source/ChavrusaText/UIRoutingHost/Tests",
    "Source/Otzaria/UIRouting/Tests").stdout.decode().splitlines() if x.endswith(".swift")]
test_catalog = {}
test_functions = {}
for path in test_paths:
    raw = read(path); contents = raw.decode()
    methods = re.findall(r"\bfunc (test[A-Za-z0-9_]+)\s*\(", contents)
    test_catalog[path] = {**evidence(path), "declared_test_methods": sorted(set(methods)),
                          "execution_on_this_snapshot": "NOT_RUN_BY_CROSSWALK"}
    declarations = list(re.finditer(r"\bfunc (\w+)\s*\(", contents))
    test_functions[path] = [
        (m[1], contents[m.start():declarations[i+1].start() if i+1 < len(declarations) else len(contents)],
         contents[:m.start()].count("\n") + 1)
        for i, m in enumerate(declarations)
    ]

native = "Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift"
route_tests = {
    "native.library": ["testPublicV2LibraryPreservesPrivateQueryAndOriginalReader", "testPhonePublicV2LibraryPreservesOriginalReaderOwner"],
    "native.reader.toc": ["testPublicV2TOCPreservesPrivateFilterAndOriginalReader", "testPublicV2TOCWithoutOriginalReaderCannotAcknowledge"],
    "native.history": ["testWarmHistoryURLUsesOtzariaNativeScene", "testWarmHistoryURLUsesLegacyNativeScene", "testWarmHistoryURLUsesEmbeddedNativeScene", "testColdHistoryURLWaitsForActualSceneMount"],
    "native.search": ["testGlobalSearchPublicRootPreservesOriginalPrivateQuery", "testSystemAppIntentFocusesOriginalSearchComponent", "testPublicV2SearchQueryFocusUsesOriginalFirstResponder"],
    "native.search.results": ["testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPad", "testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPhone"],
    "native.annotations": ["testAnnotationsPublicRootShowsOriginalScreenAndNativeReceipt"],
    "native.settings": ["testSystemAppIntentSettingsShowsOriginalSheetAndReceipt"],
    "native.reader.inspector": ["testPublicV2InspectorPreservesOriginalReaderAndWorkspace", "testSystemAppIntentShowsOriginalReaderInspector", "testPhoneSystemAppIntentShowsOriginalReaderInspector"],
    "native.reader.noteDraft": ["testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPad", "testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPhone"],
    "native.reader": ["testPublicV2CurrentReaderShowsTwoCanonicalSourceLines", "testPublicV2NewTabSameBookCreatesDistinctOriginalReaderTab", "testSystemBookIntentResolvesNamedChapterThroughOriginalCore", "testPhoneSystemBookIntentUsesOriginalReaderOwner"],
}
for dest, methods in route_tests.items():
    assert dest in descriptors
    assert set(methods) <= set(test_catalog[native]["declared_test_methods"])

def tests_for(row, dest):
    old = row.get("tests", {})
    candidate = old.get("candidate_existing_suite") or {}
    candidate_path = candidate.get("path")
    result = {"original_case_plan_id": old.get("case_plan_id"),
              "original_required_checks": old.get("required", []),
              "historical_candidate_suite": candidate,
              "current_related_suite": test_catalog.get(candidate_path),
              "current_route_tests": [],
              "literal_identifier_references": [],
              "runtime_boundary": "A source reference, related suite or declared test is not an executed test or exact-row acceptance."}
    if dest:
        result["current_route_tests"] = [{"path": native, "method": method, "relationship": "destination-level regression; exact component requirements remain separate"}
                                        for method in route_tests.get(dest, [])]
    match = re.search(r'accessibilityIdentifier\("([^"]+)"\)', row["source"]["anchor"])
    if match:
        token = '"' + match[1] + '"'
        for path, functions in test_functions.items():
            for name, body, line in functions:
                if token in body:
                    result["literal_identifier_references"].append({"path": path, "function": name, "line": line,
                       "identifier": match[1], "relationship": "literal source reference; inspect assertion and runtime separately"})
    return result

def contexts_for(short):
    prefix = short.split(".", 1)[0]
    contexts = {"library": ["native.library"], "toc": ["native.reader.toc"],
                "reader": ["native.reader"], "inspector": ["native.reader.inspector"],
                "notes": ["native.reader.noteDraft"], "annotations": ["native.annotations"],
                "search": ["native.search"], "settings": ["native.settings"],
                "history": ["native.history"], "sidebar": ["native.library", "native.reader.toc"],
                "workspace": ["native.reader"]}
    return contexts.get(prefix, [])

backends = ["otzaria", "sefaria", "sefariaEmbedded"]
ingresses = ["in_app", "app_intents", "urls", "hanlin", "guides"]
surfaces = []
for row in rows:
    ident = row["id"]; short = ident.removeprefix("inventory.v1.")
    action = (row.get("linked_semantic_action") or {}).get("id")
    anchor = current_anchor(row)
    dest = mapped.get(ident) or (core_routes.get(ident) or (None,))[0]
    kind = "NO_EXACT_COMPONENT_ROUTE_ESTABLISHED"
    statuses = {ingress: "NO_EXACT_COMPONENT_BINDING_ESTABLISHED" for ingress in ingresses}
    statuses["in_app"] = "SOURCE_COMPONENT_PRESENT_ACTIVATION_AND_STATE_ACCEPTANCE_SEPARATE"
    if ident in mapped:
        kind = "ROOT_OR_CANONICAL_READER_SUBSET"
        statuses.update(in_app="REGISTRY_SOURCE_WIRED_CONDITIONAL",
                        app_intents="THIN_FOREGROUND_INTENT_SOURCE_WIRED_CONDITIONAL",
                        urls="PUBLIC_V2_DECODER_AND_ASSOCIATED_DOMAIN_PRESENT_OS_HANDOFF_OPEN")
        if dest in guide_destinations:
            statuses["guides"] = "ACTUAL_THREE_STEP_GUIDE_DESTINATION_SOURCE_WIRED"
        if dest == "native.reader":
            statuses["hanlin"] = "EXISTING_SDK_SOURCE_LINK_NAVIGATION_CONDITIONAL"
    if ident in core_routes:
        kind = "TRUSTED_CORE_TO_ORIGINAL_NATIVE_ROUTE"
        statuses["in_app"] = "ORIGINAL_CORE_PREPARE_DELIVER_VISIBLE_ACK_SOURCE_WIRED"
        if ident in {"inventory.v1.notes.draft", "inventory.v1.inspector.related-source"}:
            statuses["app_intents"] = "OPTIONAL_BOOK_INTENT_SEMANTIC_JOURNEY_SOURCE_WIRED"
    if action in metadata_actions and statuses["hanlin"] == "NO_EXACT_COMPONENT_BINDING_ESTABLISHED":
        statuses["hanlin"] = "METADATA_TOOL_SOURCE_ONLY_NOT_COMPONENT_NAVIGATION"
    if ident in intent_definitions:
        kind = "SYSTEM_INGRESS_DEFINITION"
        statuses["app_intents"] = "THIN_FOREGROUND_INTENT_SOURCE_WIRED_CONDITIONAL"
    if ident in legacy_links:
        kind = "LEGACY_URL_HANDLER_RETAINED"
        statuses["urls"] = "EXISTING_LEGACY_HANDLER_NO_NEW_REGISTRY_ACK_ASSERTED"
    supplemental = None
    if ident in infrastructure:
        path, actual_anchor = infrastructure[ident]
        kind = "FORMER_FUTURE_ROW_NOW_HAS_REAL_INFRASTRUCTURE"
        supplemental = {**evidence(path), "anchor": actual_anchor,
            "status": "SOURCE_IMPLEMENTED_CONDITIONAL_RUNTIME_ACCEPTANCE_SEPARATE"}
    cells = {backend: {ingress: {"source_status": statuses[ingress],
              "runtime_on_this_source": "NOT_RUN_BY_CROSSWALK",
              "original_backend_contract": row.get("backends", {}).get(backend)}
              for ingress in ingresses} for backend in backends}
    surfaces.append({
        "id": ident, "area": row["area"], "label": row["screen_section_component"],
        "original_contract": {key: row.get(key) for key in ["inputs", "visible_state",
            "dependencies_and_requirements", "security_tier", "suitability", "status"]},
        "original_route_implementation": row.get("route_implementation"),
        "original_ui_implementation": row.get("ui_implementation"),
        "current_source": anchor, "current_infrastructure": supplemental,
        "linked_core_action": action, "core_implemented_now": action in implemented if action else None,
        "destination": dest, "mapping_kind": kind,
        "context_destinations_only": contexts_for(short),
        "mapping_boundary": "Context/root availability does not prove exact selection, component focus, private state, save, or all backend/ingress combinations.",
        "tests": tests_for(row, dest),
        "cells": cells,
        "original_disposition_preserved": True,
        "acceptance": "NO_NEW_RUNTIME_ACCEPTANCE_ASSERTED; original disposition and acceptance criteria remain authoritative"
    })

source_failures = [r["id"] for r in surfaces if r["current_source"]["status"] not in {"ANCHOR_PRESENT", "LOCALIZED_ANCHOR_RECONCILED"}]
assert not source_failures, source_failures
assert {r["id"] for r in surfaces} == ids

port_path = "docs/ipad-ui-rebuild/source-provenance.json"
port_rows = json.loads(read(port_path))
ports = []
for row in port_rows:
    raw = read(row["destination"])
    ports.append({**row, "historical_record": port_path,
                  "current_source_ref": source, "current_destination_sha256": sha(raw),
                  "matches_recorded_port_bytes": sha(raw) == row["destinationSHA256"],
                  "matches_recorded_original_bytes": sha(raw) == row["sha256"],
                  "boundary": "Original reference and adaptation reason preserved; changed port bytes require current provenance review, not an unmodified-source claim."})

evidence_paths = {composition, registry_path, hanlin_path, guide_path, catalog_path, lock_path, entitlements_path, port_path,
    "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeIntents.swift",
    "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeURLHandler.swift",
    "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeDestinationIntents.swift",
    "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderIntents.swift",
    "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeIntentOutcome.swift",
    "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativePublicNavigationURLV2.swift",
    "Source/Localizable.xcstrings",
    "Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Guides/GuidedNavigation.swift"}
summary = {"source_sha": source, "upstream_observed_sha": upstream,
    "semantic_rows": len(surfaces), "unique_ids": len(ids),
    "app_git_rows": sum(r["current_source"]["storage"] == "PINNED_APP_GIT_OBJECT" for r in surfaces),
    "external_pinned_rows": sum(r["current_source"]["storage"] == "PINNED_EXTERNAL_GIT_OBJECT" for r in surfaces),
    "potential_backend_ingress_cells": len(rows) * len(backends) * len(ingresses),
    "source_anchor_statuses": dict(collections.Counter(r["current_source"]["status"] for r in surfaces)),
    "mapping_kinds": dict(collections.Counter(r["mapping_kind"] for r in surfaces)),
    "actual_registry_destinations": len(descriptors),
    "core_implemented_actions": len(implemented),
    "guide_steps": len(guide_destinations),
    "test_source_files": len(test_catalog),
    "fresh_runtime_executions_by_crosswalk": 0,
    "fresh_runtime_passes_by_crosswalk": 0,
    "original_source_port_records": len(ports),
    "unchanged_recorded_port_records": sum(x["matches_recorded_port_bytes"] for x in ports)}
report = {
    "schema_version": 2, "source_sha": source,
    "boundary": "Reproducible source/implementation/route/test crosswalk, not product acceptance. All 294 original IDs and requirements are retained. 4410 potential cells are not test executions. No original pass criteria, gates, signatures, source pins, or historical inventory files are modified.",
    "historical_inputs": {historical_path: {"sha256": sha(historical_raw), "source_sha": historical.get("source_sha"), "rows": len(rows)},
                          prior_path: {"sha256": sha(read(prior_path)), "source_sha": prior["source_sha"]}},
    "contracts_snapshot": {"file": a.contracts.name, "sha256": sha(contracts_raw), "task_count": len(contracts["tasks"])},
    "external_source_proof": {"file": a.sefaria_proof.name, "sha256": sha(sefaria_raw),
        "TorahInspectorKit": inspector_pin, "SefariaMobile": embedded_pin},
    "original_qa_contract": prior["qa_input"],
    "backends": backends, "ingresses": ingresses,
    "composition_descriptors": descriptors,
    "core_implemented_actions": implemented,
    "core_catalog_actions_not_implemented": sorted(catalog_ids - set(implemented)),
    "hanlin": {"metadata_read_actions": metadata_actions,
        "additional_current_work_read_action": "search.query only with original live read consent",
        "transport_name_mapping": hanlin_transport,
        "boundary": "Transport names do not establish advertised availability. Existing Core, backend readiness, scene ownership and current read consent decide each live invocation."},
    "guides": {"actual_app_tour_destinations": guide_destinations,
        "source": evidence(guide_path),
        "boundary": "Original runner waits for native acknowledgement before coaching. Three steps do not satisfy all 294 components or three separate multi-step model journeys."},
    "universal_links": {"associated_domains": associated_domains,
        "decoder_source": evidence("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativePublicNavigationURLV2.swift"),
        "os_https_delivery": "OPEN_NOT_EXECUTED_BY_THIS_CROSSWALK",
        "aasa_http_evidence": "Preserve prior task/CI origin+Apple-CDN200 evidence; not re-executed here."},
    "crosscutting_acceptance": {
        "settings_subsection_and_control_routes": "OPEN_ROOT_SETTINGS_IS_NOT_SPECIFIC_CONTROL",
        "exact_selection_focus_toc_and_bookmark_targets": "OPEN_EXACT_COMPONENT_MATRIX_REQUIRED",
        "original_legacy_urls": "PRESERVED_SOURCE_AND_ORIGINAL_RUNTIME_REGRESSION_REQUIRED",
        "siri_and_shortcuts_discovery": "SOURCE_DEFINITIONS_PRESENT_ACTUAL_SYSTEM_ACCEPTANCE_REQUIRED",
        "voiceover": "ORIGINAL_SPEECH_TESTS_AND_PHYSICAL_EVIDENCE_REQUIRED_NO_DOWNGRADE",
        "rtl_english_keyboard_resize_multiwindow": "ORIGINAL_CASES_RETAINED_FINAL_CANDIDATE_RUN_REQUIRED",
        "production_v40": "FINAL_PRODUCTION_ACCEPTANCE_REQUIRED_PORTABLE_OR_MINITEST10_IS_NOT_SUBSTITUTE",
        "physical_iPad_iPhone": "OWNER_RUN_NOT_PERFORMED_BY_THIS_AUDIT",
        "iOS26_original_Q_UI07_049": "ORIGINAL_REQUIREMENT_RETAINED_CURRENT_APP_TARGET27_DOES_NOT_SATISFY_IT",
        "owner_gate": "REQUIRES_AUTHENTIC_SOURCE_BOUND_ATTESTATION_FOR_NEW_PROTECTED_DELTA; NO_SIGNATURE_GENERATED"},
    "original_source_ports": ports,
    "source_evidence": {path: evidence(path) for path in sorted(evidence_paths)},
    "test_source_catalog": test_catalog,
    "summary": summary, "surfaces": surfaces}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"output": str(a.output), "sha256": sha(a.output.read_bytes()), **summary}, ensure_ascii=False))
