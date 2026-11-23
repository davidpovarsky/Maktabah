#!/usr/bin/env python3
"""Optional app-only admission of the original same-toolchain SDK distribution."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import runpy
import shutil
import stat
import subprocess
import sys
import tempfile

TARGET = "Maktabah-iOS"
BUNDLE = "com.davidpovarsky.chavrusatext"
QUALIFIED = "ACTUAL_ORIGINAL_FRAMEWORK_EXTERNAL_IMPORT_LINK_RESOURCES_PASS"

# One observed build-tool-only candidate, not a general package-pin exemption.
# Names are the union of the actual products/targets in these two Package.swift
# blobs (including test/support targets). Full derivation is retained in review.
SYNTAX_APP = "79e4b74a295b6eb74a8b585e3a39d29e70c1dbd1"
SYNTAX_SDK = "0687f71944021d616d34d922343dcef086855920"
SYNTAX_MANIFESTS = {
    SYNTAX_APP: {"git_blob": "ba92d6854a76feacd87c1083da99ad8188e21be1",
                 "sha256": "a9d82d3f7cdd7c1be7baa604173651e51f1711b190516eb9fbfe279c642eacc5"},
    SYNTAX_SDK: {"git_blob": "59e62e1f5156819aa1012276ccd228f5becb4cef",
                 "sha256": "4b8285326dcd86b30ee3e485d9b50298d2e96c043bb6cf4f485ba8890b750e3e"},
}
SYNTAX_NAMES = (
    "PerformanceTest", "SwiftBasicFormat", "SwiftBasicFormatTest", "SwiftCompilerPlugin",
    "SwiftCompilerPluginMessageHandling", "SwiftCompilerPluginTest", "SwiftDiagnostics", "SwiftDiagnosticsTest",
    "SwiftIDEUtils", "SwiftIDEUtilsTest", "SwiftIfConfig", "SwiftIfConfigTest", "SwiftLexicalLookup",
    "SwiftLexicalLookupTest", "SwiftLibraryPluginProvider", "SwiftOperators", "SwiftOperatorsTest", "SwiftParser",
    "SwiftParserDiagnostics", "SwiftParserDiagnosticsTest", "SwiftParserTest", "SwiftRefactor", "SwiftRefactorTest",
    "SwiftSyntax", "SwiftSyntax-all", "SwiftSyntax509", "SwiftSyntax510", "SwiftSyntax600", "SwiftSyntax601",
    "SwiftSyntax602", "SwiftSyntax603", "SwiftSyntaxBuilder", "SwiftSyntaxBuilderTest", "SwiftSyntaxMacroExpansion",
    "SwiftSyntaxMacroExpansionTest", "SwiftSyntaxMacros", "SwiftSyntaxMacrosGenericTestSupport",
    "SwiftSyntaxMacrosTestSupport", "SwiftSyntaxMacrosTestSupportTests", "SwiftSyntaxTest", "SwiftSyntaxTestSupportTest",
    "SwiftWarningControl", "SwiftWarningControlTest", "_InstructionCounter", "_SwiftCompilerPluginMessageHandling",
    "_SwiftLibraryPluginProvider", "_SwiftLibraryPluginProviderCShims", "_SwiftSyntaxCShims", "_SwiftSyntaxDynamic",
    "_SwiftSyntaxGenericTestSupport", "_SwiftSyntaxTestSupport",
)


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def owned_path(root, relative, *, build=False):
    require(isinstance(relative, str) and re.fullmatch(r"[A-Za-z0-9_./+-]+", relative), "Malformed SDK input path")
    parts = PurePosixPath(relative)
    require(not parts.is_absolute() and ".." not in parts.parts and parts.as_posix() == relative,
            "SDK input path is not an exact relative path")
    result = Path(root) / relative
    if build:
        require(parts.parts and parts.parts[0] == "build", "SDK artifact must be staged in owned build output")
    for parent in [result, *result.parents]:
        require(not parent.is_symlink(), "SDK input path contains a link")
        if parent == Path(root):
            break
    require(result.resolve().is_relative_to(Path(root).resolve()), "SDK input escaped the checkout")
    return result


def read_json(path, maximum=16 * 1024 * 1024):
    path = Path(path)
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= maximum,
            "Missing or oversized SDK JSON input: " + str(path))
    return json.loads(path.read_bytes())


def inventory(directory, *, metadata=False):
    """Same materialized-file closure as the original exporter; no aliases."""
    directory = Path(directory)
    require(directory.is_dir() and not directory.is_symlink(), "SDK product directory is missing or aliased")
    records = {}
    for path in [directory, *sorted(directory.rglob("*"))]:
        relative = path.relative_to(directory).as_posix()
        info = path.lstat()
        require(not stat.S_ISLNK(info.st_mode), "SDK product contains a link: " + relative)
        require(stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode), "Special SDK product member: " + relative)
        if stat.S_ISDIR(info.st_mode):
            if metadata:
                records[relative] = {"kind": "directory", "mode": stat.S_IMODE(info.st_mode)}
            continue
        row = {"bytes": info.st_size, "sha256": digest(path)}
        if metadata:
            row.update(kind="file", mode=stat.S_IMODE(info.st_mode))
        records[relative] = row
    return records


def command(argv, *, root, evidence, label, timeout=60):
    result = subprocess.run(argv, cwd=root, text=True, capture_output=True, timeout=timeout)
    write(Path(evidence) / (label + ".json"), {"command": argv, "returncode": result.returncode,
          "stdout": result.stdout, "stderr": result.stderr})
    require(result.returncode == 0, "Original SDK command failed: " + label)
    return result.stdout.strip()


def shared_package_policy(app_pins, sdk_pins):
    app = {name.lower(): revision for name, revision in app_pins.items()}
    sdk = {name.lower(): revision for name, revision in sdk_pins.items()}
    require(len(app) == len(app_pins) and len(sdk) == len(sdk_pins), "Case-aliased package identities")
    common = sorted(set(app) & set(sdk))
    different = [name for name in common if app[name] != sdk[name]]
    require(not different or (different == ["swift-syntax"] and app["swift-syntax"] == SYNTAX_APP
                             and sdk["swift-syntax"] == SYNTAX_SDK),
            "Original SDK and Maktabah resolve different revisions of a shared runtime package")
    return {"identical_revisions": [name for name in common if name not in different],
            "swift_syntax_requires_actual_runtime_absence": bool(different)}


def require_no_syntax_names(names):
    matches = sorted({module for name in names for module in SYNTAX_NAMES if module in name})
    require(not matches, "SwiftSyntax-associated runtime product or import found: " + ", ".join(matches))


def code_images(directory):
    """Enumerate real Mach-O/archive bytes, including static framework products."""
    directory = Path(directory)
    require(directory.is_dir() and not directory.is_symlink(), "Missing runtime image root")
    images = {}
    magic = {b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
             b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
    for path in sorted(directory.rglob("*")):
        require(not path.is_symlink(), "Aliased runtime image input")
        if not path.is_file():
            continue
        with path.open("rb") as stream:
            header = stream.read(8)
        if header[:4] in magic or header == b"!<arch>\n":
            images[path.relative_to(directory).as_posix()] = {"bytes": path.stat().st_size, "sha256": digest(path)}
    require(images, "No actual runtime image evidence")
    return images


def scan_binary_output(path, *, symbols):
    count, nonempty = 0, False
    with Path(path).open("rb") as stream:
        for line in stream:
            nonempty |= bool(line.strip())
            require_no_syntax_names([line.decode("utf-8", errors="replace")])
            if re.match(rb"^\s*(?:[a-fA-F0-9]+\s+)?[A-Za-z?]\s+\S+", line):
                count += 1
    require(nonempty, "Missing actual full binary-command output")
    require(not symbols or count > 0, "Missing nonempty actual full symbol-table evidence")
    return {"symbol_lines": count if symbols else None}


def binary_command(argv, *, root, evidence, label, symbols=False):
    """Retain full successful output, compressed without truncation; no mocks."""
    evidence = Path(evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    destination = evidence / (label + ".txt.gz")
    require(not destination.exists(), "Refusing stale runtime closure output")
    with tempfile.TemporaryFile() as temporary:
        result = subprocess.run(argv, cwd=root, stdout=temporary, stderr=subprocess.STDOUT, timeout=240)
        size = temporary.tell()
        require(0 < size <= 512 * 1024 * 1024, "Missing or oversized actual binary-command output")
        temporary.seek(0)
        with destination.open("xb") as saved, gzip.GzipFile(filename="", mode="wb", fileobj=saved, mtime=0) as zipped:
            shutil.copyfileobj(temporary, zipped)
    row = {"command": argv, "returncode": result.returncode, "uncompressed_bytes": size,
           "output": destination.name, "bytes": destination.stat().st_size, "sha256": digest(destination)}
    write(evidence / (label + ".json"), row)
    require(result.returncode == 0, "Actual runtime closure command failed: " + label)
    with gzip.open(destination, "rb") as zipped, tempfile.NamedTemporaryFile() as plain:
        shutil.copyfileobj(zipped, plain)
        plain.flush()
        row.update(scan_binary_output(plain.name, symbols=symbols))
    write(evidence / (label + ".json"), row)
    return row


def runtime_absence_proof(root, directory, evidence, *, reused=None):
    root, directory, evidence = Path(root), Path(directory), Path(evidence)
    require_no_syntax_names(path.relative_to(directory).as_posix() for path in directory.rglob("*"))
    images = code_images(directory)
    by_hash = {row["sha256"]: row for row in (reused or {}).get("verified_images", {}).values()}
    verified = {}
    for number, (relative, image) in enumerate(images.items()):
        previous = by_hash.get(image["sha256"])
        if previous is not None:
            require(previous["bytes"] == image["bytes"], "Runtime evidence size differs")
            verified[relative] = {**image, "reused_exact_image_proof": previous}
            continue
        binary = directory / relative
        checks = {}
        for name, options in [("symbols", ["nm", "-a"]), ("imports", ["otool", "-L"]), ("loads", ["otool", "-l"])]:
            checks[name] = binary_command([*options, str(binary)], root=root, evidence=evidence,
                                          label=f"image-{number}-{name}", symbols=name == "symbols")
        require(digest(binary) == image["sha256"], "Runtime image changed during symbol/import inspection")
        verified[relative] = {**image, "checks": checks}
    require(code_images(directory) == images, "Runtime image closure changed during inspection")
    return {"status": "ACTUAL_FULL_SYMBOL_IMPORT_AND_PRODUCT_CLOSURE_PASS", "images": images,
            "verified_images": verified, "evidence": evidence.relative_to(root).as_posix(),
            "forbidden_names": list(SYNTAX_NAMES), "native_execution": False}


def verify_absence_receipt(root, directory, proof, *, reused=None):
    require(proof.get("status") == "ACTUAL_FULL_SYMBOL_IMPORT_AND_PRODUCT_CLOSURE_PASS"
            and code_images(directory) == proof["images"], "Runtime closure proof no longer matches actual images")
    require(set(proof["verified_images"]) == set(proof["images"])
            and all({key: row[key] for key in ["bytes", "sha256"]} == proof["images"][name]
                    for name, row in proof["verified_images"].items()), "Incomplete per-image binary proof")
    require_no_syntax_names(path.relative_to(directory).as_posix() for path in Path(directory).rglob("*"))
    evidence = Path(root) / proof["evidence"]
    by_hash = {row["sha256"]: row for row in (reused or {}).get("verified_images", {}).values()}
    for row in proof["verified_images"].values():
        if "reused_exact_image_proof" in row:
            require("checks" not in row and row["reused_exact_image_proof"] == by_hash.get(row["sha256"])
                    and row["reused_exact_image_proof"] is not None,
                    "Reused runtime image lacks the original exact successful source proof")
        else:
            require(set(row.get("checks", {})) == {"symbols", "imports", "loads"}
                    and row["checks"]["symbols"].get("symbol_lines", 0) > 0,
                    "Missing symbol/import/load closure")
        for check in row.get("checks", {}).values():
            path = evidence / check["output"]
            require(path.is_file() and not path.is_symlink() and path.stat().st_size == check["bytes"]
                    and digest(path) == check["sha256"] and check["returncode"] == 0,
                    "Original full binary proof is missing or changed")


def require_compiled_host_api(qualification, *, retained_original=None):
    """Admit the original producer's compiled API proof, never editor execution."""
    public_api = "EXPOSED_COMPILED_NATIVE_EDITOR_NOT_RUN"
    probe = qualification.get("compiled_consumer_api_probe_sha256")
    public_host_api = qualification.get("public_host_api")
    if retained_original is not None:
        # The new run restores the signed consumer. Its public API proof belongs
        # to the exact successful original build, whose failed runtime is kept.
        require(qualification.get("kind") == "ORIGINAL_SIGNED_CONSUMER_RUNTIME_CONTINUATION"
                and hashlib.sha256(json.dumps(retained_original, sort_keys=True,
                    separators=(",", ":")).encode()).hexdigest()
                    == "5433db38125e3fd7827cf2694e508c44796a7b48fe532222f0f847be54f214d7"
                and retained_original.get("original_framework_build") == "PASS"
                and retained_original.get("external_consumer_build") == "PASS"
                and retained_original.get("compiled_consumer_api_probe_sha256") == probe
                and retained_original.get("actual_public_surface") == qualification.get("actual_public_surface"),
                "Retained public Host proof differs from the original compiled producer")
        public_host_api = retained_original.get("public_host_api")
    require(public_host_api == public_api
            and qualification.get("editable_mount") == "API_COMPILED_NATIVE_UI_NOT_RUN"
            and type(qualification.get("native_editor_ui_tests")) is int
            and qualification["native_editor_ui_tests"] == 0
            and isinstance(probe, str) and re.fullmatch(r"[a-f0-9]{64}", probe),
            "Original producer lacks the actual compiled Host/API prerequisite")
    surface = qualification.get("actual_public_surface", {})
    require(isinstance(surface, dict) and surface.get("status") == "ACTUAL_TARGET_PUBLIC_SURFACE_INSPECTED"
            and surface.get("target") == "AnytypeOriginalEditor"
            and type(surface.get("reviewed_host_and_spi_requirements_observed")) is int
            and surface["reviewed_host_and_spi_requirements_observed"] == 38
            and surface.get("editable_mount_api") == public_api
            and surface.get("qualification_spi_scope_verified") is True
            and surface.get("public_host_scope_verified") is True
            and surface.get("public_original_editor_or_writer_declarations") == []
            and isinstance(surface.get("own_public_symbols"), list) and len(surface["own_public_symbols"]) >= 38
            and all(isinstance(symbol, dict) and type(symbol.get("spi")) is bool
                    for symbol in surface["own_public_symbols"]),
            "Original full public/qualification-SPI verifier prerequisite is incomplete")
    return {"public_host_api": public_api, "editable_mount": qualification["editable_mount"],
            "compiled_consumer_api_probe_sha256": probe,
            "actual_public_surface": surface, "native_editor_ui_tests": 0}


