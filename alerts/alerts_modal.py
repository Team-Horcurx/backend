from datetime import datetime

from sqlalchemy import text


def _row(r):
    return {
        "id": r["id"],
        "severity": r["severity"],
        "text": r["text"],
        "ward_id": r["ward_id"],
        "created_at": r["created_at"].isoformat() + "Z" if isinstance(r["created_at"], datetime) else r["created_at"],
    }


def list_by_ward(conn, ward_id):
    rows = conn.execute(
        text("SELECT id, ward_id, severity, text, created_at FROM alerts WHERE ward_id = :ward_id ORDER BY created_at DESC"),
        {"ward_id": ward_id},
    ).mappings().all()
    return [_row(r) for r in rows]


def list_all(conn):
    rows = conn.execute(
        text("SELECT id, ward_id, severity, text, created_at FROM alerts ORDER BY created_at DESC")
    ).mappings().all()
    return [_row(r) for r in rows]
