from alerts import alerts_modal
from shared.s3_client import upload_csv


class AlertsService:
    def list_for_ward(self, obj, conn):
        return "success", alerts_modal.list_by_ward(conn, obj["wardId"])

    def export(self, obj, conn):
        rows = alerts_modal.list_all(conn)
        key = upload_csv("exports/alerts", rows)
        from shared.s3_client import presigned_get
        return "success", {"presigned_url": presigned_get(key)}
