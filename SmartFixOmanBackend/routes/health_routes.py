from flask import Blueprint, current_app, jsonify

from services.firebase_service import get_firestore
from utils.helpers import utc_now_iso

bp = Blueprint("health", __name__)


@bp.get("/health")
def health():
    return jsonify({
        "ok": True,
        "ts": utc_now_iso(),
        "smtp": current_app.config.get("SMTP_STATUS", "unknown"),
        "mail_disabled": current_app.config.get("DISABLE_MAIL"),
        "inbox": current_app.config.get("FEEDBACK_INBOX") or current_app.config.get("MAIL_DEFAULT_SENDER") or current_app.config.get("MAIL_USERNAME"),
        "cors": current_app.config.get("CORS_ALLOWED_ORIGINS"),
        "router": {"base": current_app.config.get("OSRM_BASE"), "profile": current_app.config.get("OSRM_PROFILE")},
        "firestore": bool(get_firestore() is not None),
    })


@bp.get("/healthz")
def healthz():
    return "ok", 200
