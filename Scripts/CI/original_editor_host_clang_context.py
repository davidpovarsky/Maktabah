"""Compose an admitted SDK's Clang declarations with the real host build.

The original export and its 19-map admission remain immutable. A shared SwiftPM
module may use the host's map only after every exported declaration in that
include root matches byte for byte. CocoaPods name collisions are reported;
they are never silently resolved by choosing one unrelated binary version.
"""
from pathlib import Path
import hashlib
import re

# These are the shared package modules from the actual Stage B compiler command.
SHARED_PACKAGES = {
    "Clang/Packages/swift-cmark/src/include/module.modulemap": "swift-cmark",
    "Clang/Packages/swift-cmark/extensions/include/module.modulemap": "swift-cmark",
    "Clang/Packages/swift-markdown/Sources/CAtomic/include/module.modulemap": "swift-markdown",
    "Clang/Packages/iosMath/iosMath/module.modulemap": "iosmath",
}
MODULE = re.compile(r"(?m)^\s*(?:explicit\s+)?(?:framework\s+)?module\s+([A-Za-z_][A-Za-z0-9_]*)\b")


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def bounded_file(path, root):
    path, root = Path(path), Path(root).resolve(strict=True)
    actual = path.resolve(strict=True)
    require(actual.is_relative_to(root) and actual.is_file()
            and actual.stat().st_size <= 8 * 1024 * 1024,
            "Missing, escaping or oversized host Clang declaration: " + str(path))
    return actual


def modules(path):
    text = Path(path).read_text()
    names = MODULE.findall(text)
    require(names and len(names) == len(set(names)),
            "Missing or ambiguous Clang module names: " + str(path))
    return names


def host_module_inventory(root):
    root = Path(root).resolve(strict=True)
    base = root / "Pods/Headers/Public"
    found = {}
    if not base.exists():
        return found
    for path in sorted(base.rglob("*.modulemap")):
        actual = bounded_file(path, root)
        for name in modules(actual):
            previous = found.get(name)
            require(previous is None or Path(previous).resolve() == actual,
                    "Multiple CocoaPods maps define host module " + name)
            found[name] = str(path.relative_to(root))
    return found


def project_host_context(root, distribution, context, identical_revisions):
    root = Path(root).resolve(strict=True)
    distribution = Path(distribution).resolve(strict=True)
    require(distribution.is_relative_to(root / "build"),
            "SDK distribution escapes the owned build")
    maps = context["module_maps"]
    headers = context["header_search_paths"]
    require(len(maps) == len(set(maps)) == 19
            and len(headers) == len(set(headers)) == 19,
            "Original admitted Clang closure differs")
    host_pods = host_module_inventory(root)
    result_maps, result_headers, reused, conflicts = [], [], [], []
    for relative in maps:
        original = bounded_file(distribution / relative, distribution)
        names = modules(original)
        package = SHARED_PACKAGES.get(relative)
        if package is None:
            for name in names:
                if name in host_pods:
                    host = bounded_file(root / host_pods[name], root)
                    conflicts.append({
                        "module": name, "sdk_map": relative,
                        "sdk_map_sha256": digest(original),
                        "host_map": host_pods[name], "host_map_sha256": digest(host),
                        "reason": "SEPARATE_COCOAPODS_RUNTIME_REQUIRES_SHARED_PRODUCT",
                    })
            result_maps.append(str(original.relative_to(root)))
            continue
        require(package in identical_revisions,
                "Shared Clang package revisions differ: " + package)
        package_relative = Path(relative).relative_to("Clang/Packages")
        host = bounded_file(root / "build/SourcePackages/checkouts" / package_relative, root)
        require(digest(original) == digest(host),
                "Shared Clang module-map bytes differ: " + relative)
        original_root = Path(relative).parent.as_posix()
        require(original_root in headers, "Shared module has no admitted header root")
        observed = {}
        # Check the complete exported declaration root, not just its umbrella header.
        for exported in sorted(original.parent.rglob("*")):
            if exported.is_dir():
                continue
            exported = bounded_file(exported, distribution)
            counterpart = bounded_file(host.parent / exported.relative_to(original.parent), root)
            require(digest(exported) == digest(counterpart),
                    "Shared Clang declaration bytes differ: " + str(exported.relative_to(distribution)))
            observed[str(exported.relative_to(original.parent))] = digest(exported)
        require(observed, "Shared Clang declaration root is empty")
        result_maps.append(str(host.relative_to(root)))
        reused.append({
            "modules": names, "package": package, "sdk_map": relative,
            "host_map": str(host.relative_to(root)),
            "sdk_header_root": original_root,
            "host_header_root": str(host.parent.relative_to(root)),
            "declaration_sha256": observed,
        })
    replacements = {item["sdk_header_root"]: item["host_header_root"] for item in reused}
    for relative in headers:
        if relative in replacements:
            result_headers.append(replacements[relative])
        else:
            path = distribution / relative
            require(path.is_dir() and not path.is_symlink(),
                    "Missing or aliased admitted SDK header root")
            result_headers.append(str(path.relative_to(root)))
    return {
        "schema": 1,
        "status": "HOST_RUNTIME_COLLISIONS" if conflicts else "HOST_CLANG_CONTEXT_COMPOSED",
        "producer_identity": context["producer_identity"],
        "module_maps": result_maps,
        "header_search_paths": result_headers,
        "reused_identical_host_modules": reused,
        "runtime_collisions": conflicts,
        "original_export_modified": False,
        "native_build_or_runtime_qualified": False,
    }
