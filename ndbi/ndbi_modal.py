from sqlalchemy import text


def list_by_ward_years(conn, ward_id, baseline_year, comparison_year):
    rows = conn.execute(
        text("""
            SELECT lat, lng, detection_type,
                   COALESCE(ndbi_delta, CAST(confidence_breakdown->>'$.ndbi_delta' AS DECIMAL(3,2))) AS ndbi_delta
            FROM properties
            WHERE ward_id = :ward_id AND baseline_year = :baseline_year AND comparison_year = :comparison_year
        """),
        {"ward_id": ward_id, "baseline_year": baseline_year, "comparison_year": comparison_year},
    ).mappings().all()
    return [
        {
            "lat": float(r["lat"]),
            "lng": float(r["lng"]),
            "detection_type": r["detection_type"],
            "ndbi_delta": float(r["ndbi_delta"]) if r["ndbi_delta"] is not None else 0.0,
        }
        for r in rows
    ]
