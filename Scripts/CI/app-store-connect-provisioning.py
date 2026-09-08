#!/usr/bin/env python3
"""Inspect App Store Connect provisioning state and create an App Store profile."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com"


class AppStoreConnectClient:
    def __init__(self, key_path: Path, key_id: str, issuer_id: str) -> None:
        now = int(time.time())
        token = jwt.encode(
            {"iss": issuer_id, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
            key_path.read_bytes(),
            algorithm="ES256",
            headers={"kid": key_id, "typ": "JWT"},
        )
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        url = path if path.startswith("https://") else f"{API_ROOT}{path}"
        payload = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(
            url, data=payload, headers=self.headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            response = error.read().decode("utf-8", errors="replace")
            try:
                details = json.loads(response).get("errors", [])
                detail_text = "; ".join(
                    f"{item.get('code', 'unknown')}: {item.get('detail', item.get('title', ''))}"
                    for item in details
                )
            except json.JSONDecodeError:
                detail_text = response[:1000]
            print(f"::error::App Store Connect API {method} {path} failed with HTTP {error.code}: {detail_text}")
            if error.code == 403:
                print(
                    "::error::The ASC API key lacks provisioning-management access. "
                    "Use an Admin API key with Certificates, Identifiers & Profiles access."
                )
            raise SystemExit(1) from error

    def list_all(self, path: str) -> list[dict]:
        resources: list[dict] = []
        next_path: str | None = path
        while next_path:
            response = self.request("GET", next_path)
            resources.extend(response.get("data", []))
            next_path = response.get("links", {}).get("next")
        return resources


def find_bundle_id(client: AppStoreConnectClient, identifier: str) -> dict:
    query = urllib.parse.urlencode(
        {"filter[identifier]": identifier, "limit": "10"}
    )
    matches = client.list_all(f"/v1/bundleIds?{query}")
    exact = [
        item
        for item in matches
        if item.get("attributes", {}).get("identifier") == identifier
    ]
    if len(exact) != 1:
        print(
            f"::error::Expected one registered Bundle ID for {identifier}, found {len(exact)}"
        )
        raise SystemExit(1)
    bundle = exact[0]
    platform = bundle.get("attributes", {}).get("platform")
    if platform != "IOS":
        print(f"::error::Bundle ID {identifier} has platform {platform}, expected IOS")
        raise SystemExit(1)
    return bundle


def inspect_capabilities(
    client: AppStoreConnectClient, bundle: dict, identifier: str
) -> None:
    capabilities = client.list_all(
        f"/v1/bundleIds/{bundle['id']}/bundleIdCapabilities?limit=200"
    )
    capability_types = sorted(
        item.get("attributes", {}).get("capabilityType", "<unknown>")
        for item in capabilities
    )
    print(f"Registered Bundle ID verified: {identifier} ({bundle['id']})")
    print(f"Enabled capability types: {', '.join(capability_types)}")
    icloud = [
        item
        for item in capabilities
        if item.get("attributes", {}).get("capabilityType") == "ICLOUD"
    ]
    if not icloud:
        print(f"::error::Registered Bundle ID {identifier} does not expose ICLOUD capability")
        raise SystemExit(1)
    settings = icloud[0].get("attributes", {}).get("settings", [])
    print(f"iCloud capability verified; settings: {json.dumps(settings, sort_keys=True)}")


def normalize_serial(value: str) -> str:
    return "".join(character for character in value.upper() if character in "0123456789ABCDEF").lstrip("0") or "0"


def create_profile(
    client: AppStoreConnectClient,
    bundle: dict,
    certificate_serial: str,
    output: Path,
    metadata_output: Path,
) -> None:
    certificates = client.list_all("/v1/certificates?limit=200")
    wanted_serial = normalize_serial(certificate_serial)
    candidates = []
    for certificate in certificates:
        attributes = certificate.get("attributes", {})
        certificate_type = attributes.get("certificateType", "")
        if not attributes.get("activated", False):
            continue
        if "DISTRIBUTION" not in certificate_type:
            continue
        if normalize_serial(attributes.get("serialNumber", "")) == wanted_serial:
            candidates.append(certificate)
    if len(candidates) != 1:
        available = [
            f"{item.get('attributes', {}).get('certificateType')}:{item.get('attributes', {}).get('serialNumber')}"
            for item in certificates
            if item.get("attributes", {}).get("activated", False)
            and "DISTRIBUTION" in item.get("attributes", {}).get("certificateType", "")
        ]
        print(
            f"::error::Expected one active Apple Distribution certificate matching serial "
            f"{certificate_serial}, found {len(candidates)}. Active API certificates: {available}"
        )
        raise SystemExit(1)

    profile_name = (
        f"ChavrusaText_App_Store_Automated_{os.environ.get('GITHUB_RUN_ID', int(time.time()))}_"
        f"{os.environ.get('GITHUB_RUN_ATTEMPT', '1')}"
    )
    body = {
        "data": {
            "type": "profiles",
            "attributes": {
                "name": profile_name,
                "profileType": "IOS_APP_STORE",
            },
            "relationships": {
                "bundleId": {
                    "data": {"type": "bundleIds", "id": bundle["id"]}
                },
                "certificates": {
                    "data": [
                        {"type": "certificates", "id": candidates[0]["id"]}
                    ]
                },
            },
        }
    }
    response = client.request("POST", "/v1/profiles", body)
    profile = response["data"]
    attributes = profile["attributes"]
    output.write_bytes(base64.b64decode(attributes["profileContent"]))
    metadata_output.write_text(
        json.dumps(
            {
                "id": profile["id"],
                "name": attributes["name"],
                "uuid": attributes["uuid"],
                "profileType": attributes["profileType"],
                "profileState": attributes["profileState"],
            }
        ),
        encoding="utf-8",
    )
    print(
        f"Created App Store provisioning profile {attributes['name']} "
        f"({attributes['uuid']}) through the official API"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("inspect", "create-profile"))
    parser.add_argument("--key-path", type=Path, required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--certificate-serial")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--metadata-output", type=Path)
    args = parser.parse_args()

    client = AppStoreConnectClient(args.key_path, args.key_id, args.issuer_id)
    bundle = find_bundle_id(client, args.bundle_id)
    inspect_capabilities(client, bundle, args.bundle_id)
    if args.operation == "create-profile":
        if not args.certificate_serial or not args.output or not args.metadata_output:
            parser.error(
                "create-profile requires --certificate-serial, --output, and --metadata-output"
            )
        create_profile(
            client,
            bundle,
            args.certificate_serial,
            args.output,
            args.metadata_output,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
