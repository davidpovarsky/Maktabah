"""True portable compile/run of real app types; never substitute a coordinator."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(args):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)


binary_path = subprocess.check_output(["swift", "build", "--package-path", "Source/Otzaria/Actions", "--show-bin-path"], cwd=ROOT, text=True).strip()
object_folder = Path(binary_path) / "OtzariaActionCore.build"
objects = list(object_folder.glob("*.o")) + list(object_folder.glob("*.obj"))
assert objects, "Build the focused Core package first; no dependencies are installed by this script"
files = [
    "Source/LibraryBackend/LibraryBackendModels.swift",
    "Source/LibraryBackend/LibraryBackendProtocols.swift",
    "Source/LibraryBackend/BackendCoordinator.swift",
    "Source/Otzaria/Actions/Integration/ActionAppIdentityBridge.swift",
    "Source/Otzaria/Actions/Integration/ActionBackendCoordinatorFacade.swift",
    "Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift",
    "Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift",
    "Source/SefariaEmbedded/Runtime/SefariaRuntimeManager.swift",
    "Source/SefariaEmbedded/Runtime/SefariaExpoLifecycleAdapter.swift",
    "Source/SefariaEmbedded/Adapters/SefariaEmbeddedRelationshipsAdapter.swift",
    "docs/hq-actions-bridge/RuntimeAcceptance.swift",
    "docs/hq-actions-bridge/RelationshipsAcceptance.swift",
    "docs/hq-actions-bridge/ResourceAcceptance.swift",
    "docs/hq-actions-bridge/IntegrationAcceptance.swift",
]
with tempfile.TemporaryDirectory(prefix="hq-actions-integration-") as folder:
    target = Path(folder) / "integration-fixtures.exe"
    run(["swiftc", "-parse-as-library", "-swift-version", "6", "-strict-concurrency=complete",
         "-I", str(Path(binary_path) / "Modules"), *files, *map(str, objects), "-o", str(target)])
    run([str(target)])
