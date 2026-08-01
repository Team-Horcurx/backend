from datetime import datetime, timedelta, timezone

from sqlalchemy import text

from ndbi.ndbi_validator import NdbiGridQuery
from shared.bedrock_client import commissioner_brief

AI_BRIEF_TTL_MINUTES = 10


def _admin_config(conn):
    rows = conn.execute(text("SELECT key_name, value FROM admin_config")).mappings().all()
    return {r["key_name"]: r["value"] for r in rows}


def compute_stats(conn, ward_id=None):
    sql = """
        SELECT
            COUNT(*) AS total_detections,
            SUM(detection_type = 'new_build') AS new_builds,
            SUM(detection_type = 'change_of_use') AS change_of_use,
            SUM(status = 'pending') AS pending_verification,
            SUM(status = 'verified') AS verified,
            SUM(status = 'false_positive') AS false_positives,
            SUM(CASE WHEN status IN ('pending','underassessed')
                     THEN area_sqm * (CASE WHEN detection_type = 'new_build' THEN 80 ELSE 40 END)
                     ELSE 0 END) AS revenue_estimate
        FROM properties
    """
    params = {}
    if ward_id:
        sql += " WHERE ward_id = :ward_id"
        params["ward_id"] = ward_id
    row = conn.execute(text(sql), params).mappings().first()
    cfg = _admin_config(conn)

    return {
        "total_detections": int(row["total_detections"] or 0),
        "new_builds": int(row["new_builds"] or 0),
        "change_of_use": int(row["change_of_use"] or 0),
        "pending_verification": int(row["pending_verification"] or 0),
        "verified": int(row["verified"] or 0),
        "false_positives": int(row["false_positives"] or 0),
        "revenue_estimate": int(row["revenue_estimate"] or 0),
        "ward_id": ward_id,
        "data_mode": cfg.get("data_mode", "demo"),
        "pipeline_status": cfg.get("pipeline_status", "idle"),
        "last_refresh": cfg.get("last_refresh"),
        "ndbi_threshold": float(cfg.get("ndbi_threshold", 0.15)),
    }


def compute_comparison(conn, ward_id, baseline_year, comparison_year):
    sql = """
        SELECT
            SUM(detection_type = 'new_build') AS new_structures,
            SUM(detection_type = 'change_of_use') AS change_of_use,
            SUM(CASE WHEN detection_type = 'new_build' THEN area_sqm ELSE 0 END) AS built_up_area_increase_sqm,
            SUM(CASE WHEN status IN ('pending','underassessed') THEN area_sqm ELSE 0 END) AS estimated_assessable_area_sqm,
            AVG(COALESCE(ndbi_delta, CAST(confidence_breakdown->>'$.ndbi_delta' AS DECIMAL(3,2)))) AS avg_ndbi_change,
            SUM(CASE WHEN status IN ('pending','underassessed')
                     THEN area_sqm * (CASE WHEN detection_type = 'new_build' THEN 80 ELSE 40 END)
                     ELSE 0 END) AS estimated_tax_impact_inr
        FROM properties
        WHERE ward_id = :ward_id AND baseline_year = :baseline_year AND comparison_year = :comparison_year
    """
    row = conn.execute(
        text(sql),
        {"ward_id": ward_id, "baseline_year": baseline_year, "comparison_year": comparison_year},
    ).mappings().first()

    return {
        "ward_id": ward_id,
        "baseline_year": baseline_year,
        "comparison_year": comparison_year,
        "new_structures": int(row["new_structures"] or 0),
        "change_of_use": int(row["change_of_use"] or 0),
        "built_up_area_increase_sqm": int(row["built_up_area_increase_sqm"] or 0),
        "estimated_assessable_area_sqm": int(row["estimated_assessable_area_sqm"] or 0),
        "avg_ndbi_change": round(float(row["avg_ndbi_change"]), 3) if row["avg_ndbi_change"] is not None else 0.0,
        "estimated_tax_impact_inr": int(row["estimated_tax_impact_inr"] or 0),
    }


def compute_all_wards(conn):
    ward_rows = conn.execute(text("""
        SELECT w.id AS ward_id, w.name AS ward_name,
               SUM(p.status = 'pending') AS unassessed_count,
               COUNT(p.id) AS total_detections
        FROM wards w
        LEFT JOIN properties p ON p.ward_id = w.id
        GROUP BY w.id, w.name
        ORDER BY w.id
    """)).mappings().all()
    wards = [
        {
            "ward_id": r["ward_id"],
            "ward_name": r["ward_name"],
            "unassessed_count": int(r["unassessed_count"] or 0),
            "total_detections": int(r["total_detections"] or 0),
        }
        for r in ward_rows
    ]
    totals = compute_stats(conn, ward_id=None)

    cfg = _admin_config(conn)
    ai_brief = cfg.get("ai_brief")
    updated_at = cfg.get("ai_brief_updated_at")
    stale = True
    if ai_brief and updated_at:
        try:
            age = datetime.now(timezone.utc) - datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
            stale = age > timedelta(minutes=AI_BRIEF_TTL_MINUTES)
        except ValueError:
            stale = True

    if stale or not ai_brief:
        ai_brief = commissioner_brief(totals, wards)
        now_iso = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        conn.execute(
            text("UPDATE admin_config SET value = :v WHERE key_name = 'ai_brief'"),
            {"v": ai_brief},
        )
        conn.execute(
            text("UPDATE admin_config SET value = :v WHERE key_name = 'ai_brief_updated_at'"),
            {"v": now_iso},
        )

    return {"wards": wards, "ai_brief": ai_brief, "totals": totals}


class StatsService:
    def get_stats(self, obj, conn):
        return "success", compute_stats(conn, ward_id=obj.get("ward_id"))

    def get_all_wards(self, obj, conn):
        return "success", compute_all_wards(conn)

    def get_comparison(self, obj, conn):
        query = NdbiGridQuery(
            baseline_year=obj.get("baseline_year"),
            comparison_year=obj.get("comparison_year"),
        )
        query.validate_years()
        return "success", compute_comparison(conn, obj["wardId"], query.baseline_year, query.comparison_year)
