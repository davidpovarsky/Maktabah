#!/usr/bin/env python3
"""Wait for one uploaded App Store Connect build to finish processing."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com"
TERMINAL_STATES = {"VALID", "FAILED", "INVALID"}


class Client:
    def __init__(self, key_path: Path, key_id: str, issuer_id: str) -> None:
        self.private_key = key_path.read_bytes()
        self.key_id = key_id
        self.issuer_id = issuer_id

    def get(self, path: str) -> dict:
        now = int(time.time())
        token = jwt.encode(
            {
                "iss": self.issuer_id,
                "iat": now,
                "exp": now + 600,
                "aud": "appstoreconnect-v1",
            },
            self.private_key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )
        request = urllib.request.Request(
            f"{API_ROOT}{path}",
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)


def query(client: Client, bundle_id: str, version: str, build_number: str) -> dict | None:
    app_query = urllib.parse.urlencode(
        {"filter[bundleId]": bundle_id, "fields[apps]": "name,bundleId"}
    )
    apps = client.get(f"/v1/apps?{app_query}").get("data", [])
    if len(apps) != 1:
        raise RuntimeError(f"expected one App Store Connect app for {bundle_id}, found {len(apps)}")

    build_query = urllib.parse.urlencode(
        {
            "filter[app]": apps[0]["id"],
            "filter[version]": build_number,
            "fields[builds]": "version,uploadedDate,processingState,expired,preReleaseVersion",
            "fields[preReleaseVersions]": "version,platform",
            "include": "preReleaseVersion",
            "limit": "20",
        }
    )
    response = client.get(f"/v1/builds?{build_query}")
    prereleases = {
        item["id"]: item.get("attributes", {})
        for item in response.get("included", [])
        if item.get("type") == "preReleaseVersions"
    }
    for build in response.get("data", []):
        relationship = build.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
        prerelease = prereleases.get(relationship.get("id"), {})
        if prerelease.get("version") == version and prerelease.get("platform") == "IOS":
            attributes = build.get("attributes", {})
            return {
                "appId": apps[0]["id"],
                "buildId": build["id"],
                "bundleId": bundle_id,
                "version": version,
                "buildNumber": build_number,
                "processingState": attributes.get("processingState", "UNKNOWN"),
                "uploadedDate": attributes.get("uploadedDate"),
                "expired": attributes.get("expired"),
            }
    return None


def write_result(path: Path, result: dict) -> None:
    result["observedAt"] = datetime.now(timezone.utc).isoformat()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--key-path", type=Path, required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout-seconds", type=int, default=5400)
    parser.add_argument("--interval-seconds", type=int, default=30)
    args = parser.parse_args()

    client = Client(args.key_path, args.key_id, args.issuer_id)
    deadline = time.monotonic() + args.timeout_seconds
    last_result: dict = {
        "bundleId": args.bundle_id,
        "version": args.version,
        "buildNumber": args.build_number,
        "processingState": "AWAITING_APPEARANCE",
    }

    while True:
        try:
            observed = query(
                client,
                bundle_id=args.bundle_id,
                version=args.version,
                build_number=args.build_number,
            )
            if observed is not None:
                last_result = observed
                state = observed["processingState"]
                print(
                    f"App Store Connect build {args.version} ({args.build_number}): {state}",
                    flush=True,
                )
                if state in TERMINAL_STATES:
                    write_result(args.output, observed)
                    if state == "VALID":
                        print("TestFlight processing completed successfully.", flush=True)
                        return 0
                    print(f"::error::Apple processing ended in {state}", flush=True)
                    return 1
            else:
                print(
                    f"Waiting for App Store Connect build {args.version} ({args.build_number}) to appear...",
                    flush=True,
                )
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")[:1000]
            if error.code == 429 or error.code >= 500:
                print(f"Transient App Store Connect HTTP {error.code}: {detail}", flush=True)
            else:
                print(f"::error::App Store Connect HTTP {error.code}: {detail}", flush=True)
                last_result["processingState"] = "API_FAILURE"
                last_result["httpStatus"] = error.code
                write_result(args.output, last_result)
                return 1
        except (OSError, RuntimeError) as error:
            print(f"Transient App Store Connect query error: {error}", flush=True)

        if time.monotonic() >= deadline:
            last_result["processingState"] = "PROCESSING_TIMEOUT"
            write_result(args.output, last_result)
            print(
                f"::error::Apple processing did not finish within {args.timeout_seconds} seconds",
                flush=True,
            )
            return 2
        time.sleep(args.interval_seconds)


if __name__ == "__main__":
    sys.exit(main())
