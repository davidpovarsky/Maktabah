"""Emit a reviewable registration patch; never edit the shared Xcode project."""
import difflib
import hashlib
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
target = root / "Maktabah.xcodeproj/project.pbxproj"
original = target.read_text(encoding="utf-8")
modified = original
ids = {kind: hashlib.sha256(("N:ChavrusaUIRoutingHost:" + kind).encode()).hexdigest()[:24].upper()
       for kind in ["package", "product", "framework"]}
assert all(value not in original for value in ids.values())

def replace_once(anchor, replacement):
    global modified
    assert modified.count(anchor) == 1, anchor
    modified = modified.replace(anchor, replacement, 1)

replace_once("/* End PBXBuildFile section */", f'\t\t{ids["framework"]} /* ChavrusaUIRoutingHost in Frameworks */ = {{isa = PBXBuildFile; productRef = {ids["product"]} /* ChavrusaUIRoutingHost */; }};\n/* End PBXBuildFile section */')
anchor = "\t\tF30577472FA46222005732C6 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tfiles = (\n"
replace_once(anchor, anchor + f'\t\t\t\t{ids["framework"]} /* ChavrusaUIRoutingHost in Frameworks */,\n')
anchor = '\t\t\tname = "Maktabah-iOS";\n\t\t\tpackageProductDependencies = (\n'
replace_once(anchor, anchor + f'\t\t\t\t{ids["product"]} /* ChavrusaUIRoutingHost */,\n')
anchor = "\t\t\tpackageReferences = (\n"
replace_once(anchor, anchor + f'\t\t\t\t{ids["package"]} /* ChavrusaUIRoutingHost */,\n')
anchor = "/* End XCLocalSwiftPackageReference section */"
replace_once(anchor, f'\t\t{ids["package"]} /* ChavrusaUIRoutingHost */ = {{\n\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = Source/ChavrusaText/UIRoutingHost;\n\t\t}};\n' + anchor)
anchor = "/* End XCSwiftPackageProductDependency section */"
replace_once(anchor, f'\t\t{ids["product"]} /* ChavrusaUIRoutingHost */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = {ids["package"]} /* ChavrusaUIRoutingHost */;\n\t\t\tproductName = ChavrusaUIRoutingHost;\n\t\t}};\n' + anchor)

integration = sorted((root / "Source/ChavrusaText/UIRoutingHost/Integration").glob("*.swift"))
def xid(value):
    result = hashlib.sha256(("N:HostIntegration:" + value).encode()).hexdigest()[:24].upper()
    assert result not in original
    return result
group_id = xid("group")
file_refs, build_refs, children, source_members = [], [], [], []
for source in integration:
    ref, build = xid(source.name + ":ref"), xid(source.name + ":build")
    relative = source.relative_to(root).as_posix()
    file_refs.append(f'\t\t{ref} /* {source.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {relative}; sourceTree = "<group>"; }};\n')
    build_refs.append(f'\t\t{build} /* {source.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {source.name} */; }};\n')
    children.append(f'\t\t\t\t{ref} /* {source.name} */,\n')
    source_members.append(f'\t\t\t\t{build} /* {source.name} in Sources */,\n')
replace_once("/* End PBXFileReference section */", "".join(file_refs) + "/* End PBXFileReference section */")
replace_once("/* End PBXBuildFile section */", "".join(build_refs) + "/* End PBXBuildFile section */")
root_anchor = '\t\t4B32021F2EDAFE85003B95D1 = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
replace_once(root_anchor, root_anchor + f'\t\t\t\t{group_id} /* Native Routing Host */,\n')
group = f'\t\t{group_id} /* Native Routing Host */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n' + "".join(children) + '\t\t\t);\n\t\t\tname = "Native Routing Host";\n\t\t\tsourceTree = "<group>";\n\t\t};\n'
replace_once("/* End PBXGroup section */", group + "/* End PBXGroup section */")
native = re.search(r'/\* Begin PBXNativeTarget section \*/(.*?)/\* End PBXNativeTarget section \*/', original, re.S).group(1)
app = re.search(r'F30576DD2FA46222005732C6.*?buildPhases = \((.*?)\);', native, re.S).group(1)
phase = re.search(r'([A-F0-9]+) /\* Sources \*/', app).group(1)
anchor = f'\t\t{phase} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tfiles = (\n'
replace_once(anchor, anchor + "".join(source_members))
patch = "".join(difflib.unified_diff(original.splitlines(keepends=True), modified.splitlines(keepends=True),
                                     fromfile="a/Maktabah.xcodeproj/project.pbxproj", tofile="b/Maktabah.xcodeproj/project.pbxproj"))
(Path(__file__).parent / "N_PROPOSED_PACKAGE_REGISTRATION.diff").write_text(patch, encoding="utf-8")
print("Created proposal only; shared project unchanged. Base SHA256=" + hashlib.sha256(target.read_bytes()).hexdigest())

hooks = []
def hook(relative, changes):
    old = (root / relative).read_text(encoding="utf-8")
    new = old
    for anchor, replacement in changes:
        assert new.count(anchor) == 1, (relative, anchor)
        new = new.replace(anchor, replacement, 1)
    hooks.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True), fromfile="a/" + relative, tofile="b/" + relative))

hook("Source/UI/iOS/MaktabahApp.swift", [("        BackendComposition.registerAll()\n", "        BackendComposition.registerAll()\n        MaktabahNativeRoutingComposition.shared.installIntentDependency()\n")])
hook("Source/UI/iOS/Views/iOSMainView.swift", [
    ("                SettingsView()\n", "                SettingsView()\n                    .modifier(MaktabahNativeRoutingSurface(kind: .settings))\n"),
    ("        .modifier(CompactStudyWorkspaceHostModifier(manager: navigationManager))\n", "        .modifier(MaktabahNativeRoutingHost(manager: navigationManager, selectedTab: $selectedTab, columnVisibility: $columnVisibility, showSettings: $showSettings))\n        .modifier(CompactStudyWorkspaceHostModifier(manager: navigationManager))\n"),
    ("        guard let deepLink = WidgetDeepLink.parse(from: url) else { return }\n", "        if MaktabahNativeURLHandler.handle(url, manager: bManager) { return }\n        guard let deepLink = WidgetDeepLink.parse(from: url) else { return }\n")])
hook("Source/UI/iOS/Views/iPadLayout.swift", [("            iOSHistoryView()\n", "            iOSHistoryView()\n                .modifier(MaktabahNativeRoutingSurface(kind: .history))\n")])
(Path(__file__).parent / "N_PROPOSED_NATIVE_HOOKS.diff").write_text("".join(hooks), encoding="utf-8")
print(f"Proposed {len(integration)} app integration source registrations and five narrow native hooks; no protected file edited")
