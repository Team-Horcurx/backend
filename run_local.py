"""Lightweight local dev server — no SAM/Docker required.

Wraps incoming HTTP requests into API-Gateway-proxy-shaped events and calls
lambda_function.handler directly, so the exact same code path deploys to Lambda.

Usage:
    set -a; source .env; set +a   # or use python-dotenv manually
    python run_local.py
"""
import base64
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

import lambda_function


class Handler(BaseHTTPRequestHandler):
    def _handle(self, method):
        parsed = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(parsed.query).items()}
        length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(length) if length else b""

        content_type = self.headers.get("Content-Type", "")
        is_multipart = "multipart/form-data" in content_type

        event = {
            "httpMethod": method,
            "path": parsed.path,
            "queryStringParameters": query or None,
            "headers": dict(self.headers.items()),
            "body": base64.b64encode(raw_body).decode() if is_multipart else raw_body.decode("utf-8", errors="ignore"),
            "isBase64Encoded": is_multipart,
        }

        result = lambda_function.handler(event, None)

        self.send_response(result["statusCode"])
        for k, v in result.get("headers", {}).items():
            self.send_header(k, v)
        self.end_headers()
        body = result.get("body", "")
        self.wfile.write(body.encode("utf-8") if isinstance(body, str) else body)

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_OPTIONS(self):
        self._handle("OPTIONS")

    def log_message(self, fmt, *args):
        print(f"[{self.address_string()}] {fmt % args}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"GVMC backend local dev server running on http://localhost:{port}")
    server.serve_forever()
