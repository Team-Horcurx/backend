import os
from datetime import datetime, timezone

import boto3

from admin import admin_modal
from properties import properties_modal


class AdminService:
    def upload_csv(self, obj, conn):
        rows = obj.get("_csv_rows")
        if not rows:
            raise ValueError("No CSV rows found in upload")
        imported = properties_modal.bulk_upsert(conn, rows)
        admin_modal.upsert_config(conn, "data_mode", "live")
        return "success", {"properties_imported": imported}

    def save_db_config(self, obj, conn):
        for key, value in obj.items():
            if key.startswith("_"):
                continue
            admin_modal.upsert_config(conn, key, value)
        return "success", {}

    def trigger_refresh(self, obj, conn):
        admin_modal.upsert_config(conn, "pipeline_status", "running")
        instance_id = os.environ.get("PIPELINE_EC2_INSTANCE_ID")
        if instance_id:
            try:
                ssm = boto3.client("ssm", region_name=os.environ.get("AWS_REGION", "ap-south-1"))
                ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={"commands": ["cd /opt/gvmc-pipeline && bash run_pipeline.sh"]},
                )
            except Exception as e:
                print(f"[SSM ERROR] {e}")
                admin_modal.upsert_config(conn, "pipeline_status", "failed")
                return "success", {"triggered": True}

        now_iso = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        admin_modal.upsert_config(conn, "pipeline_status", "completed")
        admin_modal.upsert_config(conn, "last_refresh", now_iso)
        return "success", {"triggered": True}
