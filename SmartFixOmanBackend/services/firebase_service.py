from __future__ import annotations

import logging
import os
from typing import Optional, Tuple

import firebase_admin
from firebase_admin import auth as fb_auth, credentials as fb_credentials
from firebase_admin import firestore as fb_fs
from flask import current_app, request

log = logging.getLogger("smartfixoman.firebase")
fs = None


def init_firebase(app=None):
    global fs
    try:
        if not firebase_admin._apps:
            path = current_app.config["GOOGLE_APPLICATION_CREDENTIALS"] if app is None else app.config["GOOGLE_APPLICATION_CREDENTIALS"]
            if path and os.path.exists(path):
                firebase_admin.initialize_app(fb_credentials.Certificate(path))
                log.info("Firebase initialized with service account file.")
            else:
                firebase_admin.initialize_app()
                log.info("Firebase initialized with Application Default Credentials.")
        fs = fb_fs.client()
    except Exception as exc:
        fs = None
        log.error("Firebase not initialized: %s", exc)
    return fs


def get_firestore():
    return fs


def verify_token() -> Optional[dict]:
    if not firebase_admin._apps:
        log.error("verify_token: Firebase Admin not initialized")
        return None
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        if current_app.config.get("DEV_ALLOW_NO_AUTH") and request.remote_addr in {"127.0.0.1", "::1"}:
            return {"uid": "dev-local", "email": "dev@local"}
        return None
    token = auth_header.split(" ", 1)[1].strip()
    try:
        return fb_auth.verify_id_token(token)
    except Exception as exc:
        log.warning("verify_token failed: %s", exc)
        return None


def verify_firebase_token_from_header() -> Tuple[Optional[str], Optional[str]]:
    decoded = verify_token()
    if not decoded:
        return None, None
    return decoded.get("uid"), decoded.get("email")
