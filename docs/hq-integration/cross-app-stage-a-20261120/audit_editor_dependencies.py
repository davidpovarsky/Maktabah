#!/usr/bin/env python3
"""Read pinned Git blobs; record bounded editor feasibility, never build/embed.

No checkout, fetch, package resolution, upstream source copy, account, signing,
network or database write is performed. Output contains metadata and identifiers.
"""
import argparse
import datetime
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--anytype-repo", type=Path, required=True)
parser.add_argument("--otzaria-repo", type=Path, required=True)
parser.add_argument("--anytype-ref", required=True)
parser.add_argument("--otzaria-ref", required=True)
parser.add_argument("--any-engine-ref", required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
if args.output.exists():
    raise SystemExit("Preserve prior evidence; output must not exist")

def git(repo, *arguments):
    return subprocess.check_output(["git", "-C", str(repo), *arguments])

def read(repo, ref, path):
    return git(repo, "show", ref + ":" + path)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def paths(repo, ref, *prefixes):
    return git(repo, "ls-tree", "-r", "--name-only", ref, "--", *prefixes).decode().splitlines()

def metadata(raw):
    text = raw.decode("utf-8")
    return {"sha256": sha(raw), "bytes": len(raw), "lines": len(text.splitlines()),
            "imports": sorted(set(re.findall(r"^\s*(?:@_exported\s+)?import\s+(\w+)", text, re.M))),
            "injected_factories": sorted(set(re.findall(r"@Injected\(\\\.(\w+)\)", text))),
            "declarations": re.findall(r"^\s*(?:(?:public|private|final|internal)\s+)*(?:class|struct|protocol|enum)\s+(\w+)", text, re.M),
            "native_commands": sorted(set(re.findall(r"ClientCommands\.(\w+)", text)))}

any_repo, otz_repo = args.anytype_repo.resolve(), args.otzaria_repo.resolve()
before = git(any_repo, "status", "--porcelain=v1", "-z")
any_head = git(any_repo, "rev-parse", "HEAD").decode().strip()
any_ref = git(any_repo, "rev-parse", args.anytype_ref + "^{commit}").decode().strip()
otz_ref = git(otz_repo, "rev-parse", args.otzaria_ref + "^{commit}").decode().strip()
engine_ref = git(any_repo, "rev-parse", args.any_engine_ref + "^{commit}").decode().strip()
any_paths = [
    "Anytype/Sources/PresentationLayer/TextEditor/EditorPage/EditorPageView.swift",
    "Anytype/Sources/PresentationLayer/TextEditor/Assembly/Page/EditorPageModuleAssembly.swift",
    "Anytype/Sources/PresentationLayer/TextEditor/EditorPage/EditorPageController.swift",
    "Anytype/Sources/PresentationLayer/TextEditor/EditorPage/EditorPageBlocksStateManager.swift",
    "Anytype/Sources/ServiceLayer/Subscriptions/OpenedDocumentsProvider.swift",
    "Anytype/Sources/Models/Documents/Document/BaseDocumentProtocol.swift",
    "Anytype/Sources/Models/Documents/Document/BaseDocument.swift",
    "Anytype/Sources/ServiceLayer/Block/BlockActionHandler/BlockActionService/BlockActionService.swift",
    "Anytype/Sources/ServiceLayer/ServicesDI.swift",
    "Anytype/Sources/PresentationLayer/Assemblies/ModulesDI.swift",
    "Modules/Services/Sources/Services/BlockService/BlockService.swift",
    "Modules/Services/Sources/Services/ObjectLifecycleService/ObjectLifecycleService.swift",
    "Anytype/Anytype.entitlements", "Anytype/AnytypeDebug.entitlements",
    "Anytype.xcodeproj/project.pbxproj", "LICENSE.md",
    "Anytype.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
]
any_raw = {path: read(any_repo, any_ref, path) for path in any_paths}
any_meta = {path: metadata(raw) for path, raw in any_raw.items()}
for path, record in any_meta.items():
    record["original_tree_commit_sha256"] = sha(read(any_repo, any_head, path))
    current = (any_repo / path).read_bytes().replace(b"\r\n", b"\n")
    record["original_tree_working_lf_sha256"] = sha(current)
    record["working_equals_original_head"] = record["original_tree_commit_sha256"] == sha(current)
    record["working_equals_selected_published_ref"] = sha(current) == record["sha256"]

manifests = [p for p in paths(any_repo, any_ref, "Modules") if p.endswith("/Package.swift")]
packages = {}
for path in manifests:
    raw = read(any_repo, any_ref, path); text = raw.decode("utf-8")
    packages[path] = {"sha256": sha(raw),
        "local_packages": re.findall(r'\.package\(path:\s*"([^"]+)"', text),
        "remote_packages": re.findall(r'\.package\(url:\s*"([^"]+)"', text),
        "binary_targets": re.findall(r'\.binaryTarget\(name:\s*"([^"]+)"\s*,\s*path:\s*"([^"]+)"', text),
        "resource_bundle": ".process(" in text}

otz_paths = ["Source/Features/Annotations/Models/Annotation.swift",
    "Source/Features/Annotations/Database/AnnotationRepository.swift",
    "Source/Features/Annotations/Database/AnnotationStore.swift",
    "Source/Core/CloudKit/AnnotationSyncHandler.swift",
    "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift",
    "Source/ChavrusaText-iOS.entitlements", "Maktabah.xcodeproj/project.pbxproj"]
otz_raw = {path: read(otz_repo, otz_ref, path) for path in otz_paths}
engine_paths = ["Modules/PinkhaAnyUI/Package.swift",
    "Modules/PinkhaAnyUI/Sources/PinkhaAnyUI/AnyNativeEditor.swift", "NativeApp/README.md"]
engine_raw = {path: read(any_repo, engine_ref, path) for path in engine_paths}

def text(raw):
    return raw.decode("utf-8")

editor = text(any_raw[any_paths[0]])
assembly = text(any_raw[any_paths[1]])
repository = text(otz_raw[otz_paths[1]])
locked = json.loads(any_raw[any_paths[-1]])["pins"]
any_groups = set()
for path in ["Anytype/Anytype.entitlements", "Anytype/AnytypeDebug.entitlements"]:
    any_groups.update(plistlib.loads(any_raw[path]).get("com.apple.security.application-groups", []))
otz_groups = set(plistlib.loads(otz_raw["Source/ChavrusaText-iOS.entitlements"])
                 .get("com.apple.security.application-groups", []))
tracked_editor = [p for p in paths(any_repo, any_ref, "Anytype/Sources/PresentationLayer/TextEditor") if p.endswith(".swift")]
constructors = sorted(set(re.findall(r"let\s+\w+\s*=\s*([A-Z]\w+)\s*\(", assembly)))
pattern = "TorahAnnotationEnvelope|OtzariaEmbeddedAnyTapyEditorView|AnnotationEditorDocumentAdapter|EXHostViewController|import ExtensionKit"
missing = subprocess.run(["git", "-C", str(any_repo), "grep", "-l", "-E", pattern,
    any_ref, "--", "Anytype", "Modules"], capture_output=True)
if missing.returncode not in (0, 1): raise RuntimeError(missing.stderr.decode())
engine_refs = subprocess.run(["git", "-C", str(any_repo), "grep", "-l", "-E",
    "EditorPageView|EditorPageController", engine_ref, "--", "Modules/PinkhaAnyUI", "NativeApp"], capture_output=True)
if engine_refs.returncode not in (0, 1): raise RuntimeError(engine_refs.stderr.decode())
after = git(any_repo, "status", "--porcelain=v1", "-z")
report = {
    "kind": "bounded source dependency spike; no compile or UI execution",
    "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "anytype_original_worktree": str(any_repo), "anytype_original_head": any_head,
    "anytype_published_source": any_ref, "otzaria_source": otz_ref, "any_engine_source": engine_ref,
    "anytype_worktree_before_sha256": sha(before), "anytype_worktree_after_sha256": sha(after),
    "anytype_worktree_status_unchanged": before == after,
    "anytype_initial_dirty_entries": len([x for x in before.split(b"\0") if x]),
    "source_files": any_meta, "packages": packages,
    "otzaria_source_files": {p: metadata(r) for p, r in otz_raw.items()},
    "separate_any_engine_source_files": {p: metadata(r) for p, r in engine_raw.items()},
    "locked_remote_packages": locked,
    "editor_subtree_swift_file_count": len(tracked_editor),
    "assembly_constructor_identifiers": constructors,
    "observations": {
        "editor_is_internal_app_struct": "struct EditorPageView: View" in editor and "public struct EditorPageView" not in editor,
        "editor_uses_global_factory": "Container.shared.legacyEditorPageModuleAssembly()" in editor,
        "assembly_opens_object_in_space": "objectId: data.objectId" in assembly and "spaceId: data.spaceId" in assembly,
        "opened_document_provider_calls_open": "try await document.open()" in text(any_raw[any_paths[4]]),
        "object_lifecycle_calls_native_open_close": all(v in text(any_raw[any_paths[11]]) for v in ["ClientCommands.objectOpen", "ClientCommands.objectClose"]),
        "block_service_uses_native_commands": bool(any_meta[any_paths[10]]["native_commands"]),
        "separate_editor_package_manifest_present": any("Editor" in p for p in manifests),
        "crossapp_or_extensionkit_source_matches": missing.stdout.decode().splitlines(),
        "any_engine_ui_references_original_editor": engine_refs.stdout.decode().splitlines(),
        "any_engine_is_separate_editor_controller": "public final class AnyNativeEditorController" in text(engine_raw[engine_paths[1]]),
        "otzaria_existing_uuid_assignment": "annotationToSave.ckRecordId = UUID().uuidString" in repository,
        "otzaria_existing_transactional_cloudkit_pending_upload": "try self.addPendingSync(ckRecordId: ckId, operation: \"upload\")" in repository and "try transaction" in repository,
        "otzaria_events_are_passthrough": "PassthroughSubject<AnnotationEvent, Never>" in text(otz_raw[otz_paths[2]]),
    },
    "signing_sources": {
        "anytype_group_ids": sorted(any_groups), "otzaria_group_ids": sorted(otz_groups),
        "common_group_ids": sorted(any_groups & otz_groups),
        "anytype_declared_teams": sorted(set(re.findall(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", text(any_raw["Anytype.xcodeproj/project.pbxproj"])))),
        "otzaria_all_declared_teams": sorted(set(re.findall(r"DEVELOPMENT_TEAM = ([A-Z0-9]+);", text(otz_raw["Maktabah.xcodeproj/project.pbxproj"])))),
        "installed_signatures_or_provisioning_verified": False,
    },
    "boundary": "Identifier/import/manifest inspection is not a compiler call graph or complete transitive dependency closure. No source is copied into an app target; no editor, Heart, account/Space, data, signing, package resolution, UI, migration or cross-app sync is executed. Original dirty worktree inventory is preserved and observed, not committed by this audit.",
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"output": str(args.output), "sha256": sha(args.output.read_bytes()),
    "editor_subtree_swift_files": len(tracked_editor), "assembly_constructor_count": len(constructors),
    "module_manifests": len(packages), "locked_remote_packages": len(locked),
    "worktree_unchanged": before == after, "observations": report["observations"],
    "signing_sources": report["signing_sources"]}, ensure_ascii=False))
