from __future__ import annotations

import os
import secrets

from flask import Blueprint, current_app, jsonify, request, send_file
from sqlalchemy import text as sql_text

import extensions
from services.firebase_service import verify_token
from services.socket_service import emit_sound
from utils.image_utils import sniff_image_mime

bp = Blueprint("chat", __name__)


@bp.post("/api/chat/upload-image")
def upload_chat_image():
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401
    if "file" not in request.files:
        return jsonify({"error": "No file"}), 400

    file = request.files["file"]
    file_bytes = file.read()
    if sniff_image_mime(file_bytes) is None:
        return jsonify({"error": "Invalid image"}), 400
    if len(file_bytes) > current_app.config["MAX_UPLOAD_BYTES"]:
        return jsonify({"error": "Too large"}), 413

    unique_name = f"{secrets.token_hex(8)}.jpg"
    os.makedirs(current_app.config["UPLOAD_FOLDER"], exist_ok=True)
    path = os.path.join(current_app.config["UPLOAD_FOLDER"], unique_name)
    with open(path, "wb") as f:
        f.write(file_bytes)

    url = f"{request.host_url.rstrip('/')}/uploads/chat/{unique_name}"
    return jsonify({"ok": True, "url": url})


@bp.get("/uploads/chat/<path:filename>")
def serve_chat_image(filename):
    path = os.path.join(current_app.config["UPLOAD_FOLDER"], filename)
    if not os.path.exists(path):
        return jsonify({"error": "not found"}), 404
    return send_file(path)


@bp.post("/api/chat/send")
def send_chat_message():
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json() or {}
    chat_id = data.get("chatId")
    message_text = data.get("text")
    image_url = data.get("imageUrl")
    msg_type = data.get("type", "text")

    if not chat_id:
        return jsonify({"error": "chatId required"}), 400

    try:
        with extensions.engine.begin() as conn:
            conn.execute(sql_text("""
                INSERT INTO chat_messages (chat_id, sender_id, text, image_url, type)
                VALUES (:chat_id, :sender_id, :text, :image_url, :type)
            """), {
                "chat_id": chat_id,
                "sender_id": decoded["uid"],
                "text": message_text,
                "image_url": image_url,
                "type": msg_type,
            })
        return jsonify({"ok": True})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@bp.post("/sound_event")
def sound_event():
    data = request.get_json() or {}
    try:
        payload = {
            "receiver_id": data["receiver_id"],
            "sender_id": data["sender_id"],
            "chat_id": data["chat_id"],
        }
        with extensions.engine.begin() as conn:
            conn.execute(sql_text("""
                INSERT INTO sound_notifications (receiver_id, sender_id, chat_id)
                VALUES (:receiver_id, :sender_id, :chat_id)
            """), payload)
        emitted = emit_sound(data["receiver_id"], payload)
        return jsonify({"success": True, "emitted": emitted})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500
