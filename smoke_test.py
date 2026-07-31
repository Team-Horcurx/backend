"""Pre-flight smoke test — not part of the deployed Lambda, run manually before
`sam deploy`. Verifies all modules import cleanly and the routing table /
request parsing behave correctly, without needing a real database connection
(SQLAlchemy engines are lazy — no network call happens until a query runs).

Usage: python smoke_test.py
"""
import os
import sys

os.environ.setdefault("DB_URL", "mysql+pymysql://user:pass@localhost:3306/gvmc")
os.environ.setdefault("S3_BUCKET", "gvmc-sw14-data")
os.environ.setdefault("AWS_REGION", "ap-south-1")
os.environ.setdefault("BEDROCK_REGION", "us-east-1")

import lambda_function  # noqa: E402 — verifies get_engine() + all service module imports resolve
import routing  # noqa: E402
import request_handler  # noqa: E402

print("[OK] lambda_function, routing, request_handler imported cleanly")

# --- routing table checks -------------------------------------------------
import re

TEST_CASES = [
    ("GET", "/api/wards", {}),
    ("GET", "/api/wards/4/changes", {"wardId": "4"}),
    ("GET", "/api/wards/4/unassessed", {"wardId": "4"}),
    ("GET", "/api/wards/4/alerts", {"wardId": "4"}),
    ("GET", "/api/properties/prop-w1-001", {"id": "prop-w1-001"}),
    ("POST", "/api/properties/prop-w1-001/verify", {"id": "prop-w1-001"}),
    ("GET", "/api/stats", {}),
    ("GET", "/api/stats/all-wards", {}),
    ("POST", "/api/alerts/export", {}),
    ("POST", "/api/chat", {}),
    ("POST", "/api/admin/upload-csv", {}),
    ("POST", "/api/admin/db-config", {}),
    ("POST", "/api/admin/refresh", {}),
]

failures = []
for method, path, expected_params in TEST_CASES:
    matched = None
    for route_method, pattern, handler_fn, param_names in routing.ROUTES:
        if route_method != method:
            continue
        m = re.fullmatch(pattern, path)
        if m:
            matched = (handler_fn, {name: m.group(name) for name in param_names})
            break
    if matched is None:
        failures.append(f"NO MATCH: {method} {path}")
        continue
    handler_fn, params = matched
    if params != expected_params:
        failures.append(f"PARAM MISMATCH: {method} {path} -> got {params}, expected {expected_params}")
    else:
        print(f"[OK] {method:5s} {path:40s} -> {handler_fn.__self__.__class__.__name__}.{handler_fn.__name__} {params}")

# also confirm a wrong method/path correctly raises "not found"
try:
    routing.dispatch_rest("GET", "/api/does-not-exist", {}, None)
    failures.append("Expected ValueError for unknown route, got none")
except ValueError:
    print("[OK] unknown route raises ValueError as expected")

# --- request_handler checks ------------------------------------------------
json_event = {
    "httpMethod": "POST",
    "path": "/api/properties/prop-w1-001/verify",
    "queryStringParameters": None,
    "headers": {"Content-Type": "application/json"},
    "body": '{"status": "verified", "notes": "looks good", "updated_by": "officer1"}',
    "isBase64Encoded": False,
}
req = request_handler.parse_request(json_event)
assert req["body"]["status"] == "verified", req
assert req["body"]["updated_by"] == "officer1", req
print("[OK] parse_request handles JSON body correctly")

query_event = {
    "httpMethod": "GET",
    "path": "/api/wards/4/unassessed",
    "queryStringParameters": {"type": "new_build", "status": "pending"},
    "headers": {},
    "body": "",
    "isBase64Encoded": False,
}
req2 = request_handler.parse_request(query_event)
assert req2["body"]["type"] == "new_build", req2
assert req2["body"]["status"] == "pending", req2
print("[OK] parse_request handles query params correctly")

import base64
csv_content = "id,ward_id,lat,lng,area_sqm,detection_type,confidence\nprop-x-1,1,17.7,83.3,200,new_build,0.8\n"
boundary = "----testboundary"
body = (
    f"--{boundary}\r\n"
    f'Content-Disposition: form-data; name="file"; filename="upload.csv"\r\n'
    f"Content-Type: text/csv\r\n\r\n"
    f"{csv_content}\r\n"
    f"--{boundary}--\r\n"
).encode("utf-8")
multipart_event = {
    "httpMethod": "POST",
    "path": "/api/admin/upload-csv",
    "queryStringParameters": None,
    "headers": {"Content-Type": f"multipart/form-data; boundary={boundary}"},
    "body": base64.b64encode(body).decode(),
    "isBase64Encoded": True,
}
req3 = request_handler.parse_request(multipart_event)
rows = req3["body"]["_csv_rows"]
assert len(rows) == 1, rows
assert rows[0]["ward_id"] == "1", rows
assert rows[0]["area_sqm"] == 200, rows
print(f"[OK] parse_request handles multipart CSV correctly: {rows}")

if failures:
    print("\n=== FAILURES ===")
    for f in failures:
        print(" -", f)
    sys.exit(1)
else:
    print("\nALL SMOKE TESTS PASSED")
