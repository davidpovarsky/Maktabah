import datetime, hashlib, json, os, urllib.error, urllib.request
from pathlib import Path

URL = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
MODEL = "gemini-2.5-flash-lite"
OUT = Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-root-20261122\live9-provider-access-preflight")
OUT.mkdir(exist_ok=False)
request_body = {"model": MODEL, "messages": [{"role": "user", "content": "Reply with exactly OK."}], "max_tokens": 8, "temperature": 0}
payload = json.dumps(request_body, separators=(",", ":")).encode()
(OUT / "request.json").write_bytes(payload)
receipt = {"scope": "One direct configured-provider availability diagnostic; no native app, tool calls, source corpus or Live acceptance.", "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "url": URL, "model": MODEL, "request_sha256": hashlib.sha256(payload).hexdigest(), "http_requests": 0, "credential_source": "existing process GEMINI_API_KEY", "credential_value_or_hash_recorded": False, "native_acceptance": False, "new_repository_secret_created": False}
key = os.environ.get("GEMINI_API_KEY")
assert isinstance(key, str) and 20 <= len(key) <= 4096 and all(32 < ord(c) < 127 for c in key), "Known configured provider key unavailable"

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

try:
    request = urllib.request.Request(URL, data=payload, method="POST", headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    receipt["http_requests"] = 1
    try:
        response = urllib.request.build_opener(NoRedirect()).open(request, timeout=45)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        receipt["http_status"] = response.code
        raw = response.read(65537)
    if len(raw) > 65536:
        raise RuntimeError("Provider diagnostic response exceeded its retained bound")
    clean = raw.replace(key.encode(), b"[REDACTED_KNOWN_PROVIDER_KEY]")
    assert key.encode() not in clean
    (OUT / "response.redacted.json").write_bytes(clean)
    receipt["retained_response_sha256"] = hashlib.sha256(clean).hexdigest()
    parsed = json.loads(clean)
    if receipt["http_status"] == 200:
        choices = parsed.get("choices", [])
        receipt["response_model"] = parsed.get("model")
        receipt["choices"] = len(choices)
        receipt["exact_constant_reply"] = len(choices) == 1 and choices[0].get("message", {}).get("content", "").strip() == "OK"
        receipt["usage"] = parsed.get("usage")
        receipt["status"] = "CONFIGURED_PROVIDER_REQUEST_SUCCEEDED" if receipt["exact_constant_reply"] else "HTTP_SUCCESS_CONSTANT_REPLY_NOT_CONFIRMED"
    else:
        error = parsed.get("error", {})
        receipt["status"] = "PROVIDER_HTTP_ERROR"
        receipt["provider_error"] = {k: error.get(k) for k in ["code", "status", "message"]}
except Exception as error:
    receipt["status"] = "DIAGNOSTIC_FAILED"
    receipt["error_type"] = type(error).__name__
finally:
    key = None
    receipt["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (OUT / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt))
