"""A measured capacity wait before the original compiler; no build credit."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import time


def require(value, message):
    if not value:
        raise RuntimeError(message)


def wait_for_capacity(root, output, checkout_sha, directory, maximum_wait_seconds=1800):
    root = Path(root).resolve(strict=True)
    plans = Path(directory)
    if not plans.is_absolute():
        plans = root / plans
    require(not plans.is_symlink(), "Capacity plan directory cannot be a symlink")
    plans = plans.resolve(strict=True)
    require(plans.is_relative_to(root / "build") and plans.is_dir(),
            "Capacity plans must belong to this build")
    output = Path(output)
    observations = output / "compiler-capacity-observations.jsonl"
    require(not observations.exists(), "Capacity observations must not be overwritten")
    started = time.monotonic()
    recorded = {}
    own_forecast = None
    while True:
        paths = sorted(plans.glob("*.json"))
        require(paths and [p.name for p in paths] ==
                [f"{n:04d}.json" for n in range(1, len(paths) + 1)],
                "Capacity revisions must be an append-only contiguous sequence")
        require(set(recorded).issubset({p.name for p in paths}),
                "A recorded capacity plan was removed")
        current = None
        for number, path in enumerate(paths, 1):
            require(path.is_file() and not path.is_symlink(), "Invalid capacity plan file")
            raw = path.read_bytes()
            checksum = hashlib.sha256(raw).hexdigest()
            require(path.name not in recorded or recorded[path.name] == checksum,
                    "A recorded capacity plan was modified")
            plan = json.loads(raw)
            require(plan.get("schema") == "otzaria.compiler-capacity-plan/1" and
                    plan.get("checkout_sha") == checkout_sha and plan.get("revision") == number,
                    "Capacity plan belongs to another source or revision")
            phase_authorized = plan.get("phase_authorized", True)
            require(type(phase_authorized) is bool, "Compiler phase admission must be a boolean")
            own = plan.get("compiler_remaining_bytes")
            margin = plan.get("margin_bytes")
            require(type(own) is int and own > 0 and type(margin) is int and margin > 0,
                    "Capacity plan must retain an explicit compiler forecast and margin")
            if own_forecast is None:
                own_forecast = own
            require(own == own_forecast, "Compiler forecast cannot be reduced while waiting")
            phases = plan.get("other_phases")
            require(isinstance(phases, list) and isinstance(plan.get("reason"), str) and
                    plan["reason"].strip(), "Capacity plan lacks its observed phase explanation")
            names = set()
            for phase in phases:
                require(set(phase) == {"phase", "remaining_bytes", "evidence"} and
                        isinstance(phase["phase"], str) and phase["phase"] and
                        phase["phase"] not in names and
                        type(phase["remaining_bytes"]) is int and phase["remaining_bytes"] >= 0 and
                        isinstance(phase["evidence"], str) and phase["evidence"].strip(),
                        "Capacity plan lacks an explicit phase forecast/evidence")
                names.add(phase["phase"])
            recorded[path.name] = checksum
            current = plan
        free = shutil.disk_usage(root).free
        required = own_forecast + current["margin_bytes"] + sum(
            phase["remaining_bytes"] for phase in current["other_phases"])
        observation = {
            "status": ("PHASE_ADMISSION_WAIT" if not current.get("phase_authorized", True) else
                       "CAPACITY_PASS" if free >= required else "CAPACITY_WAIT"),
            "phase_authorized": current.get("phase_authorized", True),
            "observed_at": datetime.now(timezone.utc).isoformat(),
            "checkout_sha": checkout_sha, "plan": str(paths[-1]),
            "plan_sha256": recorded[paths[-1].name], "recorded_plan_hashes": dict(recorded),
            "free_bytes": free, "required_bytes": required,
            "elapsed_seconds": round(time.monotonic() - started, 3),
            "compiler_or_ui_credit": False,
        }
        with observations.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(observation, sort_keys=True) + "\n")
            stream.flush()
        if current.get("phase_authorized", True) and free >= required:
            return observation
        require(time.monotonic() - started < maximum_wait_seconds,
                ("Compiler phase still awaits explicit admission; original preparation retained"
                 if not current.get("phase_authorized", True) else
                 "Measured compiler phase still does not fit; original preparation retained"))
        time.sleep(15)
