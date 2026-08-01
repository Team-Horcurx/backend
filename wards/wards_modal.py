from sqlalchemy import text


def list_wards(conn):
    rows = conn.execute(text("""
        SELECT w.id, w.name, w.bbox_north, w.bbox_south, w.bbox_east, w.bbox_west,
               w.geojson_s3, COUNT(p.id) AS detection_count
        FROM wards w
        LEFT JOIN properties p ON p.ward_id = w.id
        GROUP BY w.id, w.name, w.bbox_north, w.bbox_south, w.bbox_east, w.bbox_west, w.geojson_s3
        ORDER BY w.id
    """)).mappings().all()
    return [dict(r) for r in rows]


def get_ward(conn, ward_id):
    row = conn.execute(
        text("SELECT id, name, geojson_s3 FROM wards WHERE id = :id"),
        {"id": ward_id},
    ).mappings().first()
    return dict(row) if row else None


def list_all_ward_ids(conn):
    rows = conn.execute(text("SELECT id, name FROM wards ORDER BY id")).mappings().all()
    return [dict(r) for r in rows]


def get_ward_bbox(conn, ward_id):
    row = conn.execute(
        text("SELECT bbox_north, bbox_south, bbox_east, bbox_west FROM wards WHERE id = :id"),
        {"id": ward_id},
    ).mappings().first()
    return dict(row) if row else None


def list_distinct_year_pairs(conn, ward_id):
    rows = conn.execute(
        text("""
            SELECT DISTINCT baseline_year, comparison_year
            FROM properties
            WHERE ward_id = :ward_id AND baseline_year IS NOT NULL AND comparison_year IS NOT NULL
            ORDER BY baseline_year, comparison_year
        """),
        {"ward_id": ward_id},
    ).mappings().all()
    return [{"baseline_year": r["baseline_year"], "comparison_year": r["comparison_year"]} for r in rows]
