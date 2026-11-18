"""Reconcile the retained UI01 inventory against an immutable actual app tree.

Documentation only. Reads Git objects, never checks out another branch, registers
routes, invokes app actions or opens a user database.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
ORIGINAL = "0b19ded4265ae0f0b6d05571b1c23b7bb3d423f8"
MAX_BYTES = 64 * 1024 * 1024
EXTENSIONS = (".swift", ".js", ".jsx", ".ts", ".tsx", ".m")


def git(*args, repo=ROOT):
    return subprocess.check_output(["git", "-C", str(repo), *args])


def original(name):
    return json.loads(git("show", ORIGINAL + ":docs/hq-ui-inventory/" + name))


def blobs(ids, repo=ROOT):
    unique = list(dict.fromkeys(ids))
    raw = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "--batch"],
        input="".join(value + "\n" for value in unique).encode(),
        capture_output=True, check=True).stdout
    if len(raw) > MAX_BYTES:
        raise ValueError("Source input exceeds bounded documentation census")
    result = {}
    offset = 0
    for value in unique:
        end = raw.index(b"\n", offset)
        identity, kind, size = raw[offset:end].split()
        if identity.decode() != value or kind != b"blob":
            raise ValueError("Missing or wrong Git object")
        offset = end + 1
        result[value] = raw[offset:offset + int(size)]
        offset += int(size) + 1
    return result


def main(source):
    if not re.fullmatch("[a-f0-9]{40}", source):
        raise ValueError("Require full immutable source SHA")
    previous = original("UI_ROUTE_COVERAGE.json")
    old_scan = original("SOURCE_SCAN.json")
    entries = {}
    for item in git("ls-tree", "-r", "-z", source).split(b"\0"):
        if not item:
            continue
        meta, path = item.decode().split("\t", 1)
        _, kind, blob = meta.split()
        if kind == "blob":
            entries[path] = blob
    local = {p: b for p, b in entries.items() if p.endswith(EXTENSIONS)
             and p.startswith(("Source/", "Vendor/SefariaMobile/Integration/"))}
    cache = blobs(local.values())
    registry_source = cache[local["Source/Otzaria/Actions/Sources/OtzariaActionCore/Registry/ActionRegistry.swift"]].decode()
    declaration = next(line for line in registry_source.splitlines() if "static let implemented:" in line)
    implemented = set(re.findall(r'"([a-zA-Z.]+)"', declaration))
    old_files = {f["path"]: f for f in old_scan["files"]}
    external = [f for f in old_scan["files"] if "git_object_path" in f]
    for dep in (old_scan["embedded_source"], old_scan["inspector_dependency"]):
        if dep is old_scan["embedded_source"]:
            actual_pin = git("rev-parse", source + ":Vendor/SefariaMobile/Upstream").decode().strip()
            assert actual_pin == dep["pin"], "Embedded pin changed; semantic review required"
        else:
            project = git("show", source + ":Maktabah.xcodeproj/project.pbxproj").decode()
            assert dep["pin"] in project, "Inspector pin changed; semantic review required"
        members = [f for f in external if f["source_revision"] == dep["pin"]]
        values = blobs([f["git_blob"] for f in members], dep["object_repository"])
        for f in members:
            raw = values[f["git_blob"]]
            assert hashlib.sha256(raw).hexdigest() == f["sha256"], f["path"]
            cache[f["git_blob"]] = raw

    rows = copy.deepcopy(previous["semantic_surfaces"])
    changes = []
    suite_paths = {r["tests"]["candidate_existing_suite"]["path"] for r in rows}
    suite_paths.add("Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift")
    suite_data = blobs([entries[p] for p in suite_paths])

    def refresh(ref):
        # Explicit semantic moves, reviewed against the current source. Never
        # replace an unresolved anchor with an arbitrary matching line.
        replacements = {
            ("Source/UI/iOS/Views/iPadLayout.swift", "Bindable(bManager.libraryViewModel).searchQuery"):
                ("Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift", "page == .library ? navigationManager.libraryViewModel.searchQuery : coordinator.contentsQuery"),
            ("Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift", '.searchable(text: $searchText, prompt: String(localized: "Search Contents"))'):
                ("Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift", ".modifier(ReaderSidebarContentsSearch(text: $searchText))"),
            ("Source/Features/Search/iOS/SearchModeView.swift", "focusBinding: $isSearchFieldFocused"):
                ("Source/ChavrusaText/Search/UI/NativeGlobalSearchField.swift", 'field.accessibilityIdentifier = "global-search-query"'),
            ("Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift", "providerID: BackendID.sefaria.rawValue"):
                ("Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift", "providerID: section.locator.backend.rawValue"),
        }
        replacement = replacements.get((ref["path"], ref["anchor"]))
        if replacement:
            ref["historical_anchor"] = {"path": ref["path"], "anchor": ref["anchor"]}
            ref["path"], ref["anchor"] = replacement
            ref["occurrence"] = 1
        path = ref["path"]
        old_blob = ref["git_blob"]
        blob = local.get(path, old_files[path]["git_blob"] if path in old_files else None)
        if path.startswith("Source/") and path not in local:
            raise ValueError("Missing current source anchor: " + path)
        raw = cache[blob]
        lines = raw.decode("utf-8-sig").splitlines()
        matches = [i for i, line in enumerate(lines, 1) if ref["anchor"] in line]
        occurrence = ref.get("occurrence", 1)
        if len(matches) < occurrence:
            raise ValueError("Unresolved semantic anchor: " + path + " " + ref["anchor"])
        line = matches[occurrence - 1]
        ref.update(line=line, source_line=lines[line - 1].strip(), git_blob=blob,
                   sha256=hashlib.sha256(raw).hexdigest(),
                   source_revision=source if path in local else ref["source_revision"],
                   storage="immutable_git_object")
        if old_blob != blob:
            changes.append({"path": path, "anchor": ref["anchor"], "old_blob": old_blob,
                            "current_blob": blob, "line": line})

    for row in rows:
        refresh(row["source"])
        suite = row["tests"]["candidate_existing_suite"]
        suite["sha256"] = hashlib.sha256(suite_data[entries[suite["path"]]]).hexdigest()
        if row.get("linked_semantic_action"):
            action = row["linked_semantic_action"]
            action.update(catalog_present=True, core_v1_implemented=action.get("id") in implemented,
                          historical_catalog_revision=previous["source_sha"],
                          note="Core is present in the current tree. A catalog implementation does not install this UI route or grant native capabilities.")
    close = copy.deepcopy(next(r for r in rows if r["id"] == "inventory.v1.search.command-palette"))
    close.update(id="inventory.v1.search.command-palette.close", screen_section_component="Visible palette Cancel action",
                 owning_view_model="Exact9401ViewerToolbar.isPresented / existing onDismiss",
                 inputs=["exactScene", "palettePresentation"], visible_state="palette and focused input removed",
                 linked_semantic_action=None, note="New real esc button uses native cancelAction. Candidate is NOT_RUN until the selected native run is accepted.")
    close["source"] = dict(path="Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift",
                           anchor='Button(action: onDismiss)', occurrence=1, git_blob=local["Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift"])
    refresh(close["source"])
    close["tests"]["candidate_existing_suite"] = {"path": "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift",
        "sha256": hashlib.sha256(suite_data[entries["Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"]]).hexdigest(),
        "relationship": "Focused actual native window/input/Inspector oracle; acceptance recorded separately by exact run", "execution": "NOT_RUN"}
    rows.append(close)
    assert len(rows) == 228 and len({r["id"] for r in rows}) == 228
    # New downstream Search controls are real source surfaces. Inventory IDs
    # are documentation, never registry entries or native receipt witnesses.
    template = next(r for r in rows if r["id"] == "inventory.v1.search.input-focus")
    seen = set()
    for path in sorted(p for p in local if p.startswith("Source/ChavrusaText/Search/UI/")):
        for line in cache[local[path]].decode("utf-8-sig").splitlines():
            match = re.search(r'accessibilityIdentifier(?:\(| = )"(global-search-[^"\\]+)"', line)
            toggle = re.search(r'Toggle\("[^"]+", isOn: \$session\.(\w+)\)', line)
            if not match and not toggle:
                continue
            stable = match[1] if match else "toggle-" + toggle[1]
            if stable in seen or stable == "global-search-query":
                continue
            seen.add(stable)
            row = copy.deepcopy(template)
            row.update(id="inventory.v1.search.native." + stable, screen_section_component=stable,
                owning_view_model="UnifiedSearchSessionController / original SearchViewModel",
                inputs=["exactScene", "backend", "currentQueryAndConfiguration"],
                visible_state="Conditional original native control or state; inspect source conditions",
                linked_semantic_action=None,
                note="Actual source control; no public route installed and no native execution inferred from inventory.")
            row["source"] = dict(path=path, anchor=line.strip(), occurrence=1, git_blob=local[path])
            refresh(row["source"])
            row["tests"]["candidate_existing_suite"] = {
                "path": "Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift",
                "sha256": hashlib.sha256(git("show", source + ":Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift")).hexdigest(),
                "relationship": "Source-specific acceptance methods; seven no-query methods retained for phase1;11 additional Search/Reader methods now selected, with exact-run acceptance separate",
                "execution": "NOT_RUN_BY_INVENTORY"}
            rows.append(row)
    assert len({r["id"] for r in rows}) == len(rows)
    assert all(set(r["backends"]) == {"otzaria", "sefaria", "sefariaEmbedded"} for r in rows)
    old_local = {p: f["git_blob"] for p, f in old_files.items() if "git_object_path" not in f}
    dispositions = copy.deepcopy(previous["file_dispositions"])
    for row in dispositions:
        if row["path"] in local:
            row.update(git_blob=local[row["path"]], sha256=hashlib.sha256(cache[local[row["path"]]]).hexdigest())
    capabilities = copy.deepcopy(previous["backend_capability_sources"])
    caveats = copy.deepcopy(previous["source_caveats"])

    def refresh_nested(value):
        if isinstance(value, dict):
            if {"path", "anchor", "git_blob"} <= value.keys():
                refresh(value)
            else:
                for item in value.values():
                    refresh_nested(item)
        elif isinstance(value, list):
            for item in value:
                refresh_nested(item)

    refresh_nested(capabilities)
    refresh_nested(caveats)
    result = dict(schema_version=1, source_sha=source, original_inventory_commit=ORIGINAL,
        original_source_sha=previous["source_sha"], thread_uuid=None, executor="Sole current owner-authorized continuation agent; no independent reviewer",
        source_task="1220542479938540", registry_registration="INVENTORY_IDS_NOT_REGISTERED; installed native.history/native.search/native.annotations currentTab, native.settings/sheet, and native.reader/currentTab restricted to the current iPad book with actual live workspace ownership; new Reader native acceptance pending",
        linked_catalog={**previous["linked_catalog"], "present_in_runtime_source": True,
                        "historical_revision": previous["source_sha"],
                        "implemented_core_ids": sorted(implemented),
                        "required_current_contract": "Original Core/UIRouting/Host with explicitly enabled public-v2 roots and same-current-work iPad Reader. Native acceptance is separate. Cross-book/newTab/phone content/component variants remain unavailable."},
        embedded_source=old_scan["embedded_source"], inspector_dependency=old_scan["inspector_dependency"],
        semantic_surfaces=rows, file_dispositions=dispositions, changed_semantic_anchors=changes,
        backend_capability_sources=capabilities, source_caveats=caveats,
        source_census={"local_code_files": len(local), "external_pinned_files_verified": len(external),
            "all_code_files_verified": len(local)+len(external),
            "added_paths": sorted(set(local)-set(old_local)), "removed_paths": sorted(set(old_local)-set(local)),
            "changed_paths": sorted(p for p in local if p in old_local and local[p] != old_local[p]),
            "current_local_file_blobs": local},
        summary={"retained_rows_reconciled": 227, "new_visible_cancel_row": 1,
                 "semantic_surfaces": len(rows), "new_native_search_surfaces": len(rows)-228,
                 "source_anchor_validation": "EXECUTED_PASS",
                 "semantic_reconciliation": "MAIN_SESSION_NO_INDEPENDENT_REVIEWER",
                 "native_route_acceptance": "NOT_RUN", "physical_ipad": "NOT_RUN"})
    (HERE/"UI01_CURRENT_HANDOFF.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    summary={**result["summary"], **{k:v for k,v in result["source_census"].items() if k != "current_local_file_blobs"},
             "changed_semantic_anchors":changes, "source_sha":source}
    (HERE/"RECONCILIATION_REPORT.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(summary,ensure_ascii=False,indent=2))


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",required=True)
    main(parser.parse_args().source)
