import json
from datetime import datetime, timezone

from sqlalchemy import text

_COLUMNS = """
    id, ward_id, lat, lng, address, pincode, property_type, area_sqm, detection_type,
    confidence, confidence_breakdown, ndbi_delta, area_delta, ndvi_drop, osm_status, db_match,
    baseline_year, comparison_year, detected_at, s3_geojson_key, status,
    estimated_annual_tax_inr, owner_name, ai_explanation
"""


def _row_to_property(r):
    cb = r["confidence_breakdown"]
    if isinstance(cb, str):
        cb = json.loads(cb)
    return {
        "id": r["id"],
        "ward_id": r["ward_id"],
        "lat": float(r["lat"]),
        "lng": float(r["lng"]),
        "address": r["address"],
        "pincode": r["pincode"],
        "property_type": r["property_type"],
        "area_sqm": r["area_sqm"],
        "detection_type": r["detection_type"],
        "confidence": float(r["confidence"]),
        "confidence_breakdown": cb,
        "ndbi_delta": float(r["ndbi_delta"]) if r["ndbi_delta"] is not None else None,
        "area_delta": float(r["area_delta"]) if r["area_delta"] is not None else None,
        "ndvi_drop": float(r["ndvi_drop"]) if r["ndvi_drop"] is not None else None,
        "osm_status": float(r["osm_status"]) if r["osm_status"] is not None else None,
        "db_match": float(r["db_match"]) if r["db_match"] is not None else None,
        "baseline_year": r["baseline_year"],
        "comparison_year": r["comparison_year"],
        "detected_at": r["detected_at"].isoformat() + "Z" if isinstance(r["detected_at"], datetime) else r["detected_at"],
        "s3_geojson_key": r["s3_geojson_key"],
        "status": r["status"],
        "estimated_annual_tax_inr": r["estimated_annual_tax_inr"],
        "owner_name": r["owner_name"],
        "ai_explanation": r["ai_explanation"],
    }


def list_by_ward(conn, ward_id, detection_type=None, status=None):
    sql = f"SELECT {_COLUMNS} FROM properties WHERE ward_id = :ward_id"
    params = {"ward_id": ward_id}
    if detection_type:
        sql += " AND detection_type = :detection_type"
        params["detection_type"] = detection_type
    if status:
        sql += " AND status = :status"
        params["status"] = status
    sql += " ORDER BY detected_at DESC"
    rows = conn.execute(text(sql), params).mappings().all()
    return [_row_to_property(r) for r in rows]


def get_by_id(conn, property_id):
    row = conn.execute(
        text(f"SELECT {_COLUMNS} FROM properties WHERE id = :id"),
        {"id": property_id},
    ).mappings().first()
    return _row_to_property(row) if row else None


def set_ai_explanation(conn, property_id, explanation):
    conn.execute(
        text("UPDATE properties SET ai_explanation = :exp WHERE id = :id"),
        {"exp": explanation, "id": property_id},
    )


def update_status(conn, property_id, status, notes, updated_by):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    result = conn.execute(
        text("""
            UPDATE properties
            SET status = :status, notes = :notes, updated_by = :updated_by, updated_at = :updated_at
            WHERE id = :id
        """),
        {"status": status, "notes": notes, "updated_by": updated_by, "updated_at": now, "id": property_id},
    )
    return result.rowcount > 0


_BULK_UPSERT_OPTIONAL_FIELDS = (
    "address", "pincode", "property_type", "ndbi_delta", "area_delta", "ndvi_drop",
    "osm_status", "db_match", "baseline_year", "comparison_year",
    "estimated_annual_tax_inr", "owner_name",
)


def bulk_upsert(conn, rows):
    """rows: list of dicts with keys matching the properties columns (used by CSV import)."""
    count = 0
    for r in rows:
        for field in _BULK_UPSERT_OPTIONAL_FIELDS:
            r.setdefault(field, None)
        r.setdefault("status", "pending")
        conn.execute(
            text("""
                INSERT INTO properties
                    (id, ward_id, lat, lng, address, pincode, property_type, area_sqm,
                     detection_type, confidence, confidence_breakdown, ndbi_delta, area_delta,
                     ndvi_drop, osm_status, db_match, baseline_year, comparison_year,
                     detected_at, s3_geojson_key, status, estimated_annual_tax_inr, owner_name)
                VALUES
                    (:id, :ward_id, :lat, :lng, :address, :pincode, :property_type, :area_sqm,
                     :detection_type, :confidence, :confidence_breakdown, :ndbi_delta, :area_delta,
                     :ndvi_drop, :osm_status, :db_match, :baseline_year, :comparison_year,
                     :detected_at, :s3_geojson_key, :status, :estimated_annual_tax_inr, :owner_name)
                ON DUPLICATE KEY UPDATE
                    lat = VALUES(lat), lng = VALUES(lng), address = VALUES(address),
                    pincode = VALUES(pincode), property_type = VALUES(property_type),
                    area_sqm = VALUES(area_sqm), detection_type = VALUES(detection_type),
                    confidence = VALUES(confidence), confidence_breakdown = VALUES(confidence_breakdown),
                    ndbi_delta = VALUES(ndbi_delta), area_delta = VALUES(area_delta),
                    ndvi_drop = VALUES(ndvi_drop), osm_status = VALUES(osm_status),
                    db_match = VALUES(db_match), baseline_year = VALUES(baseline_year),
                    comparison_year = VALUES(comparison_year), detected_at = VALUES(detected_at),
                    estimated_annual_tax_inr = VALUES(estimated_annual_tax_inr),
                    owner_name = VALUES(owner_name)
            """),
            r,
        )
        count += 1
    return count
