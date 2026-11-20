#!/usr/bin/env python3
"""Verify and select historical Native98 evidence. Executes no app or Native test."""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
import zlib

REPOSITORY = "davidpovarsky/Maktabah"
REPOSITORY_ID = 1280062128
BASE = "e603d8182a1c10c4b37b14c92b5f0bc3829edea8"
BRANCH = "codex/otzaria-native98-commentary-evidence-20261120"
WORKFLOW = ".github/workflows/otzaria-native98-commentary-evidence.yml"
DRIVER = "Scripts/CI/native98-commentary-evidence.py"
TESTS = "Scripts/CI/test-native98-commentary-evidence.py"
MANIFEST = "Scripts/CI/native98-commentary-evidence.json"
SOURCE_PATHS = (WORKFLOW, DRIVER, TESTS, MANIFEST)
DOC_PREFIX = "docs/hq-integration/native98-commentary-evidence-20261120/"
CHUNK = 1024 * 1024


class Refusal(Exception):
    """Fixed public code only; never includes credentials or a signed URL."""


def require(condition, code):
    if not condition:
        raise Refusal(code)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def checkpoint(deadline):
    require(time.monotonic() < deadline, "processing_deadline")


def same_fields(actual, expected, code):
    require(isinstance(actual, dict), code)
    for key, value in expected.items():
        require(type(actual.get(key)) is type(value) and actual[key] == value, code)


def timestamp(value):
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        require(result.tzinfo is not None, "metadata_timestamp")
        return result
    except (AttributeError, TypeError, ValueError):
        raise Refusal("metadata_timestamp") from None


def validate_metadata(run, artifact, job, contract):
    expected_run = contract["sourceRun"]
    same_fields(run, expected_run, "source_run_identity")
    for key in ("repository", "head_repository"):
        same_fields(run.get(key), {"id": REPOSITORY_ID, "full_name": REPOSITORY}, "source_repository")
    expected_artifact = contract["sourceArtifact"]
    same_fields(artifact, expected_artifact, "source_artifact_identity")
    same_fields(artifact.get("workflow_run"), {
        "id": expected_run["id"], "repository_id": REPOSITORY_ID,
        "head_repository_id": REPOSITORY_ID, "head_sha": expected_run["head_sha"],
        "head_branch": expected_run["head_branch"],
    }, "artifact_run_binding")
    same_fields(job, contract["sourceJob"], "source_job_identity")
    steps = job.get("steps")
    require(isinstance(steps, list), "upload_step_missing")
    matches = [s for s in steps if s.get("number") == contract["uploadStep"]["number"]]
    require(len(matches) == 1, "upload_step_missing")
    same_fields(matches[0], contract["uploadStep"], "upload_step_identity")
    require(timestamp(matches[0]["started_at"]) <= timestamp(artifact["created_at"])
            <= timestamp(matches[0]["completed_at"]), "artifact_upload_window")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def safe_storage_url(url):
    try:
        parsed = urllib.parse.urlsplit(url)
        host = parsed.hostname or ""
        allowed = any(host.endswith(suffix) and host != suffix[1:]
                      for suffix in (".blob.core.windows.net", ".actions.githubusercontent.com"))
        require(parsed.scheme == "https" and parsed.port in (None, 443)
                and not parsed.username and not parsed.password and not parsed.fragment
                and allowed and not any(ord(c) < 33 or c == "\\" for c in url),
                "archive_redirect_host")
        return host
    except (ValueError, TypeError):
        raise Refusal("archive_redirect_host") from None


