#!/usr/bin/env python3
"""Shared bounded interruption and owned-target cleanup helpers for R27 runners.

Stops only explicitly owned process groups, subprocesses, and disposable
simulator UDIDs. Never executes generic process kills or asserts complete
external CoreSimulator agent cleanup from Python-side teardown alone.
"""
import os
import signal
import subprocess
import sys
import time

INTERRUPTED_PROCESS_GRACE_SECONDS = 1.0
INTERRUPTED_PROCESS_KILL_WAIT_SECONDS = 0.5
INTERRUPTED_SIM_SHUTDOWN_TIMEOUT = 5
INTERRUPTED_SIM_DELETE_TIMEOUT = 5


class InterruptController:
    """Coordinate SIGINT/SIGTERM conversion without aborting final receipt writes."""

    def __init__(self):
        self.interrupted = False
        self.cleanup_active = False
        self.signal_number = None
        self.signal_name = None
        self.repeat_signals = 0
        self._previous_handlers = {}

    def install(self):
        for sig in (signal.SIGINT, signal.SIGTERM):
            self._previous_handlers[sig] = signal.getsignal(sig)
            signal.signal(sig, self._handle_signal)
        return self

    def restore(self):
        for sig, previous in self._previous_handlers.items():
            try:
                signal.signal(sig, previous)
            except (OSError, ValueError):
                pass
        self._previous_handlers.clear()

    def mark_interrupted(self, error=None):
        self.interrupted = True
        if error is not None and self.signal_name is None:
            self.signal_name = type(error).__name__

    def _handle_signal(self, signum, _frame):
        if self.interrupted or self.cleanup_active:
            self.repeat_signals += 1
            return
        self.interrupted = True
        self.signal_number = signum
        try:
            self.signal_name = signal.Signals(signum).name
        except ValueError:
            self.signal_name = str(signum)
        raise KeyboardInterrupt(f"External signal {signum}; UI acceptance remains unverified")


def stop_owned_process_group(
    process,
    grace_seconds=5,
    kill_wait_seconds=2,
    killpg_fn=None,
    sleep_fn=time.sleep,
    monotonic_fn=time.monotonic,
):
    """Observe and stop only the created process group independently of leader exit."""
    pgid = process.pid
    killpg = killpg_fn or getattr(os, "killpg", None)
    probe_errors = []
    send_errors = []

    def alive():
        process.poll()  # Reap the leader if it exited; children may still exist.
        if killpg is None:
            return process.poll() is None
        try:
            killpg(pgid, 0)
            return True
        except ProcessLookupError:
            return False
        except OSError as error:
            # Do not mistake a transient probe failure (e.g. PermissionError)
            # for group exit and thereby skip the bounded SIGKILL fallback.
            probe_errors.append(type(error).__name__)
            return True

    def send(kind):
        if killpg is None:
            return
        try:
            killpg(pgid, kind)
        except ProcessLookupError:
            pass
        except OSError as error:
            send_errors.append((int(kind), type(error).__name__))

    def wait_gone(seconds):
        end = monotonic_fn() + seconds
        while alive():
            if monotonic_fn() >= end:
                return False
            sleep_fn(0.05)
        return True

    send(signal.SIGINT)
    gone = wait_gone(grace_seconds)
    if not gone:
        send(getattr(signal, "SIGKILL", signal.SIGTERM))
        gone = wait_gone(kill_wait_seconds)
    result = {
        "owned_pgid": pgid,
        "group_state": "GONE_CHECKED" if (gone and not send_errors) else "STILL_PRESENT_UNVERIFIED",
        "off_group_simulator_agents": "NOT_INDEPENDENTLY_VERIFIED",
    }
    if probe_errors:
        result["probe_errors"] = probe_errors
    if send_errors:
        result["send_errors"] = [{"signal": sig, "error": err} for sig, err in send_errors]
    return result


def stop_owned_subprocess(
    process,
    grace_seconds=INTERRUPTED_PROCESS_GRACE_SECONDS,
    kill_wait_seconds=INTERRUPTED_PROCESS_KILL_WAIT_SECONDS,
    prefer_sigint=False,
):
    """Stop one directly spawned owned subprocess without killing unrelated processes."""
    if process is None:
        return None
    pid = getattr(process, "pid", None)
    try:
        if process.poll() is not None:
            return {"pid": pid, "state": "EXITED", "returncode": process.returncode}
    except OSError as error:
        return {"pid": pid, "state": "UNVERIFIED", "error": type(error).__name__}

    state = "TERMINATED"
    try:
        if prefer_sigint and sys.platform != "win32":
            process.send_signal(signal.SIGINT)
        else:
            process.terminate()
    except ProcessLookupError:
        return {"pid": pid, "state": "EXITED"}
    except (OSError, ValueError) as error:
        return {"pid": pid, "state": "UNVERIFIED", "error": type(error).__name__}

    try:
        process.wait(timeout=grace_seconds)
        return {"pid": pid, "state": state, "returncode": process.poll()}
    except subprocess.TimeoutExpired:
        state = "KILLED"
    except OSError as error:
        return {"pid": pid, "state": "UNVERIFIED", "error": type(error).__name__}

    try:
        process.kill()
        process.wait(timeout=kill_wait_seconds)
        return {"pid": pid, "state": state, "returncode": process.poll()}
    except ProcessLookupError:
        return {"pid": pid, "state": "EXITED"}
    except (subprocess.TimeoutExpired, OSError) as error:
        return {"pid": pid, "state": "STILL_PRESENT_UNVERIFIED", "error": type(error).__name__}


def run_isolated_cleanup_step(name, action, errors):
    """Run one owned cleanup callback without letting its failure block later steps."""
    try:
        return action()
    except (Exception, KeyboardInterrupt) as error:
        errors[name] = f"{type(error).__name__}: {error}"
        return None
