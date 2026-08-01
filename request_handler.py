import base64
import csv
import io
import json
import uuid
from datetime import datetime, timezone


def parse_request(event):
    method = event.get("httpMethod", "GET")
    path = event.get("path", "/")
    query = event.get("queryStringParameters") or {}
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    content_type = headers.get("content-type", "")

    body_raw = event.get("body") or ""
    is_b64 = event.get("isBase64Encoded", False)

    obj = dict(query)

    if "multipart/form-data" in content_type:
        raw_bytes = base64.b64decode(body_raw) if is_b64 else body_raw.encode("utf-8")
        obj["_csv_rows"] = _parse_csv_multipart(raw_bytes, content_type)
    elif body_raw:
        try:
            text = base64.b64decode(body_raw).decode("utf-8") if is_b64 else body_raw
            parsed = json.loads(text)
            if isinstance(parsed, dict):
                obj.update(parsed)
        except (json.JSONDecodeError, UnicodeDecodeError):
            pass

    return {"method": method, "path": path, "body": obj}


def _parse_csv_multipart(raw_bytes: bytes, content_type: str) -> list[dict]:
    boundary = content_type.split("boundary=")[-1].strip().strip('"')
    delimiter = ("--" + boundary).encode()
    parts = raw_bytes.split(delimiter)

    csv_text = None
    for part in parts:
        part = part.strip(b"\r\n")
        if not part or part == b"--":
            continue
        if b"\r\n\r\n" not in part:
            continue
        header_bytes, content = part.split(b"\r\n\r\n", 1)
        header_text = header_bytes.decode("utf-8", errors="ignore")
        if "filename=" in header_text:
            content = content.rstrip(b"\r\n-")
            csv_text = content.decode("utf-8", errors="ignore")
            break

    if csv_text is None:
        raise ValueError("No file part found in multipart upload")

    reader = csv.DictReader(io.StringIO(csv_text))
    rows = []
    for row in reader:
        rows.append({
            "id": row.get("property_id") or row.get("id") or str(uuid.uuid4()),
            "ward_id": row["ward_id"],
            "lat": float(row["lat"]),
            "lng": float(row["lng"]),
            "address": row.get("address"),
            "pincode": row.get("pincode"),
            "property_type": row.get("property_type"),
            "area_sqm": int(float(row["area_sqm"])),
            "detection_type": row["detection_type"],
            "confidence": float(row["confidence"]),
            "confidence_breakdown": row.get("confidence_breakdown") or "{}",
            "ndbi_delta": float(row["ndbi_delta"]) if row.get("ndbi_delta") else None,
            "area_delta": float(row["area_delta"]) if row.get("area_delta") else None,
            "ndvi_drop": float(row["ndvi_drop"]) if row.get("ndvi_drop") else None,
            "osm_status": float(row["osm_status"]) if row.get("osm_status") else None,
            "db_match": float(row["db_match"]) if row.get("db_match") else None,
            "baseline_year": int(row["baseline_year"]) if row.get("baseline_year") else None,
            "comparison_year": int(row["comparison_year"]) if row.get("comparison_year") else None,
            "detected_at": row.get("detected_at") or datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            "s3_geojson_key": row.get("s3_geojson_key"),
            "status": row.get("status") or "pending",
            "estimated_annual_tax_inr": int(float(row["estimated_annual_tax_inr"])) if row.get("estimated_annual_tax_inr") else None,
            "owner_name": row.get("owner_name"),
        })
    return rows