def require_simulator_dynamic_architectures(architecture_output, header):
    # Preserve each authenticated framework byte, including an original universal
    # Simulator slice. The consumer needs arm64; no extra architecture is inferred
    # from a path, flag or other column in otool's output.
    architectures = architecture_output.split()
    supported = {"arm64", "x86_64"}
    require(architectures and len(architectures) == len(set(architectures))
            and "arm64" in architectures and set(architectures) <= supported,
            "Wrong or ambiguous SDK architectures")
    cpu_names = {"ARM64": "arm64", "X86_64": "x86_64"}
    header_architectures = []
    for line in header.splitlines():
        fields = line.split()
        if not fields or not fields[0].startswith("MH_"):
            continue
        require(len(fields) >= 7 and fields[0] == "MH_MAGIC_64"
                and fields[1] in cpu_names
                and re.fullmatch(r"0x[0-9a-fA-F]+", fields[3])
                and fields[4] == "DYLIB"
                and re.fullmatch(r"[0-9]+", fields[5])
                and re.fullmatch(r"[0-9]+", fields[6]),
                "Unsupported or ambiguous SDK Mach-O header")
        header_architectures.append(cpu_names[fields[1]])
    require(header_architectures
            and len(header_architectures) == len(set(header_architectures))
            and set(header_architectures) == set(architectures),
            "SDK architecture and actual DYLIB CPU headers differ")
    return tuple(sorted(architectures))


