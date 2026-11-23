import ast
import hashlib
import json
from pathlib import Path
import re
import sys
import traceback

root = Path(sys.argv[1]).resolve()
packet = Path(__file__).resolve().parent
source_path = root / "Scripts/CI/hq-original-editor-distribution.py"
raw = source_path.read_bytes()
source = raw.decode()
tree = ast.parse(source)
lines = source.splitlines(True)
segments = {}
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name in {"require", "require_simulator_dynamic_architectures"}:
        segments[node.name] = "".join(lines[node.lineno - 1:node.end_lineno])
assert len(segments) == 2
namespace = {"re": re}
exec(compile("\n\n".join(segments.values()), str(source_path), "exec"), namespace)
check = namespace["require_simulator_dynamic_architectures"]
fixtures = packet / "fixtures"
fat_arch_record = json.loads((fixtures / "sdk-architecture-0.json").read_text())
fat_header_record = json.loads((fixtures / "sdk-header-0.json").read_text())
fat_arch = fat_arch_record["stdout"].strip()
fat_header = fat_header_record["stdout"]
thin_arch = (fixtures / "framework-architecture.stdout.log").read_text().strip()
thin_header = (fixtures / "framework-header-3.stdout.log").read_text()
assert fat_arch_record["returncode"] == fat_header_record["returncode"] == 0
assert fat_arch_record["stderr"] == fat_header_record["stderr"] == ""
assert thin_arch == "arm64"
assert fat_arch == "x86_64 arm64"

assertions = 0

def expect(value):
    global assertions
    assertions += 1
    if not value:
        raise AssertionError("control assertion failed")

def reject(architectures, header):
    try:
        check(architectures, header)
    except RuntimeError:
        expect(True)
        return
    expect(False)

def actual_qualified_universal_sdk():
    # Replay the exact former comparison over the actual captured command output.
    expect((fat_arch == "arm64") is False)
    expect(check(fat_arch, fat_header) == ("arm64", "x86_64"))
    original = (fixtures / "framework-header-0.stdout.log").read_text()
    expect(check(fat_arch, original) == ("arm64", "x86_64"))

def actual_qualified_thin_original_framework():
    expect((thin_arch == "arm64") is True)
    expect(check(thin_arch, thin_header) == ("arm64",))

def missing_or_empty_required_arm64():
    for value in ["", " \n", "x86_64"]:
        reject(value, fat_header)

def duplicate_or_unsupported_architectures():
    for value in ["arm64 arm64", "arm64 x86_64 x86_64", "arm64 arm64e", "arm64 ppc"]:
        reject(value, fat_header)

def exact_cpu_column_correspondence():
    reject("arm64", fat_header)
    reject("arm64 x86_64", thin_header)
    reject("arm64", thin_header.replace("    ARM64", "   X86_64"))
    # Tokens in paths/header labels cannot confer an absent CPU slice.
    unrelated = "/ARM64/X86_64/DYLIB/path:\nmagic ARM64 unrelated X86_64\n"
    reject("arm64", unrelated)
    expect(check("arm64", unrelated + thin_header) == ("arm64",))
    reject("arm64", thin_header.replace("    ARM64", "  ARM64_32"))

def malformed_or_mixed_dylib_headers():
    reject("arm64", "")
    reject("arm64", thin_header + thin_header)
    reject("arm64", thin_header.replace("DYLIB", "OBJECT"))
    reject("arm64", thin_header + "MH_MAGIC_64 ARM64 ALL 0x00 OBJECT 3 200\n")
    reject("arm64", thin_header.replace("MH_MAGIC_64", "MH_MAGIC"))
    reject("arm64", "MH_MAGIC_64 ARM64 ALL 0x00 DYLIB not_numeric 300\n")

cases = [actual_qualified_universal_sdk, actual_qualified_thin_original_framework,
         missing_or_empty_required_arm64, duplicate_or_unsupported_architectures,
         exact_cpu_column_correspondence, malformed_or_mixed_dylib_headers]
results = []
for case in cases:
    before = assertions
    try:
        case()
        results.append({"name": case.__name__, "status": "PASS", "assertions": assertions - before})
    except Exception as error:
        results.append({"name": case.__name__, "status": "FAIL", "assertions": assertions - before,
                        "error": str(error), "traceback": traceback.format_exc()})
receipt = {"status": "PASS" if all(row["status"] == "PASS" for row in results) else "FAIL",
           "required_cases": 6, "actual_cases": len(results), "passed": sum(row["status"] == "PASS" for row in results),
           "assertions": assertions, "cases": results,
           "source_sha256": hashlib.sha256(raw).hexdigest(),
           "exact_extracted_functions": {name: hashlib.sha256(value.encode()).hexdigest() for name, value in segments.items()},
           "old_predicate_rejects_actual_qualified_universal_output": fat_arch != "arm64",
           "apple_commands_executed": 0, "native_runtime_tests_executed": 0,
           "scope": "six focused source controls over authentic retained captures and explicit adverse inputs"}
(packet / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt))
sys.exit(0 if receipt["status"] == "PASS" else 1)
