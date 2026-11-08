"""Bounded recovery of a timed-out container query on the caller-owned Simulator."""
import json
from pathlib import Path
import subprocess
import sys
import uuid


def mini_lexical_root(database_path, container):
    """Use the native install receipt, including its actual App Group choice."""
    database = Path(database_path).resolve(strict=True)
    container = Path(container).resolve(strict=True)
    if not database.is_file() or database.parts[-5:] != ("Otzaria", "Profiles", "miniTest10", "database", "seforim.db"):
        raise RuntimeError("The native receipt does not identify a real miniTest10 database")
    storage_root = database.parents[4]
    groups = container.parents[2] / "Shared/AppGroup"
    private_roots = {container / "Library/Application Support/Maktabah-Debug",
                     container / "Library/Application Support"}
    if storage_root not in private_roots:
        if storage_root.parent != groups:
            raise RuntimeError("The native installation escaped this Simulator's app/group containers")
        uuid.UUID(storage_root.name)
    return database.parents[3] / "SearchResources"


def app_data_container(udid, bundle, receipt):
    # Never accept an alias such as 'booted', which could target another job.
    udid = str(uuid.UUID(udid)).upper()
    attempts = []
    receipt = Path(receipt)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(2):
        record = {"attempt": attempt + 1, "udid": udid, "bundle": bundle}
        attempts.append(record)
        try:
            value = subprocess.check_output(
                ["xcrun", "simctl", "get_app_container", udid, bundle, "data"],
                text=True, timeout=45 if attempt == 0 else 90).strip()
            if not value or not Path(value).is_absolute() or not Path(value).is_dir():
                raise RuntimeError("The native Simulator returned no existing application data container")
            # Validate the actual native response, never infer a container UUID.
            registry = (Path.home() / "Library/Developer/CoreSimulator/Devices" / udid
                        / "data/Containers/Data/Application").resolve()
            container = Path(value).resolve()
            if not container.is_relative_to(registry) or container.parent != registry:
                raise RuntimeError("The native data container is outside this Simulator's application registry")
            record.update(status="RESOLVED", path=str(container))
            return container
        except subprocess.TimeoutExpired as error:
            record.update(status="TIMEOUT", error=str(error))
            receipt.write_text(json.dumps({"attempts": attempts}, indent=2), encoding="utf-8")
            if attempt:
                raise
            # Same scoped recovery already used by the native visual matrix.
            # Installed data is retained; no XCTest or failed installer is retried.
            subprocess.run([sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid],
                           check=True, timeout=240)
            subprocess.run(["xcrun", "simctl", "boot", udid], check=True, timeout=90)
            subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=300)
        except (subprocess.CalledProcessError, RuntimeError) as error:
            record.update(status="FAILED", error=str(error))
            raise
        finally:
            receipt.write_text(json.dumps({"attempts": attempts}, indent=2), encoding="utf-8")
