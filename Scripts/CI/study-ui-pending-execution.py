#!/usr/bin/env python3
"""Own the isolated original pending-fetch phase and its external lifetimes.

This module does not implement a source algorithm, seed app data, alter the
native selector or claim performance. It composes the real pending producer,
original URL transport and original native verifier supplied by the controller.
"""
from pathlib import Path
import os
import runpy
import subprocess
from types import SimpleNamespace


def require(value, message):
    if not value:
        raise ValueError(message)


class OwnedOriginalRunner:
    """Use the original commands with explicit lifetime proof for each group."""
    def __init__(self, core, output):
        self.core, self.output = core, Path(output)
        require(not self.output.exists(), "Use a fresh owned process receipt directory")
        self.output.mkdir()
        self.interruption = runpy.run_path(str(Path(core.ROOT) / "Scripts/CI/runtime27_interruption.py"))
        self.kernel = runpy.run_path(str(Path(core.ROOT) / "Scripts/CI/study-ui-offline-window.py"))
        self.rows, self.handles = [], {}

    def __getattr__(self, name):
        return getattr(self.core, name)

    def spawn(self, args, *, phase, **kwargs):
        require(len(self.rows) < 128 and isinstance(args, list) and args,
                "Bound the exact created command inventory")
        # This conservative in-memory row precedes Popen. An interrupted spawn
        # without its published handle cannot authorize later simulator handoff.
        row = {"phase": phase, "command": list(args), "startAttempted": True,
               "ownedPID": None, "cleanupAttempted": False, "verified": False,
               "parentPID": os.getpid(), "originalKernelIdentity": None, "receipt": None}
        self.rows.append(row)
        process = subprocess.Popen(args, start_new_session=True, **kwargs)
        row["ownedPID"] = process.pid
        self.handles[id(process)] = (process, row)
        self.current_identity(process, row)
        return process

    def current_identity(self, process, row):
        original_exit = process.poll()
        actual = self.kernel["process"](process.pid)
        if original_exit is not None:
            require(actual is None, "Refuse a live reused PID after the original child was reaped")
            return None
        if actual is None:
            require(process.poll() is not None, "A live original child has no verifiable kernel identity")
            return None
        require(actual.get("pid") == process.pid and actual.get("parentPID") == row["parentPID"],
                "Actual created process parent or PID differs")
        previous = row["originalKernelIdentity"]
        if previous is not None:
            require(all(actual.get(key) == previous.get(key) for key in ("pid", "parentPID", "startUTC")),
                    "Refuse a replaced original kernel process identity")
        # xcrun may exec the selected tool in the same owned process. Preserve
        # both actual command observations; PID/start/parent and original
        # unreaped Popen prove ownership through that normal exec transition.
        try:
            require(os.getpgid(process.pid) == process.pid, "The actual child is outside its created process group")
        except ProcessLookupError:
            require(process.poll() is not None and self.kernel["process"](process.pid) is None,
                    "Process-group identity vanished without an observed original exit")
            return None
        if process.poll() is not None:
            require(self.kernel["process"](process.pid) is None,
                    "Refuse a live PID after the original child exited during observation")
            return None
        if previous is None:
            row["originalKernelIdentity"] = actual
        row["lastVerifiedKernelIdentity"] = actual
        return actual

    def finish(self, process):
        require(id(process) in self.handles and self.handles[id(process)][0] is process,
                "Only a directly created owned process may be stopped")
        _, row = self.handles[id(process)]
        require(not row["cleanupAttempted"], "Do not repeat an uncertain process-group cleanup")
        row["cleanupAttempted"] = True
        index = next(i for i, candidate in enumerate(self.rows) if candidate is row)
        path = self.output / (str(index + 1).zfill(3) + "-cleanup.json")
        try:
            def guarded_killpg(pgid, kind):
                require(pgid == process.pid, "Only this original created group may be probed or signaled")
                identity = self.current_identity(process, row)
                if identity is None and kind != 0:
                    # An absent reaped leader cannot identify a remaining
                    # group. Observe absence only; never adopt/signal an
                    # uncertain surviving or recycled group.
                    try:
                        os.killpg(pgid, 0)
                    except ProcessLookupError:
                        raise
                    raise ValueError("A remaining group has no verifiable original live leader")
                return os.killpg(pgid, kind)
            row["originalCleanup"] = self.interruption["stop_owned_process_group"](
                process, killpg_fn=guarded_killpg)
            row["leaderExit"] = process.poll()
            row["verified"] = (row["leaderExit"] is not None
                and row["originalCleanup"].get("owned_pgid") == process.pid
                and row["originalCleanup"].get("group_state") == "GONE_CHECKED"
                and not row["originalCleanup"].get("probe_errors")
                and not row["originalCleanup"].get("send_errors"))
        except BaseException as error:
            row["errorType"] = type(error).__name__
            raise
        finally:
            # The receipt excludes itself; only a successful actual write can
            # establish its immutable witness. ENOSPC leaves receipt=None.
            self.core.write(path, {key: value for key, value in row.items() if key != "receipt"})
            row["receipt"] = self.core.witness(path)
        require(row["verified"], "Owned command process group remains unverified")
        return row["receipt"]

    def bounded(self, args, log, timeout, env=None):
        process = None
        with Path(log).open("w") as handle:
            try:
                process = self.spawn(args, phase="bounded-original-command", cwd=self.core.ROOT,
                    env=env, text=True, stdout=handle, stderr=subprocess.STDOUT)
                return process.wait(timeout=timeout)
            finally:
                if process is not None:
                    self.finish(process)

    def command(self, args, timeout=90, check=True):
        process = None
        try:
            process = self.spawn(args, phase="original-command", cwd=self.core.ROOT,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout, stderr = process.communicate(timeout=timeout)
            result = subprocess.CompletedProcess(args, process.returncode, stdout, stderr)
            if check:
                require(result.returncode == 0, "Original command failed: " + str(args[0]))
            return result
        finally:
            if process is not None:
                self.finish(process)
                # communicate() has no background Python reader here. Close
                # only after positive evidence that the owned group is gone.
                for pipe in (process.stdout, process.stderr):
                    if pipe is not None:
                        pipe.close()

    def original_url_class(self):
        cls = runpy.run_path(str(Path(self.core.ROOT) / "Scripts/CI/runtime27-url-delivery.py"))["NativeURLDelivery"]
        # run_path gives this class a private globals dictionary. Change only
        # its Popen factory to establish a new owned group; the shared Python
        # subprocess module and original transport source remain untouched.
        proxy = SimpleNamespace(**vars(subprocess))
        proxy.Popen = lambda args, **kwargs: self.spawn(args, phase="original-url-transport", **kwargs)
        cls.start.__globals__["subprocess"] = proxy
        return cls

    def verify_exits(self):
        return all(row["verified"] is True and row["receipt"] is not None for row in self.rows)

    def finish_unfinished_handles(self):
        """Cover an interruption between spawn's return and caller assignment."""
        errors = []
        for process, row in tuple(self.handles.values()):
            if row["cleanupAttempted"]:
                continue
            try:
                self.finish(process)
            except BaseException as error:
                errors.append({"ownedPID": process.pid, "errorType": type(error).__name__})
        return errors


class PendingStudyCase:
    """A single registered native case; stop every owner before retention."""
    def __init__(self, *, core, settings, pending, config, udid, container,
                 installation, output, reserved_other_bytes):
        self.core, self.settings, self.pending = core, settings, pending
        self.wait = pending.load_wait(core.ROOT)
        self.config, self.udid, self.container = config, udid, Path(container)
        self.installation, self.output = installation, Path(output)
        self.reserved_other_bytes = reserved_other_bytes
        self.runner = OwnedOriginalRunner(core, self.output / "pending-owned-processes")
        self.observer = self.delivery = None
        self.delivery_start_attempted = self.observer_stop_attempted = self.delivery_stop_attempted = False
        self.host_result = self.host_error = self.url_error = None
        self.cleanup_state = self.cleanup_receipt = None
        self.cleanup_verified = False
        self.closed = False
        self.token = ""

    def start(self):
        require(self.observer is None and self.delivery is None and not self.closed,
                "Start this single original phase once")
        catalog_dir = self.output / "pending-source-catalog"
        catalog = self.pending.prepare_catalog(self.runner, self.config, self.installation,
            catalog_dir, reserved_other_bytes=self.reserved_other_bytes)
        # Keep the existing collector on its original core. Its bounded MCM
        # and image observations belong to the joined observer/writer lifetime,
        # not the finite native/compiler/export command inventory below.
        self.observer = self.pending.PendingSQLHost(self.core, self.udid, self.container,
            self.installation, catalog_dir, catalog)
        self.token = self.observer.host.token
        self.delivery = self.runner.original_url_class()(self.udid, self.container, "full-v32", self.output)
        self.delivery_start_attempted = True
        environment = self.delivery.start()
        environment.update(self.observer.start())
        environment.update(TEST_RUNNER_READER_OBSERVATION_CORPUS="full-v40",
            TEST_RUNNER_FAITHFUL_PRODUCTION_WORKSPACE_FILE=str(
                self.container / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"))
        return environment

    def private_tokens(self):
        return tuple(value for value in (self.token, getattr(self.delivery, "token", None)) if value)

    def close(self):
        if self.closed:
            return self.cleanup_receipt
        self.closed = True
        # An acceptance exception is separate from an actual thread-stop error.
        # A failed native cohort may safely exit without becoming a UI pass.
        if self.observer is not None:
            self.observer_stop_attempted = True
            try:
                self.host_result = self.observer.stop()
            except BaseException as error:
                self.host_error = {"type": type(error).__name__, "message": str(error)}
        if self.delivery is not None:
            self.delivery_stop_attempted = True
            try:
                self.delivery.stop()
            except BaseException as error:
                self.url_error = {"type": type(error).__name__, "message": str(error)}
            finally:
                process = self.delivery.process
                if process is not None:
                    try:
                        self.runner.finish(process)
                    except BaseException as error:
                        self.url_error = {"type": type(error).__name__, "message": str(error)}
        sweep_errors = self.runner.finish_unfinished_handles()
        observer_state = self.observer.cleanup_state if self.observer is not None else None
        observer_receipt = self.observer.cleanup_receipt if self.observer is not None else None
        observer_verified = self.observer is None or (
            self.observer.owned_activity_exited is True and observer_receipt is not None
            and isinstance(observer_state, dict) and observer_state.get("stopError") is None
            and observer_state.get("originalObserverThreadExited") is True
            and observer_state.get("passiveProbeWriterExited") is True)
        url_verified = not self.delivery_start_attempted or (
            self.delivery is not None and self.delivery.process is not None
            and self.delivery.process.poll() is not None and self.url_error is None)
        verified = observer_verified and url_verified and self.runner.verify_exits() and not sweep_errors
        self.cleanup_state = {"schema": "otzaria.original-pending-phase-cleanup/1",
            "verified": verified, "observerCleanup": observer_receipt,
            "observerState": observer_state, "observerAcceptanceError": self.host_error,
            "observerConstructed": self.observer is not None,
            "urlStartAttempted": self.delivery_start_attempted, "urlStopAttempted": self.delivery_stop_attempted,
            "urlPID": self.delivery.process.pid if self.delivery is not None and self.delivery.process is not None else None,
            "urlExit": self.delivery.process.poll() if self.delivery is not None and self.delivery.process is not None else None,
            "urlError": self.url_error, "ownedProcesses": self.runner.rows,
            "unfinishedHandleCleanupErrors": sweep_errors,
            "simulatorRetentionPerformed": False, "nativeAcceptance": False,
            "scope": "Actual owned external process groups, original URL host and observer/writer cleanup only"}
        # Keep conservative memory first. A seal failure cannot authorize
        # simulator retention even if the observed processes have exited.
        self.cleanup_receipt = self.wait.seal(self.output / "pending-phase-cleanup.json", self.cleanup_state)
        self.cleanup_verified = verified
        return self.cleanup_receipt

    def stop(self):
        self.close()
        require(self.cleanup_verified, "Owned pending-phase cleanup is unverified")
        require(self.host_result is not None and self.host_error is None,
                "Original pending-fetch host did not complete all three actual cohorts")
        return {"host": self.host_result,
            "hostResult": self.wait.witness(self.output / "pending-fetch-correctness/RESULT.json"),
            "hostInputs": self.wait.witness(self.output / "pending-fetch-correctness/INPUTS.json"),
            "sourceExecution": self.wait.witness(self.output / "pending-source-catalog/execution-result.json"),
            "cleanup": self.cleanup_receipt, "fullPerformanceAcceptance": False}

    def abort(self):
        self.close()
        return {"verified": self.cleanup_verified, "cleanup": self.cleanup_receipt,
                "state": self.cleanup_state, "nativeAcceptance": False}


def validate_cleanup(value, evidence, root_report):
    """Re-read every owned-exit receipt before allowing the later update."""
    require(isinstance(value, dict) and value.get("fullPerformanceAcceptance") is False,
            "A pending native correctness phase cannot imply a performance pass")
    native = root_report.get("case_results")
    require(isinstance(native, list) and len(native) == 1 and native[0].get("passed") is True,
            "Bind cleanup to the one independently verified original native case")
    native = native[0]
    directory = Path(native["case_directory"]).parent
    require(value["cleanup"]["path"] == str(directory / "pending-phase-cleanup.json"),
            "Pending cleanup belongs to another phase directory")
    state = evidence.read_witness(value["cleanup"])
    require(state.get("schema") == "otzaria.original-pending-phase-cleanup/1"
            and state.get("verified") is True and state.get("observerConstructed") is True
            and state.get("observerAcceptanceError") is None and state.get("urlError") is None
            and state.get("unfinishedHandleCleanupErrors") == []
            and state.get("urlStartAttempted") is True and state.get("urlStopAttempted") is True
            and type(state.get("urlPID")) is int and type(state.get("urlExit")) is int,
            "The actual pending phase's full cleanup is missing")
    require(state["observerCleanup"]["path"] == str(directory / "pending-fetch-cleanup.json"),
            "Observer cleanup belongs to another phase directory")
    observed = evidence.read_witness(state["observerCleanup"])
    require(observed == state["observerState"] and observed.get("ownedActivityExited") is True
            and observed.get("stopError") is None and observed.get("originalObserverThreadExited") is True
            and observed.get("passiveProbeWriterExited") is True,
            "Original observer/writer cleanup bytes disagree or are incomplete")
    rows = state.get("ownedProcesses")
    require(isinstance(rows, list) and 0 < len(rows) <= 128,
            "The original owned native/export/URL command inventory is missing")
    for row in rows:
        require(Path(row["receipt"]["path"]).parent == directory / "pending-owned-processes",
                "An external cleanup receipt belongs to another original phase")
        actual = evidence.read_witness(row["receipt"])
        require(actual == {key: item for key, item in row.items() if key != "receipt"}
                and row.get("verified") is True and row.get("cleanupAttempted") is True
                and type(row.get("leaderExit")) is int
                and row.get("originalCleanup", {}).get("group_state") == "GONE_CHECKED"
                and row["originalCleanup"].get("owned_pgid") == row.get("ownedPID")
                and not row["originalCleanup"].get("probe_errors")
                and not row["originalCleanup"].get("send_errors"),
                "An owned original command lacks actual process-group exit proof")
    require(sum(row.get("phase") == "original-url-transport" and row.get("ownedPID") == state["urlPID"] for row in rows) == 1
            and sum(row.get("command") == native.get("command")
                    and row.get("command", [None])[0] == "xcodebuild"
                    and row.get("leaderExit") == native.get("xcodebuild_exit") == 0 for row in rows) == 1,
            "Bind both the real URL transport and native test process group")
    return {"cleanup": value["cleanup"], "observerCleanup": state["observerCleanup"],
            "ownedProcessReceipts": [row["receipt"] for row in rows]}
