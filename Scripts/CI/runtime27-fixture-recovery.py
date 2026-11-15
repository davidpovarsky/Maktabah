"""Narrow recovery eligibility; never turn provisioning into UI acceptance."""


def verified_fixture_cleanup_timeout(fixture, termination, attempt):
    return (attempt == 0 and fixture.get("passed") is True
            and fixture.get("profileID") == "miniTest10"
            and fixture.get("bookCount", 0) >= 10 and fixture.get("shaMatched") is True
            and termination.get("status") == "TIMEOUT"
            and termination.get("nativeValidationFailurePreserved") is False)
