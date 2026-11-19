#!/usr/bin/env python3
"""Safe, read-only Meshy API credential check. Never prints the API key or balance."""
import json
import os
import sys
import urllib.error
import urllib.request

key = os.environ.get("MESHY_API_KEY", "")
if not key:
    print("MESHY_HTTP_STATUS: NOT_SENT")
    print("MESHY_CHECK_ERROR: MESHY_API_KEY is missing from this job environment")
    sys.exit(2)

request = urllib.request.Request(
    "https://api.meshy.ai/openapi/v1/balance",
    headers={"Authorization": f"Bearer {key}", "Accept": "application/json"},
    method="GET",
)
try:
    with urllib.request.urlopen(request, timeout=25) as response:
        status = response.status
        body = response.read(65536)
except urllib.error.HTTPError as exc:
    status = exc.code
    body = exc.read(65536)
except Exception as exc:
    print("MESHY_HTTP_STATUS: NO_HTTP_RESPONSE")
    print(f"MESHY_NETWORK_ERROR: {type(exc).__name__}")
    sys.exit(3)

print(f"MESHY_HTTP_STATUS: {status}")
try:
    payload = json.loads(body.decode("utf-8", errors="replace"))
    if status == 200:
        print("MESHY_AUTH_CHECK: ACCEPTED")
    else:
        message = payload.get("message") if isinstance(payload, dict) else None
        if message:
            safe_message = str(message).replace("\\n", " ")[:400]
            print(f"MESHY_ERROR_MESSAGE: {safe_message}")
        else:
            print("MESHY_ERROR_MESSAGE: response did not include a message field")
except Exception:
    print("MESHY_RESPONSE: non-JSON response (body suppressed)")
sys.exit(0 if status == 200 else 1)
