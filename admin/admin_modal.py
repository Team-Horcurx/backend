from sqlalchemy import text


def upsert_config(conn, key_name, value):
    conn.execute(
        text("""
            INSERT INTO admin_config (key_name, value) VALUES (:k, :v)
            ON DUPLICATE KEY UPDATE value = VALUES(value)
        """),
        {"k": key_name, "v": str(value)},
    )
