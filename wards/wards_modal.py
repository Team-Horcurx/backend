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