def admit(root, admission_path, evidence, *, swift=None, sdk=None):
    root, admission_path, evidence = Path(root).resolve(), Path(admission_path), Path(evidence)
    relative = admission_path.relative_to(root).as_posix() if admission_path.is_absolute() else admission_path.as_posix()
    admission_path = owned_path(root, relative)
    require(relative.startswith("Scripts/CI/") and relative.endswith(".json"), "SDK admission must be a reviewed CI input")
    committed = subprocess.check_output(["git", "show", "HEAD:" + relative], cwd=root)
    require(committed == admission_path.read_bytes(), "SDK admission bytes differ from the reviewed checkout")
    config = read_json(admission_path)
    require(config.get("schema") in {1, 2} and config.get("repository") == "davidpovarsky/anytype-swift",
            "Wrong original SDK admission schema/repository")
    continuation = None
    if config["schema"] == 2:
        continuation = runpy.run_path(str(owned_path(root, "Scripts/CI/original_editor_continuation_admission.py")))
        continuation["validate_configuration"](config)
        continuation["validate_paths"](root, config, globals())
    require(re.fullmatch(r"[a-f0-9]{40}", config.get("source_sha", "")), "Unfinalized original SDK source")
    require(all(type(config.get(k)) is int and config[k] > 0 for k in ["run_id", "run_attempt", "artifact_id", "archive_bytes"]),
            "Missing immutable original SDK run/artifact identity")
    for key in ["archive_sha256", "distribution_manifest_sha256", "qualification_sha256", "original_source_sha256", "hanlin_source_sha256"]:
        require(re.fullmatch(r"[a-f0-9]{64}", config.get(key, "")), "Unfinalized SDK digest: " + key)
    archive = owned_path(root, config["archive_path"], build=True)
    require(archive.is_file() and archive.stat().st_size == config["archive_bytes"]
            and digest(archive) == config["archive_sha256"], "Original SDK archive identity differs")
    distribution = owned_path(root, config["distribution_root"], build=True)
    manifest_path = owned_path(root, config["distribution_manifest_path"], build=True)
    hanlin_source_path = owned_path(root, config["hanlin_source_path"], build=True)
    require(digest(manifest_path) == config["distribution_manifest_sha256"], "Original export manifest differs")
    require(digest(hanlin_source_path) == config["hanlin_source_sha256"], "Original compiled Hanlin snapshot receipt differs")
    qualification_path = owned_path(root, config["qualification_path"], build=True) if continuation else distribution / "QUALIFICATION.json"
    source_path = distribution / "SourceProvenance/OriginalSource.json"
    require(digest(qualification_path) == config["qualification_sha256"]
            and digest(source_path) == config["original_source_sha256"], "SDK qualification/source receipt differs")
    qualification, provenance, exported = read_json(qualification_path), read_json(source_path), read_json(manifest_path)
    if continuation:
        continuation_receipt = continuation["validate_qualification"](config, qualification)
    else:
        require(qualification.get("status") == QUALIFIED and qualification.get("phase") == "COMPLETE"
                and qualification.get("original_framework_build") == "PASS"
                and qualification.get("external_consumer_build") == "PASS"
                and qualification.get("same_toolchain_only") is True,
                "SDK lacks the original framework/external consumer prerequisites")
    compiled_host_api = (continuation["compiled_host_receipt"](root, config, qualification, globals())
                         if continuation else require_compiled_host_api(qualification))
    if continuation:
        require(provenance.get("application_source") == config["source_sha"]
                and provenance.get("original_trees") == config["framework_producer"]["source_trees"],
                "Original framework provenance changed in continuation")
    else:
        require(qualification.get("source_sha") == provenance.get("application_source") == config["source_sha"]
                and str(qualification.get("run_id")) == str(config["run_id"])
                and str(qualification.get("run_attempt")) == str(config["run_attempt"]), "SDK source/run receipt drift")
    observations = qualification.get("verified_runtime_observations", [])
    require(len(observations) == 2 and {row.get("language") for row in observations} == {"en", "he"}
            and all(row.get("status") == "ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS" for row in observations),
            "Original en/he external resource observations are incomplete")
    if swift is not None:
        require(qualification.get("swift") == swift, "Original SDK requires the same actual Swift toolchain")
    if sdk is not None:
        require(qualification.get("sdk") == sdk and sdk.split(".")[0] == "27", "Original SDK simulator version differs")
    actual = inventory(distribution)
    expected = dict(exported["files"])
    require("QUALIFICATION.json" not in expected, "Unexpected circular original qualification inventory")
    if not continuation:
        expected["QUALIFICATION.json"] = {"bytes": qualification_path.stat().st_size, "sha256": config["qualification_sha256"]}
    require(actual == expected, "Actual SDK distribution differs from the original export closure")
    frameworks = sorted(p.name for p in (distribution / "Frameworks").iterdir())
    bundles = sorted(p.name for p in (distribution / "Bundles").iterdir())
    require(frameworks == exported["frameworks"] and bundles == exported["resource_bundles"],
            "Original SDK product membership differs")
    require(all(re.fullmatch(r"[A-Za-z0-9_.+-]+\.framework", name) for name in frameworks)
            and all(re.fullmatch(r"[A-Za-z0-9_.+-]+\.bundle", name) for name in bundles), "Malformed original product name")
    dynamic = []
    for index, name in enumerate(frameworks):
        framework = distribution / "Frameworks" / name
        info = plistlib.loads((framework / "Info.plist").read_bytes())
        executable = info.get("CFBundleExecutable", "")
        require(isinstance(executable, str) and executable not in {".", ".."}
                and re.fullmatch(r"[A-Za-z0-9_.+-]+", executable), "Invalid original framework executable")
        binary = framework / executable
        header = command(["otool", "-hv", str(binary)], root=root, evidence=evidence, label="sdk-header-" + str(index))
        if re.search(r"\bDYLIB\b", header):
            dynamic.append(name)
            command(["codesign", "--verify", "--strict", str(framework)], root=root, evidence=evidence, label="sdk-signature-" + str(index))
            require_simulator_dynamic_architectures(
                command(["lipo", "-archs", str(binary)], root=root, evidence=evidence,
                        label="sdk-architecture-" + str(index)), header)
            platform = command(["xcrun", "vtool", "-show-build", str(binary)], root=root, evidence=evidence,
                               label="sdk-platform-" + str(index))
            require(re.search(r"platform\s+IOSSIMULATOR\b", platform), "Non-Simulator SDK dependency")
    require("AnytypeOriginalEditor.framework" in dynamic, "No actual original editor dynamic framework")
    result = {"admission_path": relative, "admission_sha256": digest(admission_path), "source_sha": config["source_sha"],
              "run_id": config["run_id"], "run_attempt": config["run_attempt"], "artifact_id": config["artifact_id"],
              "archive_sha256": config["archive_sha256"], "distribution_root": config["distribution_root"],
              "distribution_files": actual, "dynamic_frameworks": dynamic, "resource_bundles": bundles,
              "shared_package_revisions": provenance["dependencies"]["actual_checkout_revisions"],
              "original_package_lock_sha256": digest(distribution / "SourceProvenance/Original-Package.resolved"),
              "hanlin_source": read_json(hanlin_source_path),
              "compiled_host_api": compiled_host_api,
              "native_editor_ui_tests": 0, "scope": "ORIGINAL_DISTRIBUTION_PREREQUISITES_ONLY"}
    if continuation:
        result.update(schema=2, **continuation_receipt)
        clang = runpy.run_path(str(owned_path(root, "Scripts/CI/original_editor_clang_imports.py")))
        identity = {"source_sha": config["source_sha"], "run_id": str(config["run_id"]),
                    "run_attempt": str(config["run_attempt"]),
                    "original_package_lock_sha256": result["original_package_lock_sha256"],
                    "manifest_sha256": config["framework_producer"]["clang_manifest_sha256"]}
        result["clang_import_context"] = clang["admitted_context"](distribution, identity)
    write(evidence / "distribution-admission.json", result)
    return result


