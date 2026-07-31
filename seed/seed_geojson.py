"""Run once after deploy: builds a placeholder GeoJSON FeatureCollection per ward
from the seeded properties (small squares around each lat/lng) and uploads to
S3 at geojson/ward-{id}.json — the exact key GET /api/wards/{id}/changes presigns.

The real Sentinel-2/OSM pipeline (EC2, separate workstream) can overwrite these
same keys later with real change polygons — no API change needed.

Usage:
    DB_URL=... S3_BUCKET=... AWS_REGION=ap-south-1 python seed/seed_geojson.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text

from shared.s3_client import upload_json

HALF_SIDE_DEG = 0.0004  # ~40m square around each detection point


def build_feature(prop):
    lat, lng = float(prop["lat"]), float(prop["lng"])
    square = [
        [lng - HALF_SIDE_DEG, lat - HALF_SIDE_DEG],
        [lng + HALF_SIDE_DEG, lat - HALF_SIDE_DEG],
        [lng + HALF_SIDE_DEG, lat + HALF_SIDE_DEG],
        [lng - HALF_SIDE_DEG, lat + HALF_SIDE_DEG],
        [lng - HALF_SIDE_DEG, lat - HALF_SIDE_DEG],
    ]
    return {
        "type": "Feature",
        "properties": {
            "id": prop["id"],
            "detection_type": prop["detection_type"],
            "confidence": float(prop["confidence"]),
            "status": prop["status"],
        },
        "geometry": {"type": "Polygon", "coordinates": [square]},
    }


def main():
    db_url = os.environ["DB_URL"]
    engine = create_engine(db_url)

    with engine.connect() as conn:
        ward_ids = [r[0] for r in conn.execute(text("SELECT id FROM wards ORDER BY id"))]
        for ward_id in ward_ids:
            rows = conn.execute(
                text("SELECT id, lat, lng, detection_type, confidence, status FROM properties WHERE ward_id = :w"),
                {"w": ward_id},
            ).mappings().all()
            feature_collection = {
                "type": "FeatureCollection",
                "features": [build_feature(r) for r in rows],
            }
            key = f"geojson/ward-{ward_id}.json"
            upload_json(key, feature_collection)
            print(f"Uploaded {key} ({len(rows)} features)")


if __name__ == "__main__":
    main()
