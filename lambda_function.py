import json

from shared.db import get_connection
from request_handler import parse_request
from routing import dispatch_rest


def handler(event, context):
    return handle_rest(event, context)


def handle_rest(event, context):
    method = event.get("httpMethod", "?")
    path = event.get("path", "?")
    if method == "OPTIONS":
        return response(200, None)
    try:
        req = parse_request(event)
        method, path = req["method"], req["path"]
        print(f"[REQUEST] {method} {path}")
        with get_connection() as conn:
            status, data = dispatch_rest(
                method=req["method"],
                path=req["path"],
                obj=req["body"],
                connection=conn,
            )
        code = {"success": 200, "created": 201}.get(status, 200)
        return response(code, data)
    except LookupError as e:
        print(f"[NOT_FOUND] {method} {path}: {e}")
        return response(404, {"message": str(e) or "Not found"})
    except ValueError as e:
        print(f"[BAD_REQUEST] {method} {path}: {e}")
        return response(400, {"message": str(e)})
    except Exception as e:
        print(f"[ERROR] Unhandled {method} {path}: {e}")
        return response(500, {"message": "Internal server error"})


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=str) if body is not None else "",
    }
