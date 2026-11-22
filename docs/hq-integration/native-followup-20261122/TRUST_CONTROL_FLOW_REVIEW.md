# Immutable trust guard control-flow review

Verifier: 978db8b37256d4dd2d58e91a0ea8d531798221c0:tools/verify_upstream_boundary.py
SHA-256:9733798a242382f59da99cb999a169e2c69c59010b336742e9a8fa151e837676.
Existing baseline031df35710ab2c6015efb1acd1e65154dbcd3f24 remains unchanged.

The current audit emits COUPLED_CHANGE because Scripts/CI/verify-upstream-boundary.py changed
and unapproved protected paths remain. However, protected_files_changed is populated by the
violating paths, not by successfully authenticated exceptions. On genuine successful verification
the guard appends APPROVED_UPSTREAM_EXCEPTION and continues without appending that path to
protected_files_changed. If every exact protected modification authenticates, that list can be
empty and the coupled condition can disappear. Therefore this diagnostic alone does not prove
that an additional baseline revision is necessary. No alternative baseline was created or adopted.

Missing genuine owner signatures and the absent external public verification key remain actual
blockers. Exact blob/diff/archive/repository/expiry checks remain mandatory. Existing PR trusted-base
registry admission is unchanged. This is a read-only control-flow review, not a fabricated signed
positive test or a runtime acceptance claim.

Exact immutable success branch and coupled condition:

```python
789:                 warnings.append({
790:                     "type": "APPROVED_UPSTREAM_EXCEPTION",
791:                     "path": path,
792:                     "approval_ref": approved_entry.get("approval_ref"),
793:                     "attestation": attestation,
794:                     "patch_format": patch_format,
795:                     "message": f"Cryptographically verified upstream exception: {path} (approval={approval_id}, signer={pinned_owner_key[:12]}...)"
796:                 })
797:                 continue
798: 
799:             violations.append({
800:                 "type": "UNAUTHORIZED_UPSTREAM_MODIFICATION",
801:                 "path": path,
802:                 "status": status,
803:                 "provenance": provenance,
804:                 "message": f"Protected upstream-owned file modified without owner approval ({provenance}): {path}"
805:             })
806:             protected_files_changed.append(path)
807:             continue
808: 
809:         # Untracked or added file in protected upstream namespaces
810:         if ("?" in status or "A" in status) and path not in base_files and not is_upstream_owned:
811:             in_protected_ns = any(path.startswith(ns) for ns in PROTECTED_NAMESPACES)
812:             in_allowed_fork_ns = any(path.startswith(ns) for ns in FORK_ALLOWED_NAMESPACES)
813:             if in_protected_ns and not in_allowed_fork_ns:
814:                 violations.append({
815:                     "type": "PROTECTED_NAMESPACE_POLLUTION",
816:                     "path": path,
817:                     "status": status,
818:                     "provenance": provenance,
819:                     "message": f"New file created inside protected namespace without fork prefix ({provenance}): {path}. Use Source/ChavrusaText/ instead."
820:                 })
821:                 protected_files_changed.append(path)
822: 
823:     # Detect bypass attempt: policy files changed together with protected sources
824:     if policy_files_changed and protected_files_changed:
825:         violations.append({
826:             "type": "UNAUTHORIZED_POLICY_BYPASS_ATTEMPT",
827:             "path": ", ".join(policy_files_changed),
828:             "status": "BYPASS",
829:             "provenance": "COUPLED_CHANGE",
830:             "message": "Policy enforcement or exception files were modified in the same change as protected source code!"
```
