"""Emit a reviewable registration patch; never edit the shared Xcode project."""
import difflib
import hashlib
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
patch = "".join(difflib.unified_diff(original.splitlines(keepends=True), modified.splitlines(keepends=True),
                                     fromfile="a/Maktabah.xcodeproj/project.pbxproj", tofile="b/Maktabah.xcodeproj/project.pbxproj"))
(Path(__file__).parent / "N_PROPOSED_PACKAGE_REGISTRATION.diff").write_text(patch, encoding="utf-8")
print("Created proposal only; shared project unchanged. Base SHA256=" + hashlib.sha256(target.read_bytes()).hexdigest())
