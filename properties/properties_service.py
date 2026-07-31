from properties import properties_modal
from properties.properties_validator import VerifyBody
from shared.bedrock_client import explain_property


class PropertiesService:
    def list_for_ward(self, obj, conn):
        rows = properties_modal.list_by_ward(
            conn,
            obj["wardId"],
            detection_type=obj.get("type"),
            status=obj.get("status"),
        )
        return "success", rows

    def get_detail(self, obj, conn):
        prop = properties_modal.get_by_id(conn, obj["id"])
        if not prop:
            raise LookupError("Not found")
        if not prop["ai_explanation"]:
            explanation = explain_property(prop)
            properties_modal.set_ai_explanation(conn, prop["id"], explanation)
            prop["ai_explanation"] = explanation
        return "success", prop

    def verify(self, obj, conn):
        body = VerifyBody(status=obj.get("status"), notes=obj.get("notes"), updated_by=obj.get("updated_by"))
        body.validate_status()
        ok = properties_modal.update_status(conn, obj["id"], body.status, body.notes, body.updated_by)
        if not ok:
            raise LookupError("Not found")
        return "success", {"status": body.status}
