from __future__ import annotations

import logging
import os

from flask import Flask
from flask_cors import CORS

import extensions
from config import Config, env_bool, env_int
from database.db import ensure_tables
from routes import register_routes
from services.email_service import smtp_preflight
from services.firebase_service import init_firebase
from services.socket_service import register_socket_events

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("smartfixoman")


def create_app() -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)
    app.config["JSON_SORT_KEYS"] = False

    os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)

    CORS(
        app,
        resources={r"/*": {"origins": app.config["CORS_ALLOWED_ORIGINS"]}},
        supports_credentials=False,
        allow_headers=["Content-Type", "Authorization"],
        expose_headers=["Content-Type", "Authorization"],
    )

    # Keep Gmail sender safe unless aliases are explicitly allowed.
    if (not app.config["ALLOW_SENDER_ALIAS"] and app.config["MAIL_DEFAULT_SENDER"]
            and app.config["MAIL_USERNAME"]
            and app.config["MAIL_DEFAULT_SENDER"].lower() != app.config["MAIL_USERNAME"].lower()):
        log.warning("MAIL_DEFAULT_SENDER != MAIL_USERNAME; forcing sender=username.")
        app.config["MAIL_DEFAULT_SENDER"] = app.config["MAIL_USERNAME"]

    extensions.mail.init_app(app)
    extensions.socketio.init_app(app, cors_allowed_origins="*")
    extensions.init_engine(app.config["DATABASE_URL"])

    with app.app_context():
        try:
            ensure_tables()
            log.info("DB tables ensured.")
        except Exception as exc:
            log.warning("DB ensure warning: %s", exc)
        init_firebase(app)
        smtp_ok, smtp_err = smtp_preflight()
        app.config["SMTP_OK"] = smtp_ok
        app.config["SMTP_ERR"] = smtp_err
        app.config["SMTP_STATUS"] = "ok" if smtp_ok else f"error: {smtp_err}"

    register_socket_events()
    register_routes(app)
    return app


app = create_app()

if __name__ == "__main__":
    port = env_int("PORT", 5000)
    extensions.socketio.run(
        app,
        host="0.0.0.0",
        port=port,
        debug=env_bool("FLASK_DEBUG", False),
    )
