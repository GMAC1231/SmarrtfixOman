from __future__ import annotations

import os
from typing import Iterable
from dotenv import load_dotenv, find_dotenv


def load_env() -> None:
    env_file = os.environ.get("ENV_FILE")
    if env_file and os.path.exists(env_file):
        print(f"[dotenv] loading explicit: {env_file}")
        load_dotenv(env_file, override=True)
    else:
        env_path = find_dotenv(usecwd=True)
        print(f"[dotenv] loading: {env_path or 'NOT FOUND'}")
        load_dotenv(dotenv_path=env_path, override=True)


def env_bool(key: str, default: bool = False) -> bool:
    return os.environ.get(key, str(default)).strip().lower() in ("1", "true", "yes", "on")


def env_int(key: str, default: int) -> int:
    try:
        return int(os.environ.get(key, str(default)).strip())
    except ValueError:
        return default


def env_csv(key: str, default: Iterable[str] = ()) -> list[str]:
    raw = os.environ.get(key, "")
    if not raw.strip():
        return list(default)
    return [x.strip() for x in raw.split(",") if x.strip()]


def env_required(key: str) -> str:
    value = os.environ.get(key, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {key}")
    return value


load_env()
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class Config:
    ENV_DEBUG = env_bool("ENV_DEBUG", False)
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev").strip()
    DATABASE_URL = env_required("DATABASE_URL")

    MAIL_SERVER = os.environ.get("MAIL_SERVER", "smtp.gmail.com").strip()
    MAIL_PORT = env_int("MAIL_PORT", 587)
    MAIL_USE_TLS = env_bool("MAIL_USE_TLS", True)
    MAIL_USE_SSL = env_bool("MAIL_USE_SSL", False)
    MAIL_USERNAME = os.environ.get("MAIL_USERNAME", "").strip()
    MAIL_PASSWORD = os.environ.get("MAIL_PASSWORD", "").strip()
    MAIL_DEFAULT_SENDER = os.environ.get("MAIL_DEFAULT_SENDER", "").strip() or MAIL_USERNAME
    MAIL_TIMEOUT_SEC = env_int("MAIL_TIMEOUT_SEC", 25)
    SMTP_PREFLIGHT = env_bool("SMTP_PREFLIGHT", True)
    DISABLE_MAIL = env_bool("DISABLE_MAIL", False)
    ALLOW_SENDER_ALIAS = env_bool("ALLOW_SENDER_ALIAS", False)
    FEEDBACK_INBOX = os.environ.get("FEEDBACK_INBOX", "").strip()

    DEV_ALLOW_NO_AUTH = env_bool("DEV_ALLOW_NO_AUTH", False)
    MAX_UPLOAD_BYTES = env_int("MAX_UPLOAD_BYTES", 5 * 1024 * 1024)
    CORS_ALLOWED_ORIGINS = env_csv("CORS_ALLOWED_ORIGINS", ["*"])

    GOOGLE_APPLICATION_CREDENTIALS = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip() or os.path.join(BASE_DIR, "serviceAccount.json")

    OSRM_BASE = os.environ.get("OSRM_BASE", "https://router.project-osrm.org").rstrip("/")
    OSRM_PROFILE = os.environ.get("OSRM_PROFILE", "driving")
    OSRM_TIMEOUT_SEC = env_int("OSRM_TIMEOUT_SEC", 8)

    UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads", "chat")
    ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "pakistanfixme.service1@gmail.com").strip().lower()
