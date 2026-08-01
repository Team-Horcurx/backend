from wards import wards_modal
from shared.s3_client import presigned_get


class WardsService:
    def list_wards(self, obj, conn):
        rows = wards_modal.list_wards(conn)
        data = [
            {
                "id": r["id"],
                "name": r["name"],
                "bbox": {
                    "north": float(r["bbox_north"]),
                    "south": float(r["bbox_south"]),
                    "east": float(r["bbox_east"]),
                    "west": float(r["bbox_west"]),
                },
                "geojson_s3": r["geojson_s3"],
                "detection_count": r["detection_count"],
            }
            for r in rows
        ]
        return "success", data

    def get_changes(self, obj, conn):
        ward = wards_modal.get_ward(conn, obj["wardId"])
        if not ward:
            raise ValueError("Ward not found")
        key = ward["geojson_s3"] or f"geojson/ward-{obj['wardId']}.json"
        return "success", {"presigned_url": presigned_get(key)}

    def get_years(self, obj, conn):
        ward = wards_modal.get_ward(conn, obj["wardId"])
        if not ward:
            raise LookupError("Ward not found")
        pairs = wards_modal.list_distinct_year_pairs(conn, obj["wardId"])
        return "success", {"ward_id": obj["wardId"], "pairs": pairs}