def require_unchanged(root, admitted):
    root = Path(root)
    require(digest(root / admitted["admission_path"]) == admitted["admission_sha256"], "SDK admission changed during build")
    require(inventory(root / admitted["distribution_root"]) == admitted["distribution_files"], "SDK distribution changed during build")
    if admitted.get("schema") == 2:
        sidecar = owned_path(root, admitted["qualification_path"], build=True)
        require(not sidecar.is_relative_to(owned_path(root, admitted["distribution_root"], build=True))
                and digest(sidecar) == admitted["qualification_sha256"], "Separate runtime qualification changed during build")


def compare_or_copy(source, target):
    source, target = Path(source), Path(target)
    expected = inventory(source, metadata=True)
    require(not target.is_symlink() and not any(p.is_symlink() for p in target.parents),
            "Refusing aliased app product destination")
    if target.exists():
        require(inventory(target, metadata=True) == expected, "Existing app product differs; no overwrite: " + target.name)
        return "REUSED_IDENTICAL"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target, copy_function=shutil.copy2, symlinks=False)
    require(inventory(target, metadata=True) == expected, "Copied SDK product identity differs: " + target.name)
    return "COPIED_MISSING"


def app_bundle(root, path):
    path = Path(path)
    require(path.is_dir() and not path.is_symlink() and path.name == "Maktabah.app"
            and path.resolve().is_relative_to((Path(root) / "build").resolve()), "Unowned Maktabah build product")
    for parent in path.parents:
        require(not parent.is_symlink(), "Aliased app product parent")
        if parent == Path(root):
            break
    return path


