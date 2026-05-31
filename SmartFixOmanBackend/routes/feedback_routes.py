from flask import Blueprint, current_app, jsonify, request
from flask_mail import Message
from sqlalchemy import text as sql_text
from sqlalchemy.exc import SQLAlchemyError

import extensions
from services.firebase_service import verify_firebase_token_from_header
from utils.helpers import utc_now_iso

bp = Blueprint("feedback", __name__)


@bp.post("/api/feedback")
def create_feedback():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    message = (data.get("message") or "").strip()
    app_version = (data.get("appVersion") or "").strip()
    platform = (data.get("platform") or "").strip()
    anonymous = bool(data.get("anonymous", False))
    if not title or not message:
        return jsonify({"error": "title and message are required"}), 400

    user_id = None
    user_email = None
    if not anonymous:
        user_id, user_email = verify_firebase_token_from_header()
        user_email = user_email or (data.get("userEmail") or "").strip()
        if not user_email:
            return jsonify({"error": "user email required (use Firebase token or userEmail)"}), 400

    try:
        with extensions.engine.begin() as conn:
            conn.execute(sql_text("""
                INSERT INTO feedback (user_id, user_email, title, message, app_version, platform)
                VALUES (:uid, :email, :title, :message, :appv, :platform)
            """), {
                "uid": user_id,
                "email": user_email,
                "title": title,
                "message": message,
                "appv": app_version,
                "platform": platform,
            })
    except SQLAlchemyError as exc:
        return jsonify({"error": f"db error: {exc}"}), 500

    try:
        if current_app.config.get("DISABLE_MAIL"):
            return jsonify({"status": "saved", "email": "skipped"}), 200
        if not current_app.config.get("SMTP_OK"):
            raise RuntimeError(f"SMTP not ready: {current_app.config.get('SMTP_ERR') or 'preflight failed'}")

        to_addr = current_app.config.get("FEEDBACK_INBOX") or current_app.config.get("MAIL_DEFAULT_SENDER") or current_app.config.get("MAIL_USERNAME")
        who = user_email if user_email else "anonymous"
        msg = Message(
            subject=f"Feedback - {title} (from {who})",
            recipients=[to_addr],
            body=f"""New feedback received.

Title:
{title}

Message:
{message}

—
User: {user_email or '-'}
UID: {user_id or '-'}

App: {app_version or '-'}
Platform: {platform or '-'}

Submitted: {utc_now_iso()}
""",
            sender=current_app.config.get("MAIL_DEFAULT_SENDER") or current_app.config.get("MAIL_USERNAME"),
            reply_to=(user_email if (user_email and not anonymous and current_app.config.get("ALLOW_SENDER_ALIAS")) else None),
        )
        msg.charset = "utf-8"
        extensions.mail.send(msg)
        return jsonify({"status": "saved", "email": "sent"}), 200
    except Exception as exc:
        return jsonify({"status": "saved", "email": "failed", "error": str(exc)}), 202