class GitHubReader:
    """Only api.github.com receives Authorization. Every redirect is explicit."""
    def __init__(self, token, deadline, api_opener=None, storage_opener=None):
        require(isinstance(token, str) and bool(token), "github_token_missing")
        self.token, self.deadline = token, deadline
        self.api_opener = api_opener or urllib.request.build_opener(NoRedirect)
        self.storage_opener = storage_opener or urllib.request.build_opener(NoRedirect)

    def api_request(self, route):
        require(route.startswith(f"repos/{REPOSITORY}/actions/")
                and not any(c in route for c in (":", "?", "#", "\\"))
                and ".." not in route.split("/"), "api_route")
        checkpoint(self.deadline)
        return urllib.request.Request("https://api.github.com/" + route, headers={
            "Authorization": "Bearer " + self.token,
            "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "otzaria-native98-evidence-reader",
        })

    def json(self, route):
        try:
            with self.api_opener.open(self.api_request(route), timeout=45) as response:
                require(response.status == 200, "metadata_http_status")
                data = response.read(4 * CHUNK + 1)
            require(len(data) <= 4 * CHUNK, "metadata_size")
            result = json.loads(data)
            require(isinstance(result, dict), "metadata_shape")
            return result
        except Refusal:
            raise
        except Exception:
            raise Refusal("metadata_read_failed") from None

    def metadata(self, contract):
        prefix = f"repos/{REPOSITORY}/actions/"
        return (self.json(prefix + f"runs/{contract['sourceRun']['id']}"),
                self.json(prefix + f"artifacts/{contract['sourceArtifact']['id']}"),
                self.json(prefix + f"jobs/{contract['sourceJob']['id']}"))

    def download(self, artifact_id, destination, expected_bytes, expected_sha):
        route = f"repos/{REPOSITORY}/actions/artifacts/{artifact_id}/zip"
        try:
            response = self.api_opener.open(self.api_request(route), timeout=45)
        except urllib.error.HTTPError as error:
            try:
                require(error.code == 302, "archive_redirect_status")
                url = error.headers.get("Location")
            finally:
                error.close()
        except Refusal:
            raise
        except Exception:
            raise Refusal("archive_redirect_failed") from None
        else:
            response.close()
            raise Refusal("archive_redirect_required")
        host = safe_storage_url(url)
        # A NEW request and a separate no-redirect opener. No token/header forwarding.
        request = urllib.request.Request(url, headers={
            "Accept": "application/octet-stream", "User-Agent": "otzaria-native98-evidence-reader"})
        checkpoint(self.deadline)
        digest, received = hashlib.sha256(), 0
        destination.parent.mkdir(parents=True, exist_ok=True)
        require(not destination.exists(), "archive_output_exists")
        try:
            with self.storage_opener.open(request, timeout=45) as response:
                require(response.status == 200, "archive_http_status")
                length = response.headers.get("Content-Length")
                require(length is None or length == str(expected_bytes), "archive_content_length")
                with destination.open("xb") as handle:
                    while True:
                        checkpoint(self.deadline)
                        chunk = response.read(min(CHUNK, expected_bytes - received + 1))
                        if not chunk:
                            break
                        received += len(chunk)
                        require(received <= expected_bytes, "archive_too_large")
                        handle.write(chunk)
                        digest.update(chunk)
        except Refusal:
            raise
        except Exception:
            raise Refusal("archive_read_failed") from None
        require(received == expected_bytes, "archive_incomplete")
        require(digest.hexdigest() == expected_sha, "archive_sha256")
        return {"bytes": received, "sha256": digest.hexdigest(), "redirectHost": host,
                "authorizationForwardedToStorage": False}


def canonical_entry(info):
    name = info.filename
    require(name == info.orig_filename and name and len(name) <= 2048
            and not any(ord(c) < 32 or c in "\\:" for c in name), "archive_member_path")
    bare = name[:-1] if name.endswith("/") else name
    path = PurePosixPath(bare)
    require(not path.is_absolute() and path.parts and all(p not in (".", "..") for p in path.parts)
            and path.as_posix() == bare and "//" not in name, "archive_member_path")
    kind = stat.S_IFMT(info.external_attr >> 16)
    require(kind in (0, stat.S_IFREG, stat.S_IFDIR), "archive_member_type")
    require((kind != stat.S_IFDIR or info.is_dir()) and not info.flag_bits & 1,
            "archive_member_type")
    require(info.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), "archive_compression")
    return name


def hash_file(path, deadline):
    result = hashlib.sha256()
    with path.open("rb") as handle:
        while data := handle.read(CHUNK):
            checkpoint(deadline)
            result.update(data)
    return result.hexdigest()


