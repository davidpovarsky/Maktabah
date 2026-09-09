#!/usr/bin/env python3
"""Verify an App Store profile and signed app authorize ChavrusaText services."""

from __future__ import annotations

import argparse
import plistlib
from datetime import datetime, timezone
from pathlib import Path


def values(dictionary: dict, key: str) -> set[str]:
    value = dictionary.get(key, [])
    if isinstance(value, str):
        return {value}
    return set(value)


def fail(message: str) -> None:
    print(f"::error::{message}")
    raise SystemExit(1)


def require_entitlements(
    label: str,
    entitlements: dict,
    team_id: str,
    bundle_id: str,
    container_id: str,
    *,
    allow_profile_wildcards: bool = False,
) -> None:
    expected_application_id = f"{team_id}.{bundle_id}"
    if entitlements.get("application-identifier") != expected_application_id:
        fail(
            f"{label} application-identifier: expected {expected_application_id}, "
            f"found {entitlements.get('application-identifier')!r}"
        )
    containers = values(entitlements, "com.apple.developer.icloud-container-identifiers")
    if container_id not in containers:
        fail(f"{label} missing iCloud container {container_id}; found {sorted(containers)}")
    services = values(entitlements, "com.apple.developer.icloud-services")
    missing_services = {"CloudKit", "CloudDocuments"} - services
    if missing_services and not (allow_profile_wildcards and "*" in services):
        fail(
            f"{label} missing iCloud services {sorted(missing_services)}; "
            f"found {sorted(services)}"
        )
    ubiquity = values(
        entitlements, "com.apple.developer.ubiquity-container-identifiers"
    )
    if container_id not in ubiquity:
        fail(f"{label} missing ubiquity container {container_id}; found {sorted(ubiquity)}")
    expected_kvstore = expected_application_id
    kvstore = entitlements.get("com.apple.developer.ubiquity-kvstore-identifier")
    profile_kvstore_wildcard = f"{team_id}.*"
    if kvstore != expected_kvstore and not (
        allow_profile_wildcards and kvstore == profile_kvstore_wildcard
    ):
        fail(
            f"{label} key-value-store identifier: expected {expected_kvstore}, "
            f"found {kvstore!r}"
        )
    if entitlements.get("aps-environment") != "production":
        fail(
            f"{label} aps-environment: expected production, "
            f"found {entitlements.get('aps-environment')!r}"
        )


def require_app_groups(label: str, entitlements: dict) -> None:
    required = {
        "group.com.davidpovarsky.chavrusatext",
        "group.com.davidpovarsky.itorah",
    }
    groups = values(entitlements, "com.apple.security.application-groups")
    missing = required - groups
    if missing:
        fail(f"{label} missing App Groups {sorted(missing)}; found {sorted(groups)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile-plist", type=Path, required=True)
    parser.add_argument("--app-entitlements", type=Path, required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--container-id", required=True)
    args = parser.parse_args()

    profile = plistlib.loads(args.profile_plist.read_bytes())
    profile_entitlements = profile.get("Entitlements", {})
    app_entitlements = plistlib.loads(args.app_entitlements.read_bytes())

    if profile_entitlements.get("get-task-allow") is not False:
        fail("Provisioning profile is not an App Store distribution profile")
    if "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices"):
        fail("Provisioning profile is device-limited or enterprise, not App Store")
    expiration = profile.get("ExpirationDate")
    if not expiration or expiration.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        fail("Provisioning profile is expired")

    require_entitlements(
        "Provisioning profile",
        profile_entitlements,
        args.team_id,
        args.bundle_id,
        args.container_id,
        allow_profile_wildcards=True,
    )
    require_entitlements(
        "Signed app",
        app_entitlements,
        args.team_id,
        args.bundle_id,
        args.container_id,
    )
    require_app_groups("Provisioning profile", profile_entitlements)
    require_app_groups("Signed app", app_entitlements)
    if app_entitlements.get("com.apple.developer.team-identifier") != args.team_id:
        fail("Signed app team identifier does not match APPLE_TEAM_ID")

    print(f"Provisioning profile verified: {profile.get('Name')} ({profile.get('UUID')})")
    print("  distribution: App Store / production")
    print(f"  application-identifier: {args.team_id}.{args.bundle_id}")
    print(f"  iCloud container: {args.container_id}")
    print("  iCloud services: CloudKit, CloudDocuments")
    if "*" in values(profile_entitlements, "com.apple.developer.icloud-services"):
        print("  profile iCloud-services authorization: * (signed app is exact)")
    print(f"  key-value store: {args.team_id}.{args.bundle_id}")
    if profile_entitlements.get("com.apple.developer.ubiquity-kvstore-identifier") == f"{args.team_id}.*":
        print("  profile key-value-store authorization: TEAM.* (signed app is exact)")
    print("  aps-environment: production (no APNs SSL certificate required)")
    print("Signed app entitlements match the provisioning profile")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