def embed(root, admission_receipt, receipt_sha256, target, evidence):
    require(os.environ.get("TARGET_NAME") == TARGET and os.environ.get("CONFIGURATION") == "Debug"
            and os.environ.get("PLATFORM_NAME") == "iphonesimulator"
            and os.environ.get("PRODUCT_BUNDLE_IDENTIFIER") == BUNDLE,
            "Original SDK embed is restricted to the real Maktabah Debug Simulator app")
    root, evidence = Path(root), Path(evidence)
    require(re.fullmatch(r"[a-f0-9]{64}", receipt_sha256) and digest(admission_receipt) == receipt_sha256,
            "Original SDK admission receipt changed after app-target preparation")
    admitted = read_json(admission_receipt)
    require_unchanged(root, admitted)
    target = app_bundle(root, target)
    distribution = root / admitted["distribution_root"]
    receipts = []
    for kind, names in [("Frameworks", admitted["dynamic_frameworks"]), ("Bundles", admitted["resource_bundles"])]:
        for name in names:
            source = distribution / kind / name
            destination = target / "Frameworks" / name if kind == "Frameworks" else target / name
            result = compare_or_copy(source, destination)
            receipts.append({"kind": kind, "name": name, "disposition": result,
                             "files": inventory(destination, metadata=True)})
    require_unchanged(root, admitted)
    write(evidence / "app-embedding.json", {"status": "EXACT_PRODUCTS_PRESENT", "target": str(target),
          "products": receipts, "overwritten_products": 0, "codesign_on_copy": False, "remove_headers_on_copy": False})


