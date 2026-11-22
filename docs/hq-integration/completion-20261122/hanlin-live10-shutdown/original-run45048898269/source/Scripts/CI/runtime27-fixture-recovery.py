"""Narrow recovery eligibility; never turn provisioning into UI acceptance."""
import re


def transient_fixture_download_failure(fixture, attempt):
    """Retry the same native installer once; keep its original failed report."""
    errors = fixture.get("errors")
    return (attempt == 0 and fixture.get("passed") is False
            and fixture.get("profileID") == "miniTest10" and fixture.get("phase") == "install"
            and isinstance(errors, list) and bool(errors)
            and all(isinstance(error, str) and (
                re.search(r"\bHTTP (502|503|504)\b", error)
                # Run44559352638 window provisioning failed before downloading
                # any bytes with this native URLSession DNS error. A second
                # failure still fails the job; no hash/data check is bypassed.
                or error == "A server with the specified hostname could not be found.")
                for error in errors))


def verified_fixture_cleanup_timeout(fixture, termination, attempt):
    return (attempt == 0 and fixture.get("passed") is True
            and fixture.get("profileID") == "miniTest10"
            and fixture.get("bookCount", 0) >= 10 and fixture.get("shaMatched") is True
            and termination.get("status") == "TIMEOUT"
            and termination.get("nativeValidationFailurePreserved") is False)
