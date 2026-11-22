"""Validate the already captured exact Git blobs; no repository mutation."""
import hashlib
import json
import re
import tomllib
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlparse

import yaml

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "sources" / "otzaria-completion-20261121"
refs = json.loads((ROOT / "REFS_AND_BLOBS.json").read_text())
current = refs["refs"][1]
parallel = refs["refs"][2]
original = refs["refs"][3]
assert current["files"] == parallel["files"]

results = []
def check(name, condition, **data):
    results.append({"check": name, "passed": bool(condition), **data})

for path, record in current["files"].items():
    b = (SOURCE / path).read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(b)).encode() + b"\0" + b).hexdigest()
    check("captured_exact_current_blob", blob == record["blob"], path=path, blob=blob)

roles = ["eitan", "noam", "maya", "roni", "tomer", "yael", "dana"]
frontmatter = []
for directory in [".agents/agents", ".agents/rules", ".agents/skills"]:
    for p in sorted((SOURCE / directory).rglob("*.md")):
        text = p.read_text()
        match = re.match(r"\A---\s*\n(.*?)\n---(?:\n|$)", text, re.S)
        check("yaml_frontmatter_present", match is not None, path=p.relative_to(SOURCE).as_posix())
        if match is None:
            continue
        try:
            metadata = yaml.safe_load(match.group(1))
            valid = isinstance(metadata, dict)
        except yaml.YAMLError as error:
            metadata = {"parse_error": str(error)}
            valid = False
        check("yaml_parse", valid, path=p.relative_to(SOURCE).as_posix(), metadata=metadata)
        if valid and "/rules/" in p.as_posix():
            check("router_trigger_and_size", metadata.get("trigger") in {"always_on", "model_decision", "glob", "manual"} and p.stat().st_size <= 24576, path=p.relative_to(SOURCE).as_posix(), bytes=p.stat().st_size)
        if valid and p.relative_to(SOURCE).as_posix().startswith(".agents/agents/"):
            check("agent_metadata_identity", metadata.get("name") == p.stem and metadata.get("mainAgent") is True and metadata.get("subagent") is True and metadata.get("model") == "inherit", path=p.relative_to(SOURCE).as_posix())
        frontmatter.append(p.relative_to(SOURCE).as_posix())
check("exact_nine_frontmatter_documents", len(frontmatter) == 9, count=len(frontmatter))

for role in roles:
    p = SOURCE / ".codex/agents" / (role + ".toml")
    try:
        metadata = tomllib.loads(p.read_text())
        valid = True
    except tomllib.TOMLDecodeError as error:
        metadata = {"parse_error": str(error)}
        valid = False
    check("toml_parse", valid, path=p.relative_to(SOURCE).as_posix())
    check("logical_role_correspondence", valid and metadata.get("name") == role and (SOURCE / ".agents/roles" / (role + ".md")).is_file() and (SOURCE / ".agents/agents" / (role + ".md")).is_file() and f".agents/roles/{role}.md" in metadata.get("developer_instructions", ""), role=role)

required = ["AGENTS.md", "GEMINI.md", ".agents/rules/ai-team-router.md", ".agents/skills/asana-team-coordination/SKILL.md", "docs/ai-team/TEAM.md", "docs/ai-team/PROJECT_ASSIGNMENTS.md", "docs/ai-team/ASANA_POLICY.md", "docs/ai-team/TASK_HANDOFF_TEMPLATE.md", "docs/ai-team/PLATFORMS.md", "docs/ai-team/BRANCH_INTEGRATION.md", "docs/ai-team/VALIDATION.md"]
for role in roles:
    required += [f".agents/agents/{role}.md", f".agents/roles/{role}.md", f".codex/agents/{role}.toml"]
check("original_ensure_team_required_presence", len(required) == 32 and all(p in current["files"] for p in required), required_count=len(required))

def normalize(path):
    parts = []
    for part in PurePosixPath(path).parts:
        if part == ".": continue
        if part == "..":
            if not parts: return None
            parts.pop()
        else: parts.append(part)
    return "/".join(parts)

links = []
for p in sorted(SOURCE.rglob("*.md")):
    rel = p.relative_to(SOURCE).as_posix()
    # Only original 33-file package plus separately read CLAUDE; large supporting policy documents are reviewed separately.
    if rel not in current["files"]: continue
    for match in re.finditer(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", p.read_text()):
        target = match.group(1).strip().split(" ", 1)[0].strip("<>")
        parsed = urlparse(target)
        if parsed.scheme or target.startswith("#"):
            continue
        decoded = unquote(parsed.path)
        resolved = normalize((PurePosixPath(rel).parent / decoded).as_posix())
        root_target = normalize(decoded)
        links.append({"source": rel, "line": p.read_text()[:match.start()].count("\n") + 1, "target": target, "markdown_relative_target": resolved, "root_interpretation_target": root_target})

references = set(required + ["PROJECT_AGENT_GUIDANCE.md", "PROJECT_BOARD.md", "DESIGN_LANGUAGE.md", "docs/architecture/UPSTREAM_INTEGRITY_POLICY.md"])
for link in links:
    if link["markdown_relative_target"]: references.add(link["markdown_relative_target"])
    if link["root_interpretation_target"]: references.add(link["root_interpretation_target"])

report = {
    "status": "LOCAL_STATIC_PARSERS_AND_IDENTITY_CHECKS_COMPLETED_LINK_TARGET_TREE_READ_PENDING",
    "source": current["sha"], "same_configuration_on": parallel["sha"],
    "yaml_frontmatter_documents": len(frontmatter), "toml_documents": len(roles),
    "yaml_parser": {"name": "PyYAML", "version": yaml.__version__},
    "toml_parser": "Python stdlib tomllib", "checks": results,
    "all_current_checks_passed": all(row["passed"] for row in results),
    "markdown_links": links, "remote_target_paths_to_check": sorted(references),
    "runtime_or_native_tests": 0, "repo_mutations": 0
}
(ROOT / "STATIC_CONFIG_VALIDATION.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"checks": len(results), "all_current_checks_passed": report["all_current_checks_passed"], "yaml_documents": len(frontmatter), "toml_documents": len(roles), "markdown_links": links}, ensure_ascii=False))