def verify_archive(path, contract, output, deadline):
    expected = contract["sourceArtifact"]
    expected_sha = expected["digest"].removeprefix("sha256:")
    require(path.stat().st_size == expected["size_in_bytes"], "archive_size")
    require(hash_file(path, deadline) == expected_sha, "archive_sha256")
    selected_specs = contract["selectedMembers"]
    wanted = {s["path"] for s in selected_specs}
    require(len(wanted) == len(selected_specs) == 3, "selected_member_contract")
    selected, entries, payloads = [], [], {}
    try:
        with zipfile.ZipFile(path) as archive:
            infos = archive.infolist()
            require(3 <= len(infos) <= 50000, "archive_member_count")
            names = [canonical_entry(info) for info in infos]
            require(len(set(names)) == len(names), "archive_duplicate_member")
            require(wanted <= set(names), "selected_member_missing")
            require(sum(i.file_size for i in infos) <= 8 * 1024**3, "archive_expansion_limit")
            for info in infos:
                checkpoint(deadline)
                require(info.file_size <= 4 * 1024**3, "archive_member_limit")
                collect = info.filename in wanted
                require(not collect or (not info.is_dir() and info.file_size <= 8 * CHUNK),
                        "selected_member_limit")
                digest, crc, size = hashlib.sha256(), 0, 0
                chunks = []
                with archive.open(info) as handle:
                    while data := handle.read(CHUNK):
                        checkpoint(deadline)
                        size += len(data)
                        require(size <= info.file_size, "archive_member_size")
                        digest.update(data)
                        crc = zlib.crc32(data, crc)
                        if collect:
                            chunks.append(data)
                require(size == info.file_size and crc == info.CRC, "archive_crc_or_structure")
                receipt = {"path": info.filename, "bytes": size, "compressedBytes": info.compress_size,
                           "crc32": f"{crc:08x}", "sha256": digest.hexdigest(), "crcVerified": True}
                entries.append(receipt)
                if collect:
                    payloads[info.filename] = b"".join(chunks)
                    selected.append(receipt)
    except Refusal:
        raise
    except (zipfile.BadZipFile, EOFError, RuntimeError, ValueError, OSError, zlib.error):
        raise Refusal("archive_crc_or_structure") from None
    require(hash_file(path, deadline) == expected_sha, "archive_changed_during_verification")
    # Publish selected bytes only after the COMPLETE original ZIP passed hash and every CRC.
    for name, payload in payloads.items():
        target = output / "entries" / Path(*PurePosixPath(name).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as handle:
            handle.write(payload)
    write_json(output / "FULL_ARCHIVE_MEMBER_VERIFICATION.json", entries)
    result = {"archiveBytes": expected["size_in_bytes"], "archiveSha256": expected_sha,
              "fullArchiveHashVerifiedBeforeAndAfter": True, "allMembersCRCVerified": True,
              "archiveMemberCount": len(entries), "selected": sorted(selected, key=lambda x: x["path"]),
              "selectedPayloadBytes": sum(len(x) for x in payloads.values())}
    write_json(output / "EXTRACTION_PROOF.json", result)
    return result


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=30)


