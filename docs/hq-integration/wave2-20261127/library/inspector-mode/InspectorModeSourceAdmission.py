"""Exact source lifecycle witness. No SwiftUI scheduling or UI execution claim."""
import hashlib
import json
from pathlib import Path
import sys


def inspect(root, workspace_path):
    root = Path(root)
    workspace = Path(workspace_path).read_bytes()
    baseline_host = (root / "host-baseline.swift").read_bytes()
    candidate_host = (root / "OtzariaReaderSourcesInspectorHost.swift").read_bytes()
    adapter = (root / "MaktabahTorahInspectorAdapter.swift").read_bytes()
    owner = workspace.decode()
    before, after = baseline_host.decode(), candidate_host.decode()
    method = adapter.decode().split("    func replacementForTextMode(", 1)[1].split("    /// A workspace retains", 1)[0]
    generation = lambda text: text.split("        .onChange(of: backendCoordinator.generation", 1)[1].split("        .onChange(of: viewModel.currentReaderTextMode", 1)[0]
    cases = {
        "owner_retains_session_in_state": "@State private var inspectorSession: MaktabahTorahInspectorSession" in owner,
        "outer_host_identity_includes_mode": '.id("\\(BackendCoordinator.shared.generation):\\(viewModel.currentReaderTextMode.rawValue):\\(inspectorContentID)")' in owner,
        "baseline_mode_observer_has_no_initial_admission": ".onChange(of: viewModel.currentReaderTextMode) {" in before,
        "candidate_mode_observer_admits_initial_mount": ".onChange(of: viewModel.currentReaderTextMode, initial: true) {" in after,
        "candidate_assigns_only_actual_replacement": "if let replacement = inspectorSession.replacementForTextMode(mode, viewModel: viewModel) {\n                inspectorSession = replacement" in after,
        "matching_mode_returns_no_replacement": "guard preferredMode != mode else { return nil }" in method,
        "replacement_uses_current_mode_and_original_provider_owners": all(v in method for v in ("coordinator: coordinator", "otzaria: otzaria", "preferredMode: mode", "viewModel: viewModel")),
        "generation_admission_and_conditional_close_unchanged": generation(before) == generation(after),
    }
    return {
        "scope": "Read-only source admission: proves retained-state/remount boundary and new conditional initial callback; does not execute SwiftUI lifecycle",
        "cases": cases,
        "all_expected_source_properties": all(cases.values()),
        "sha256": {
            "workspace": hashlib.sha256(workspace).hexdigest(),
            "baseline_host": hashlib.sha256(baseline_host).hexdigest(),
            "candidate_host": hashlib.sha256(candidate_host).hexdigest(),
            "candidate_adapter": hashlib.sha256(adapter).hexdigest(),
        },
    }


if __name__ == "__main__":
    result = inspect(sys.argv[1], sys.argv[2])
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(0 if result["all_expected_source_properties"] else 1)
