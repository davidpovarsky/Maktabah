#!/usr/bin/env python3
"""Verify the reviewed Release split preserves original gates/default code.

This compares actual source AST/bytes; it does not run or certify native tests.
The optional baseline directory is for a content-verified Git export off host.
"""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import subprocess


def fingerprint(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}


def tree(data):
    return ast.parse(data.decode("utf-8"))


def dump(node):
    return ast.dump(node, include_attributes=False)


def function(document, name):
    return next(node for node in document.body if isinstance(node, ast.FunctionDef) and node.name == name)


def argument(node, owner, name):
    return isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) and node.value.id == owner and node.attr == name


class RemovePreparationOnly(ast.NodeTransformer):
    def __init__(self):
        self.removed = {"global": 0, "arguments": 0, "branches": 0}

    def visit_Global(self, node):
        if node.names == ["OUT"]:
            self.removed["global"] += 1
            return None
        return node

    def visit_Expr(self, node):
        value = node.value
        if isinstance(value, ast.Call) and isinstance(value.func, ast.Attribute) and value.func.attr == "add_argument" \
                and value.args and isinstance(value.args[0], ast.Constant) \
                and value.args[0].value in {"--prepare-inputs-only", "--preparation-evidence-dir"}:
            self.removed["arguments"] += 1
            return None
        return self.generic_visit(node)

    def visit_If(self, node):
        if argument(node.test, "args", "prepare_inputs_only"):
            self.removed["branches"] += 1
            return None
        return self.generic_visit(node)


class RemoveTransferredTestOrigin(ast.NodeTransformer):
    def __init__(self):
        self.removed = {"import": 0, "initialization": 0, "validation": 0, "command": 0, "release_hid": 0}

    def visit_Import(self, node):
        if len(node.names) == 1 and node.names[0].name == "runtime27_release_handoff":
            self.removed["import"] += 1
            return None
        return node

    def visit_Assign(self, node):
        if len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and node.targets[0].id == "original_test_run" \
                and isinstance(node.value, ast.Constant) and node.value.value is None:
            self.removed["initialization"] += 1
            return None
        return self.generic_visit(node)

    def visit_If(self, node):
        if isinstance(node.test, ast.BoolOp) and isinstance(node.test.op, ast.Or) \
                and any(isinstance(value, ast.Constant) and value.value == "requires_native_hid" for value in ast.walk(node.test)):
            self.removed["release_hid"] += 1
            node.test = node.test.values[0]
        if isinstance(node.test, ast.Name) and node.test.id == "original_test_run":
            self.removed["command"] += 1
            return None
        if isinstance(node.test, ast.Call) and node.test.args and isinstance(node.test.args[0], ast.Constant) \
                and node.test.args[0].value == "FAITHFUL_RELEASE_XCTESTRUN":
            self.removed["validation"] += 1
            return None
        return self.generic_visit(node)


class RestoreFullCollection(ast.NodeTransformer):
    def visit_FunctionDef(self, node):
        node.args.kwonlyargs, node.args.kw_defaults = [], []
        return self.generic_visit(node)

    def visit_Assign(self, node):
        if isinstance(node.value, ast.IfExp) and isinstance(node.value.test, ast.Name) and node.value.test.id == "native_only":
            node.value = node.value.orelse
        return self.generic_visit(node)

    def visit_If(self, node):
        if isinstance(node.test, ast.UnaryOp) and isinstance(node.test.op, ast.Not) \
                and isinstance(node.test.operand, ast.Name) and node.test.operand.id == "native_only":
            return node.body
        if isinstance(node.test, ast.BoolOp) and isinstance(node.test.op, ast.And) \
                and isinstance(node.test.values[0], ast.Name) and node.test.values[0].id == "native_only":
            return None
        return self.generic_visit(node)


def assigned(node, name):
    return isinstance(node, ast.Assign) and len(node.targets) == 1 \
        and isinstance(node.targets[0], ast.Name) and node.targets[0].id == name


def module_body(nodes):
    return ast.Module(body=nodes, type_ignores=[])


