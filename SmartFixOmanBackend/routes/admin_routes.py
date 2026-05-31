from flask import Blueprint, current_app, jsonify
from sqlalchemy import text as sql_text

import extensions
from services.firebase_service import verify_token

bp = Blueprint("admin", __name__)


def _require_admin():
    decoded = verify_token()
    if decoded is None:
        return None, (jsonify({"error": "Unauthorized"}), 401)
    email = (decoded.get("email") or "").strip().lower()
    if email != current_app.config["ADMIN_EMAIL"]:
        return None, (jsonify({"error": "Forbidden"}), 403)
    return decoded, None


@bp.get("/api/admin/users")
def admin_list_users():
    _, error = _require_admin()
    if error:
        return error
    with extensions.engine.begin() as conn:
        rows = conn.execute(sql_text("""
            SELECT id, firebase_uid, email, name, role, phone, city, address,
                   gender, profession, profession_emoji, fare, license_number,
                   car_plate, profile_image_url, profile_complete, created_at, updated_at
            FROM users
            ORDER BY updated_at DESC
        """)).mappings().all()
    return jsonify({"ok": True, "items": [dict(r) for r in rows]}), 200


@bp.get("/api/admin/feedback")
def admin_list_feedback():
    _, error = _require_admin()
    if error:
        return error
    with extensions.engine.begin() as conn:
        rows = conn.execute(sql_text("""
            SELECT id, user_id, user_email, title, message, app_version, platform, created_at
            FROM feedback
            ORDER BY created_at DESC
        """)).mappings().all()
    return jsonify({"ok": True, "items": [dict(r) for r in rows]}), 200


@bp.delete("/api/admin/feedback/<int:feedback_id>")
def admin_delete_feedback(feedback_id: int):
    _, error = _require_admin()
    if error:
        return error
    with extensions.engine.begin() as conn:
        result = conn.execute(sql_text("DELETE FROM feedback WHERE id = :id"), {"id": feedback_id})
    return jsonify({"ok": True, "deleted": result.rowcount}), 200
