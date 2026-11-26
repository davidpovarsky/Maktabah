#!/usr/bin/env python3
"""Render the retained requirements, without converting source evidence into acceptance."""
import collections
import json
from pathlib import Path

root = Path(__file__).resolve().parent
r = json.loads((root / "CURRENT_CROSSWALK.json").read_text())
table = ["# All 294 retained UI requirements", "",
    "Source/route/test index at " + r["source_sha"] + ". This table is source accounting, not runtime acceptance. Complete original criteria and relationships remain in CURRENT_CROSSWALK.json.", "",
    "| ID | Original component | Pinned source | Route relationship | Original public-intent suitability |",
    "|---|---|---|---|---|"]
facets = []

def cell(value):
    return str(value).replace("|", " / ").replace("\n", " ")

for row in r["surfaces"]:
    s, c = row["current_source"], row["original_contract"]
    line = (s.get("current_matching_lines") or s.get("matching_lines") or ["?"])[0]
    table.append("| " + " | ".join(map(cell, [
        row["id"], row["label"],
        s["path"] + ":" + str(line) + " @ " + s["source_ref"][:12],
        row["mapping_kind"] + "; " + str(row.get("destination")),
        c["suitability"]["app_intent"]])) + " |")
    facets.append({
        "id": row["id"], "area": row["area"],
        "original_status": c["status"],
        "original_app_intent_suitability": c["suitability"]["app_intent"],
        "original_mutation_rule": c["suitability"]["mutations"],
        "original_private_payload": c["suitability"]["private_payload"],
        "current_mapping_relationship": row["mapping_kind"],
        "current_destination": row.get("destination"),
        "containing_context_only": row["context_destinations_only"],
        "meaning": "Original exposure/disposition facets retained; not a new unsupported label or waiver of component/state requirements."
    })
out = {
    "source_sha": r["source_sha"],
    "boundary": "All original facets preserved verbatim. A source anchor or root-context route does not close UI03-07. Neither public-API inappropriateness nor original unavailable status waives native UI/guide/state requirements.",
    "original_status_counts": dict(collections.Counter(x["original_status"] for x in facets)),
    "original_intent_suitability_counts": dict(collections.Counter(x["original_app_intent_suitability"] for x in facets)),
    "rows": facets
}
assert len(facets) == len({x["id"] for x in facets}) == 294
for name, body in [
    ("COMPONENTS.md", "\n".join(table) + "\n"),
    ("REQUIREMENT_FACETS.json", json.dumps(out, ensure_ascii=False, indent=2) + "\n")
]:
    path = root / name
    if path.exists():
        raise SystemExit("Preserve evidence: " + name + " already exists")
    path.write_text(body)
print(json.dumps({"table_rows": len(facets), "facets": out["original_status_counts"]}))