def verify_source(root, environment, manifest_sha):
    require(environment.get("GITHUB_REPOSITORY") == REPOSITORY
            and environment.get("GITHUB_REPOSITORY_ID") == str(REPOSITORY_ID)
            and environment.get("GITHUB_EVENT_NAME") == "push"
            and environment.get("GITHUB_REF") == "refs/heads/" + BRANCH
            and environment.get("GITHUB_RUN_ATTEMPT") == "1", "processor_identity")
    head = environment.get("GITHUB_SHA", "")
    require(re.fullmatch(r"[0-9a-f]{40}", head) is not None, "processor_sha")
    require(environment.get("GITHUB_WORKFLOW_REF") == f"{REPOSITORY}/{WORKFLOW}@refs/heads/{BRANCH}"
            and environment.get("GITHUB_WORKFLOW_SHA") == head, "processor_workflow")
    require(git(root, "rev-parse", "HEAD").decode().strip() == head, "checkout_head")
    require(git(root, "show", "-s", "--format=%P", "HEAD").decode().split() == [BASE], "checkout_parent")
    changed = git(root, "diff", "--name-only", BASE, head).decode().splitlines()
    require(all(x in SOURCE_PATHS or x.startswith(DOC_PREFIX) for x in changed), "unexpected_source_change")
    source = []
    for name in SOURCE_PATHS:
        path = root / name
        require(path.is_file() and not path.is_symlink(), "processor_source_type")
        data = path.read_bytes()
        require(data == git(root, "show", f"HEAD:{name}"), "processor_source_changed")
        source.append({"path": name, "bytes": len(data), "sha256": sha256(data),
                       "gitBlob": git(root, "rev-parse", f"HEAD:{name}").decode().strip()})
    require(sha256((root / MANIFEST).read_bytes()) == manifest_sha, "manifest_sha256")
    return {"repository": REPOSITORY, "runId": environment.get("GITHUB_RUN_ID"), "attempt": 1,
            "branch": BRANCH, "head": head, "parent": BASE,
            "tree": git(root, "rev-parse", "HEAD^{tree}").decode().strip(), "inputs": source,
            "changedPaths": changed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    args = parser.parse_args()
    root, output, cache = args.root.resolve(), args.output.resolve(), args.cache.resolve()
    if (output / "RESULT.json").exists() or (output / "entries").exists():
        print(json.dumps({"qualified": False, "errorCode": "output_not_fresh", "nativeExecutions": 0}))
        return 1  # Preserve prior evidence exactly, including a prior RESULT.json.
    output.mkdir(parents=True, exist_ok=True)
    result = {"qualified": False, "scope": "Historical artifact integrity and exact-byte extraction only",
              "nativeExecutions": 0, "applicationTestExecutions": 0}
    deadline = time.monotonic() + 900
    try:
        require(output != cache and output not in cache.parents and cache not in output.parents, "cache_output_overlap")
        before = verify_source(root, os.environ, args.manifest_sha256)
        write_json(output / "SOURCE_BEFORE.json", before)
        contract = json.loads((root / MANIFEST).read_bytes())
        reader = GitHubReader(os.environ.get("GH_TOKEN"), deadline)
        metadata = reader.metadata(contract)
        for label, value in zip(("RUN", "ARTIFACT", "JOB"), metadata):
            write_json(output / ("SOURCE_" + label + "_BEFORE.json"), value)
        validate_metadata(*metadata, contract)
        archive = cache / "artifact-14632274701.zip"
        downloaded = reader.download(contract["sourceArtifact"]["id"], archive,
                                     contract["sourceArtifact"]["size_in_bytes"],
                                     contract["sourceArtifact"]["digest"].removeprefix("sha256:"))
        write_json(output / "DOWNLOAD_RECEIPT.json", downloaded)
        extraction = verify_archive(archive, contract, output, deadline)
        after_metadata = reader.metadata(contract)
        for label, value in zip(("RUN", "ARTIFACT", "JOB"), after_metadata):
            write_json(output / ("SOURCE_" + label + "_AFTER.json"), value)
        validate_metadata(*after_metadata, contract)
        after = verify_source(root, os.environ, args.manifest_sha256)
        require(before == after, "processor_inputs_changed")
        write_json(output / "SOURCE_AFTER.json", after)
        result.update(qualified=True, sourceRunId=contract["sourceRun"]["id"],
                      sourceRunConclusion=contract["sourceRun"]["conclusion"],
                      sourceArtifactId=contract["sourceArtifact"]["id"], extraction=extraction)
    except Exception as error:
        # Exception strings can contain a signed storage URL: emit only our fixed code or type.
        result.update(errorCode=str(error) if isinstance(error, Refusal) else "unexpected_processor_failure",
                      errorType=type(error).__name__)
    write_json(output / "RESULT.json", result)
    print(json.dumps({"qualified": result["qualified"], "errorCode": result.get("errorCode"),
                      "nativeExecutions": 0}, sort_keys=True))
    return 0 if result["qualified"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
