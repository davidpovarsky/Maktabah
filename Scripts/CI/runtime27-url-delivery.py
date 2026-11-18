#!/usr/bin/env python3
"""Deliver real system URLs to one owned simulator; never claim UI acceptance."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
import time
import uuid


class NativeURLDelivery:
    def __init__(self, udid, container, label, artifacts):
        self.udid = str(uuid.UUID(udid)).upper()
        self.container = Path(container)
        self.label, self.artifacts = label, Path(artifacts)
        self.token = secrets.token_hex(16)
        self.directory = Path(tempfile.mkdtemp(prefix="r27-url-"))
        self.ready = self.directory / "ready.json"
        self.process = self.log = None

    def start(self):
        environment = os.environ.copy()
        environment["R27_URL_AUTH_TOKEN"] = self.token
        self.log = (self.artifacts / f"url-delivery-{self.label}.log").open("w")
        self.process = subprocess.Popen([
            sys.executable, str(Path(__file__).resolve()), "--udid", self.udid,
            "--containers", str(self.container.parent), "--ready", str(self.ready),
            "--evidence", str(self.artifacts / f"url-delivery-{self.label}.jsonl")
        ], env=environment, stdout=self.log, stderr=subprocess.STDOUT)
        limit = time.monotonic() + 15
        while not self.ready.exists():
            if self.process.poll() is not None or time.monotonic() > limit:
                raise RuntimeError("Owned system URL transport did not become ready")
            time.sleep(0.1)
        if json.loads(self.ready.read_text())["udid"] != self.udid:
            raise RuntimeError("System URL transport has a different simulator target")
        return {"TEST_RUNNER_R27_URL_TOKEN": self.token, "TEST_RUNNER_R27_URL_UDID": self.udid}

    def redact_evidence(self, text):
        return re.sub(re.escape(self.token), "<redacted-url-token>", text, flags=re.IGNORECASE)

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        if self.log:
            self.log.close()


def dispatch_request(request, token, udid, seen, run=subprocess.run, now=time.time):
    result = {"udid": udid, "transport": "simctl-system-openurl", "delivered": False}
    validated = False
    try:
        if request.stat().st_size > 8192:
            raise ValueError()
        data = json.loads(request.read_text())
        nonce, url = data["nonce"], data["url"]
        if (set(data) != {"token", "nonce", "udid", "url"} or not token
                or data["token"] != token or data["udid"] != udid
                or not isinstance(nonce, str) or str(uuid.UUID(nonce)).upper() != nonce
                or nonce in seen or len(seen) >= 256
                or request.name != f"r27-url-{token}-{nonce}.request.json"
                or not 0 <= now() - request.stat().st_mtime < 30
                or not isinstance(url, str) or len(url) > 6144
                or not re.fullmatch(r"maktabah-debug://action/(?:v[12]/native\.(?:history|search|annotations|library|reader\.toc)|v2/native\.reader)\?route=[A-Za-z0-9_-]+", url)):
            raise ValueError()
        # This is transport syntax only. The actual app's canonical parser,
        # backend/scene authority and receipt ledger still decide the outcome.
        seen.add(nonce)
        result["nonce"] = nonce
        validated = True
        completed = run(["xcrun", "simctl", "openurl", udid, url],
                        capture_output=True, timeout=12, check=False)
        result["delivered"] = completed.returncode == 0
        if not result["delivered"]:
            result["error"] = f"System URL transport exited with code {int(completed.returncode)}"
    except subprocess.TimeoutExpired:
        result["error"] = "System URL transport timed out"
    except OSError:
        result["error"] = "System URL transport could not start" if validated else "System URL request rejected"
    except Exception:
        # No raw URL, private filename, credentials, argv or subprocess stderr.
        result["error"] = "System URL transport failed" if validated else "System URL request rejected"
    result["time"] = now()
    return result


def serve(args):
    token = os.environ.pop("R27_URL_AUTH_TOKEN")
    udid = str(uuid.UUID(args.udid)).upper()
    seen, paths = set(), set()
    Path(args.ready).write_text(json.dumps({"udid": udid, "transport": "simctl-system-openurl"}))
    while True:
        for request in Path(args.containers).glob(f"*/Documents/r27-url-{token}-*.request.json"):
            if request in paths:
                continue
            # Bound this job-local fixture without deleting any app files.
            if len(paths) >= 256:
                raise RuntimeError("Owned system URL request limit exceeded")
            paths.add(request)
            result = dispatch_request(request, token, udid, seen)
            with Path(args.evidence).open("a") as evidence:
                evidence.write(json.dumps(result) + "\n")
            ack = request.with_name(request.name.replace(".request.json", ".ack.json"))
            temporary = ack.with_suffix(".tmp")
            try:
                temporary.write_text(json.dumps(result))
                temporary.replace(ack)
            except OSError:
                raise RuntimeError("Could not write owned system URL acknowledgement") from None
        time.sleep(0.1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for key in ["udid", "containers", "ready", "evidence"]:
        parser.add_argument("--" + key, required=True)
    serve(parser.parse_args())
