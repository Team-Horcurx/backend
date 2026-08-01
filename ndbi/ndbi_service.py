import math

from sqlalchemy import text

from ndbi import ndbi_modal
from ndbi.ndbi_validator import NdbiGridQuery
from wards import wards_modal

CELL_SIZE_DEG = 0.0009  # ~100m grid cell
DEFAULT_LOW = 0.15
DEFAULT_HIGH = 0.6

BUCKET_COLORS = {
    "red": "#dc3545",
    "orange": "#ff8c00",
    "green": "#28a745",
}
BUCKET_LABELS = {
    "red": "High-density change (new construction)",
    "orange": "Low-to-mid change",
    "green": "No significant change / open land",
}


def _config_value(conn, key, default):
    row = conn.execute(
        text("SELECT value FROM admin_config WHERE key_name = :k"), {"k": key}
    ).mappings().first()
    if not row or row["value"] is None:
        return default
    return float(row["value"])


def _bucket(avg_delta, low, high):
    if avg_delta >= high:
        return "red"
    if avg_delta >= low:
        return "orange"
    return "green"


def build_grid(conn, ward_id, baseline_year, comparison_year):
    bbox = wards_modal.get_ward_bbox(conn, ward_id)
    if not bbox:
        raise LookupError("Ward not found")

    north, south = float(bbox["bbox_north"]), float(bbox["bbox_south"])
    east, west = float(bbox["bbox_east"]), float(bbox["bbox_west"])

    n_cols = max(1, math.ceil((east - west) / CELL_SIZE_DEG))
    n_rows = max(1, math.ceil((north - south) / CELL_SIZE_DEG))

    cell_sum = {}
    cell_count = {}
    for prop in ndbi_modal.list_by_ward_years(conn, ward_id, baseline_year, comparison_year):
        col = min(n_cols - 1, max(0, int((prop["lng"] - west) / CELL_SIZE_DEG)))
        row = min(n_rows - 1, max(0, int((prop["lat"] - south) / CELL_SIZE_DEG)))
        key = (row, col)
        cell_sum[key] = cell_sum.get(key, 0.0) + prop["ndbi_delta"]
        cell_count[key] = cell_count.get(key, 0) + 1

    low = _config_value(conn, "ndbi_threshold", DEFAULT_LOW)
    high = _config_value(conn, "ndbi_threshold_high", DEFAULT_HIGH)

    features = []
    for row in range(n_rows):
        for col in range(n_cols):
            key = (row, col)
            count = cell_count.get(key, 0)
            avg = (cell_sum[key] / count) if count else 0.0
            bucket = _bucket(avg, low, high)

            cell_west = west + col * CELL_SIZE_DEG
            cell_east = cell_west + CELL_SIZE_DEG
            cell_south = south + row * CELL_SIZE_DEG
            cell_north = cell_south + CELL_SIZE_DEG

            features.append({
                "type": "Feature",
                "properties": {
                    "bucket": bucket,
                    "avg_ndbi_delta": round(avg, 3),
                    "property_count": count,
                },
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[
                        [cell_west, cell_south],
                        [cell_east, cell_south],
                        [cell_east, cell_north],
                        [cell_west, cell_north],
                        [cell_west, cell_south],
                    ]],
                },
            })

    legend = {
        "red": {"min": high, "color": BUCKET_COLORS["red"], "label": BUCKET_LABELS["red"]},
        "orange": {"min": low, "max": high, "color": BUCKET_COLORS["orange"], "label": BUCKET_LABELS["orange"]},
        "green": {"max": low, "color": BUCKET_COLORS["green"], "label": BUCKET_LABELS["green"]},
    }

    return {
        "type": "FeatureCollection",
        "features": features,
        "legend": legend,
        "ward_id": ward_id,
        "baseline_year": baseline_year,
        "comparison_year": comparison_year,
        "cell_size_deg": CELL_SIZE_DEG,
    }


class NdbiService:
    def get_grid(self, obj, conn):
        query = NdbiGridQuery(
            baseline_year=obj.get("baseline_year"),
            comparison_year=obj.get("comparison_year"),
        )
        query.validate_years()
        return "success", build_grid(conn, obj["wardId"], query.baseline_year, query.comparison_year)
