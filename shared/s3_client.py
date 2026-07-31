import csv
import io
import json
import os
from datetime import datetime

import boto3

_s3 = None


def _client():
    global _s3
    if _s3 is None:
        _s3 = boto3.client("s3", region_name=os.environ.get("AWS_REGION", "ap-south-1"))
    return _s3


def _bucket():
    bucket = os.environ.get("S3_BUCKET")
    if not bucket:
        raise RuntimeError("S3_BUCKET environment variable not set")
    return bucket


def presigned_get(key: str, expires_in: int = 900) -> str:
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": _bucket(), "Key": key},
        ExpiresIn=expires_in,
    )


def upload_json(key: str, data) -> None:
    body = json.dumps(data).encode("utf-8")
    _client().put_object(Bucket=_bucket(), Key=key, Body=body, ContentType="application/json")


def upload_csv(prefix: str, rows: list[dict]) -> str:
    """Writes rows to a timestamped CSV under `prefix/`, returns the S3 key."""
    buf = io.StringIO()
    if rows:
        writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    key = f"{prefix}/export-{datetime.utcnow().strftime('%Y%m%dT%H%M%S')}.csv"
    _client().put_object(Bucket=_bucket(), Key=key, Body=buf.getvalue().encode("utf-8"), ContentType="text/csv")
    return key