def prepare(root, admission_path, report, out, logged):
    root, out = Path(root), Path(out)
    evidence = out / "original-editor"
    evidence.mkdir(parents=True, exist_ok=True)
    admitted = admit(root, admission_path, evidence, swift=report["swift"], sdk=report["sdk_version"])
    if admitted.get("schema") == 2:
        require(report.get("xcode") == admitted["framework_producer"]["toolchain"]["xcode"],
                "Maktabah Xcode differs from the original framework and continuation")
    policy = shared_package_policy(report["package_pins"], admitted["shared_package_revisions"])
    admitted["shared_package_policy"] = policy
    distribution = root / admitted["distribution_root"]
    if policy["swift_syntax_requires_actual_runtime_absence"]:
        manifest = root / "build/SourcePackages/checkouts/swift-syntax/Package.swift"
        require(digest(manifest) == SYNTAX_MANIFESTS[SYNTAX_APP]["sha256"],
                "Actual SwiftSyntax build-tool manifest differs from the reviewed pair")
        policy.update(reviewed_manifests=SYNTAX_MANIFESTS,
                      original_sdk_lock_sha256=admitted["original_package_lock_sha256"],
                      maktabah_lock_sha256=digest(root / "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"),
                      original_macro_authorization=report["compiler_macro_authorization"],
                      producer_runtime_absence=runtime_absence_proof(root, distribution, evidence / "swift-syntax-sdk"),
                      consumer_runtime_absence_required=True)
    # The framework contains the original Hanlin modules. Equality of a remote
    # swift-ai-sdk pin alone cannot prove equality of these local SDK sources.
    compiled = lambda name: (name.startswith(("Packages/HanlinAgentSDK/", "Packages/HanlinPlatform/",
                                             "Packages/HanlinPresentationSDK/"))
                             and ("/Sources/" in name or name.endswith("/Package.swift")))
    app_hanlin = {name for name in report["hanlin_sdk_source"]["git_blobs"] if compiled(name)}
    sdk_hanlin = {name: value for name, value in admitted["hanlin_source"]["files"].items() if compiled(name)}
    require(app_hanlin == sdk_hanlin.keys(), "Original SDK and Maktabah have different Hanlin source membership")
    require(all(digest(root / "Vendor/HanlinSDK" / name) == value for name, value in sdk_hanlin.items()),
            "Original SDK and Maktabah compile different shared Hanlin bytes")
    admitted["shared_hanlin_source_verified"] = {"files": len(app_hanlin),
        "maktabah_revision": report["hanlin_sdk_source"]["sha"], "framework_revision": admitted["hanlin_source"]["revision"],
        "comparison": "EXACT_PACKAGE_MANIFEST_AND_COMPLETE_SOURCES_RESOURCE_BYTES"}
    write(evidence / "distribution-admission.json", admitted)
    # This is an actual compiler import of the exported binary API. A guarded
    # application source file cannot turn a missing framework into acceptance.
    distribution = root / admitted["distribution_root"]
    api_source = root / "Scripts/CI/OriginalEditorDistributionAPICheck.swift"
    api_command = ["xcrun", "swiftc", "-typecheck", "-parse-as-library", "-swift-version", "6", "-D", "DEBUG",
            "-sdk", report["sdk_path"], "-target", "arm64-apple-ios" + report["sdk_version"] + "-simulator",
            "-F", str(distribution / "Frameworks"), "-I", str(distribution / "Modules")]
    if admitted.get("schema") == 2:
        clang = runpy.run_path(str(owned_path(root, "Scripts/CI/original_editor_clang_imports.py")))
        api_command += clang["swift_import_arguments"](distribution, admitted["clang_import_context"])
    else:
        api_command += ["-I", str(distribution / "Include")]
    api_command.append(str(api_source))
    report.setdefault("commands", []).append(api_command)
    command(api_command, root=root, evidence=evidence, label="exported-api-typecheck", timeout=600)
    write(evidence / "actual-exported-api.json", {"status": "ACTUAL_EXPORTED_API_TYPECHECK_PASS",
          "api_probe_sha256": digest(api_source), "source_sha": admitted["source_sha"],
          "native_execution": False, "scope": "EXPORTED_SPI_AND_HOST_COMPILER_ADMISSION_ONLY"})
    project = root / "Maktabah.xcodeproj/project.pbxproj"
    plan = {"target": TARGET, "bundle": BUNDLE, "distribution_root": admitted["distribution_root"],
            "dynamic_frameworks": admitted["dynamic_frameworks"], "source_sha": admitted["source_sha"],
            "evidence": evidence.relative_to(root).as_posix(), "before_project_sha256": digest(project),
            "receipt_sha256": digest(evidence / "distribution-admission.json"), "python": sys.executable}
    if admitted.get("schema") == 2:
        plan.update(admission_schema=2, clang_import_context=admitted["clang_import_context"])
    write(evidence / "app-target-plan.json", plan)
    logged(["ruby", "Scripts/CI/hq-original-editor-app-target.rb", str(project),
            str(evidence / "app-target-plan.json"), str(evidence / "app-target-configuration.json")],
           "original-editor-app-target.log", report)
    receipt = read_json(evidence / "app-target-configuration.json")
    require(receipt["before_project_sha256"] == plan["before_project_sha256"]
            and receipt["after_project_sha256"] == digest(project)
            and receipt["all_other_objects_unchanged"] is True,
            "Original SDK integration changed an unrelated Xcode target")
    report["original_editor_distribution"] = admitted
    report["native_context"]["pre_original_editor_project_sha256"] = plan["before_project_sha256"]
    report["native_context"]["generated_project_sha256"] = digest(project)
    shutil.copyfile(project, evidence / "generated-Maktabah-project.pbxproj")
    return admitted


