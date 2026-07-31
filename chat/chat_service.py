from sqlalchemy import text

from shared.bedrock_client import chat_reply
from stats.stats_service import compute_stats


class ChatService:
    def send(self, obj, conn):
        message = obj.get("message")
        if not message:
            raise ValueError("message is required")

        stats = compute_stats(conn, ward_id=None)
        top_wards = conn.execute(text("""
            SELECT w.id AS ward_id, w.name AS ward_name, SUM(p.status = 'pending') AS pending_count
            FROM wards w
            LEFT JOIN properties p ON p.ward_id = w.id
            GROUP BY w.id, w.name
            ORDER BY pending_count DESC
            LIMIT 3
        """)).mappings().all()
        top_wards_list = [dict(r) for r in top_wards]

        reply = chat_reply(message, stats, top_wards_list)
        return "success", {"response": reply}