def verify(root, baseline):
    proofs = []
    fingerprints = {}
    def check(name, result):
        if not result:
            raise ValueError("Original source preservation failed: " + name)
        proofs.append({"check": name, "status": "PASS"})
    def pair(path):
        old, raw = baseline(path), (root / path).read_bytes()
        new = raw
        if b"\r\n" in raw:
            canonical = raw.replace(b"\r\n", b"\n")
            # Accept only the exact normalization Git itself applies to this path.
            # Retain the raw Windows fingerprint instead of confusing it with LF.
            actual_blob = subprocess.check_output(["git", "hash-object", "--path", path, "--stdin"],
                                                  cwd=root, input=raw, timeout=30).decode().strip()
            if actual_blob != fingerprint(canonical)["git_blob"]:
                raise ValueError("Unreviewed source filter or line-ending transformation: " + path)
            new = canonical
        fingerprints[path] = {"before": fingerprint(old), "after": fingerprint(new),
                              "after_worktree_bytes": fingerprint(raw), "comparison": "GIT_CANONICAL_LF"}
        return old, new

    for path in ["Scripts/CI/runtime27.py", "Scripts/CI/run-faithful-production-release.py",
                 "Scripts/CI/verify-runtime27-release-gate.py", "Scripts/CI/test-runtime27-release-gate.py",
                 "Scripts/CI/runtime27-release-manifest.json", "tools/verify_xcresult_zero_skips.py"]:
        old, new = pair(path)
        check("Git-byte-identical original: " + path, old == new)

    old, new = pair("Scripts/CI/hq-stage2-focused-apple.py")
    inverse = RemovePreparationOnly()
    restored = inverse.visit(tree(new))
    check("Only explicit preparation-mode additions; all original helper/default code AST preserved",
          inverse.removed == {"global": 1, "arguments": 2, "branches": 2} and dump(restored) == dump(tree(old)))

    old, new = pair("Scripts/CI/run-faithful-ipad-matrix.py")
    inverse = RemoveTransferredTestOrigin()
    restored = inverse.visit(tree(new))
    check("Only authenticated xctestrun selection and required Release HID wiring added; every original matrix/default gate AST preserved",
          inverse.removed == {"import": 1, "initialization": 1, "validation": 1, "command": 1, "release_hid": 1}
          and dump(restored) == dump(tree(old)))

    old, new = pair("Scripts/CI/runtime27-release.py")
    original, current = tree(old), tree(new)
    check("Default full five-configuration collection AST preserved",
          dump(RestoreFullCollection().visit(copy.deepcopy(function(current, "collect_configurations"))))
          == dump(function(original, "collect_configurations")))
    prior_run = function(original, "run").body
    old_audit_start = next(i for i, node in enumerate(prior_run) if assigned(node, "build"))
    old_gate_start = next(i for i, node in enumerate(prior_run) if assigned(node, "candidate"))
    check("Original final strict gate body AST identical after extraction into complete_release",
          dump(module_body(function(current, "complete_release").body[1:]))
          == dump(module_body(prior_run[old_gate_start:])))
    old_audit = [node for node in prior_run[old_audit_start:old_gate_start] if not assigned(node, "after")]
    new_audit = function(current, "reverify_original_inputs").body[1:-1]
    check("Original actual-source auditor body AST identical after extraction",
          dump(module_body(old_audit)) == dump(module_body(new_audit)))
    current_run = copy.deepcopy(function(current, "run").body)
    current_run = current_run[:next(i for i, node in enumerate(current_run) if assigned(node, "build"))]
    trimmed = []
    for node in current_run:
        if assigned(node, "stage"):
            continue
        if isinstance(node, ast.If) and isinstance(node.test, ast.Compare) \
                and isinstance(node.test.left, ast.Name) and node.test.left.id == "stage":
            continue
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call) \
                and any(isinstance(arg, ast.Constant) and arg.value == "Unknown Release build stage" for arg in node.value.args):
            continue
        if isinstance(node, ast.For) and isinstance(node.iter, ast.List):
            node.iter.elts = [item for item in node.iter.elts if not (isinstance(item, ast.Constant) and item.value in {
                "Scripts/CI/runtime27-release-stages.py", "Scripts/CI/runtime27_release_handoff.py"})]
        trimmed.append(node)
    check("Original prototype/native/production default ordering, time budgets and guards AST identical",
          dump(module_body(trimmed)) == dump(module_body(prior_run[:old_audit_start])))

    old, new = pair(".github/workflows/sefaria-embedded-validation.yml")
    def surrounding(data):
        beginning, rest = data.split(b"  runtime27:\n", 1)
        _, ending = rest.split(b"  hq-stage2-focused:\n", 1)
        return beginning, ending
    check("All non-R27 workflow inputs, jobs, permissions and concurrency bytes unchanged", surrounding(old) == surrounding(new))
    manifest = json.loads((root / "Scripts/CI/runtime27-release-manifest.json").read_bytes())
    check("Original 5 configurations, 96 required UI and 2 separate oracles unchanged",
          len(manifest["configurations"]) == 5
          and sum(len(row["required_ui_cases"]) for row in manifest["configurations"]) == 96
          and sum(len(row.get("required_oracle_cases", [])) for row in manifest["configurations"]) == 2)
    return {"status": "SOURCE_PRESERVATION_PASS", "native_ui_executed": 0,
            "checks": proofs, "fingerprints": fingerprints}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="Exact pre-split Git commit")
    parser.add_argument("--baseline-directory", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    def baseline(path):
        return ((args.baseline_directory / path).read_bytes() if args.baseline_directory else
                subprocess.check_output(["git", "show", args.base + ":" + path], cwd=root, timeout=30))
    result = {**verify(root, baseline), "baseline": args.base}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["status", "native_ui_executed", "baseline"]}))


if __name__ == "__main__":
    main()