def verify_built_app(root, admitted, app, evidence, *, after_ui=False):
    root, evidence = Path(root), Path(evidence)
    app = app_bundle(root, app)
    require_unchanged(root, admitted)
    embedding = read_json(evidence / "app-embedding.json")
    require(embedding["status"] == "EXACT_PRODUCTS_PRESENT" and Path(embedding["target"]) == app,
            "Original app embed phase did not execute")
    distribution = root / admitted["distribution_root"]
    prefix = "after-ui-" if after_ui else ""
    for index, name in enumerate(admitted["dynamic_frameworks"]):
        target = app / "Frameworks" / name
        require(inventory(target, metadata=True) == inventory(distribution / "Frameworks" / name, metadata=True),
                "Embedded original framework changed: " + name)
        command(["codesign", "--verify", "--strict", str(target)], root=root, evidence=evidence,
                label=prefix + "embedded-sdk-signature-" + str(index))
    for name in admitted["resource_bundles"]:
        require(inventory(app / name, metadata=True) == inventory(distribution / "Bundles" / name, metadata=True),
                "Embedded original resource bundle changed: " + name)
    command(["codesign", "--verify", "--strict", str(app)], root=root, evidence=evidence, label=prefix + "actual-app-signature")
    policy = admitted["shared_package_policy"]
    if policy["swift_syntax_requires_actual_runtime_absence"]:
        sdk_proof = policy["producer_runtime_absence"]
        verify_absence_receipt(root, distribution, sdk_proof)
        # This directory is Simulator-only; the original macOS macro targets
        # and their separately verified pins/authorization remain untouched.
        require(app.parent.name == "Debug-iphonesimulator", "Wrong actual Simulator product directory")
        require_no_syntax_names(path.relative_to(app.parent).as_posix() for path in app.parent.rglob("*"))
        if after_ui:
            verify_absence_receipt(root, app, admitted["consumer_runtime_absence"], reused=sdk_proof)
        else:
            admitted["consumer_runtime_absence"] = runtime_absence_proof(
                root, app, evidence / "swift-syntax-app", reused=sdk_proof)
        write(evidence / (prefix + "swift-syntax-runtime-absence.json"), {
            "status": "EXACT_REVIEWED_BUILD_TOOL_PAIR_WITH_ACTUAL_RUNTIME_ABSENCE",
            "maktabah_revision": SYNTAX_APP, "sdk_revision": SYNTAX_SDK,
            "sdk": sdk_proof, "app": admitted["consumer_runtime_absence"],
            "new_native_execution": False, "lock_or_macro_inputs_changed": False})
    write(evidence / (prefix + "built-app-distribution-verification.json"), {"status": "EXACT_ORIGINAL_DISTRIBUTION_EMBEDDED",
          "dynamic_frameworks": admitted["dynamic_frameworks"], "resource_bundles": admitted["resource_bundles"],
          "native_editor_ui_tests": 0, "production_or_device_qualification": False})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("command", choices=["embed"])
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--receipt-sha256", required=True)
    parser.add_argument("--app", required=True)
    parser.add_argument("--evidence", required=True)
    args = parser.parse_args()
    checkout = Path(__file__).resolve().parents[2]
    embed(checkout, owned_path(checkout, args.receipt, build=True), args.receipt_sha256, Path(args.app),
          owned_path(checkout, args.evidence, build=True))
