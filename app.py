from __future__ import annotations

import io, os, ssl, smtplib, socket, logging, secrets
from datetime import datetime, timezone
from typing import Optional, Tuple, Dict, Iterable

import requests
from flask import Flask, request, jsonify, send_file
from flask_socketio import SocketIO
from flask_cors import CORS
from dotenv import load_dotenv, find_dotenv

import psycopg2
from psycopg2 import errors as pg_errors
from psycopg2 import DataError as PGDataError
from psycopg2.extras import RealDictCursor
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from flask_mail import Mail, Message

import firebase_admin
from firebase_admin import auth as fb_auth, credentials as fb_credentials
from firebase_admin import firestore as fb_fs  # <-- Firestore

from werkzeug.utils import secure_filename

# ───────────────────────────── .env loader ─────────────────────────────
def _load_env():
    env_file = os.environ.get("ENV_FILE")
    if env_file and os.path.exists(env_file):
        print(f"[dotenv] loading explicit: {env_file}")
        load_dotenv(env_file, override=True)
    else:
        env_path = find_dotenv(usecwd=True)
        print(f"[dotenv] loading: {env_path or 'NOT FOUND'}")
        load_dotenv(dotenv_path=env_path, override=True)

_load_env()

# ───────────────────────────── helpers ─────────────────────────────
def env_bool(key: str, default: bool = False) -> bool:
    return os.environ.get(key, str(default)).strip().lower() in ("1", "true", "yes", "on")

def env_int(key: str, default: int) -> int:
    try: return int(os.environ.get(key, str(default)).strip())
    except ValueError: return default

def env_csv(key: str, default: Iterable[str] = ())->list[str]:
    raw = os.environ.get(key, "")
    if not raw.strip(): return list(default)
    return [x.strip() for x in raw.split(",") if x.strip()]

def env_required(key: str) -> str:
    val = os.environ.get(key, "").strip()
    if not val: raise RuntimeError(f"Missing required environment variable: {key}")
    return val

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def _gen_trip_id() -> str:
    return f"trip_{secrets.token_hex(8)}"

# ───────────────────────────── config ─────────────────────────────
ENV_DEBUG            = env_bool("ENV_DEBUG", False)
DATABASE_URL         = env_required("DATABASE_URL")
MAIL_SERVER          = os.environ.get("MAIL_SERVER", "smtp.gmail.com").strip()
MAIL_PORT            = env_int("MAIL_PORT", 587)
MAIL_USE_TLS         = env_bool("MAIL_USE_TLS", True)
MAIL_USE_SSL         = env_bool("MAIL_USE_SSL", False)
MAIL_USERNAME        = os.environ.get("MAIL_USERNAME", "").strip()
MAIL_PASSWORD        = os.environ.get("MAIL_PASSWORD", "").strip()
MAIL_DEFAULT_SENDER  = (os.environ.get("MAIL_DEFAULT_SENDER", "").strip() or MAIL_USERNAME)
SECRET_KEY           = os.environ.get("SECRET_KEY", "dev").strip()
MAX_UPLOAD_BYTES     = env_int("MAX_UPLOAD_BYTES", 5 * 1024 * 1024)
SMTP_PREFLIGHT       = env_bool("SMTP_PREFLIGHT", True)
DISABLE_MAIL         = env_bool("DISABLE_MAIL", False)
ALLOW_SENDER_ALIAS   = env_bool("ALLOW_SENDER_ALIAS", False)
FEEDBACK_INBOX       = os.environ.get("FEEDBACK_INBOX", "").strip()
DEV_ALLOW_NO_AUTH    = env_bool("DEV_ALLOW_NO_AUTH", False)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

GOOGLE_CREDS_PATH = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

if not GOOGLE_CREDS_PATH:
    GOOGLE_CREDS_PATH = os.path.join(BASE_DIR, "serviceAccount.json")


# Routing (OSRM)
OSRM_BASE            = os.environ.get("OSRM_BASE", "https://router.project-osrm.org").rstrip("/")
OSRM_PROFILE         = os.environ.get("OSRM_PROFILE", "driving")
OSRM_TIMEOUT_SEC     = env_int("OSRM_TIMEOUT_SEC", 8)

CORS_ALLOWED_ORIGINS = env_csv("CORS_ALLOWED_ORIGINS", ["*"])
MAIL_TIMEOUT_SEC     = env_int("MAIL_TIMEOUT_SEC", 25)
UPLOAD_FOLDER = "uploads/chat"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ───────────────────────────── app & logging ─────────────────────────────
app = Flask(__name__)
socketio = SocketIO(
    app,
    cors_allowed_origins="*",
)

connected_users = {}

@socketio.on("register")
def register_user(data):

    uid = data.get("uid")

    connected_users[uid] = request.sid

    print(
        "REGISTERED =>",
        uid,
    )

@socketio.on("connect")
def handle_connect():

    print("SOCKET CLIENT CONNECTED")
app.config["JSON_SORT_KEYS"] = False
app.config.update(
    SECRET_KEY=SECRET_KEY,
    MAIL_SERVER=MAIL_SERVER,
    MAIL_PORT=MAIL_PORT,
    MAIL_USE_TLS=MAIL_USE_TLS,
    MAIL_USE_SSL=MAIL_USE_SSL,
    MAIL_USERNAME=MAIL_USERNAME,
    MAIL_PASSWORD=MAIL_PASSWORD,
    MAIL_DEFAULT_SENDER=MAIL_DEFAULT_SENDER,
)

CORS(
    app,
    resources={r"/*": {"origins": CORS_ALLOWED_ORIGINS}},
    supports_credentials=False,
    allow_headers=["Content-Type", "Authorization"],
    expose_headers=["Content-Type", "Authorization"],
)

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("pakistanfixme")

if ENV_DEBUG:
    print(f"[env] DATABASE_URL set: {bool(DATABASE_URL)}")
    print(f"[env] MAIL_USERNAME={MAIL_USERNAME!r} MAIL_PASSWORD_LEN={len(MAIL_PASSWORD)}")
    print(f"[env] CORS_ALLOWED_ORIGINS={CORS_ALLOWED_ORIGINS}")
    print(f"[env] OSRM_BASE={OSRM_BASE} OSRM_PROFILE={OSRM_PROFILE}")

# Sender hygiene
if not ALLOW_SENDER_ALIAS and MAIL_DEFAULT_SENDER and MAIL_USERNAME \
   and (MAIL_DEFAULT_SENDER.lower() != MAIL_USERNAME.lower()):
    log.warning("MAIL_DEFAULT_SENDER != MAIL_USERNAME; forcing sender=username (ALLOW_SENDER_ALIAS=false).")
    app.config["MAIL_DEFAULT_SENDER"] = MAIL_USERNAME

mail = Mail(app)
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
mail = Mail(app)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True
)

########################################################
# CREATE SOUND TABLE
########################################################

with engine.begin() as conn:

    conn.execute(

        text("""

        CREATE TABLE IF NOT EXISTS sound_notifications (

            id SERIAL PRIMARY KEY,

            receiver_id TEXT NOT NULL,

            sender_id TEXT NOT NULL,

            chat_id TEXT NOT NULL,

            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

        )

        """)
    )

print(
    "SOUND TABLE CREATED"
)

# ───────────────────────────── Firebase Admin + Firestore ─────────────────────────────
try:
    if not firebase_admin._apps:
        if GOOGLE_CREDS_PATH and os.path.exists(GOOGLE_CREDS_PATH):
            firebase_admin.initialize_app(fb_credentials.Certificate(GOOGLE_CREDS_PATH))
            log.info("Firebase initialized with service account file.")
        else:
            firebase_admin.initialize_app()  # ADC
            log.info("Firebase initialized with Application Default Credentials.")
    fs = fb_fs.client()  # Firestore
except Exception as e:
    fs = None
    log.error(f"Firebase not initialized: {e}")

# ───────────────────────────── constants ─────────────────────────────
MAX_EMAIL=255; MAX_NAME=255; MAX_ROLE=50; MAX_PHONE=32; MAX_CITY=255
MAX_ADDRESS=512; MAX_GENDER=32; MAX_PROFESSION=255; MAX_PROFESSION_EMOJI=32
MAX_LICENSE=64; MAX_CAR_PLATE=32; MAX_PROFILE_IMAGE_URL=255

# ───────────────────────────── misc utils ─────────────────────────────
def _sniff_image_mime(data: bytes) -> Optional[str]:
    b = data or b""
    try:
        if len(b)>=3 and b[:3]==b"\xFF\xD8\xFF": return "image/jpeg"
        if len(b)>=8 and b[:8]==b"\x89PNG\r\n\x1a\n": return "image/png"
        if len(b)>=6 and (b[:6] in (b"GIF87a", b"GIF89a")): return "image/gif"
        if len(b)>=2 and b[:2]==b"BM": return "image/bmp"
        if len(b)>=4 and (b[:4] in (b"II*\x00", b"MM\x00*")): return "image/tiff"
        if len(b)>=12 and b[:4]==b"RIFF" and b[8:12]==b"WEBP": return "image/webp"
        if len(b)>=12 and b[4:8]==b"ftyp" and b[8:12] in (b"heic", b"heif", b"mif1", b"hevc"): return "image/heic"
    except Exception:
        pass
    return None

def _trim(val, maxlen: Optional[int] = None) -> Optional[str]:
    if val is None: return None
    s = str(val).strip()
    return s[:maxlen] if maxlen is not None else s

def _num(val, default: float = 0.0) -> float:
    try: return float(val)
    except (TypeError, ValueError): return default

def _parse_latlng(q: str) -> Optional[Tuple[float, float]]:
    if not q or "," not in q: return None
    a, b = q.split(",", 1)
    try:
        lat = float(a.strip()); lng = float(b.strip())
        if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0): return None
        return (lat, lng)
    except ValueError:
        return None

def verify_token() -> Optional[dict]:
    """Verify Firebase ID token, or allow dev bypass for localhost."""
    if not firebase_admin._apps:
        log.error("verify_token: Firebase Admin not initialized")
        return None
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        if DEV_ALLOW_NO_AUTH and request.remote_addr in {"127.0.0.1", "::1"}:
            log.warning("verify_token: DEV_ALLOW_NO_AUTH bypass for %s", request.remote_addr)
            return {"uid": "dev-local", "email": "dev@local"}
        return None
    token = auth_header.split(" ", 1)[1].strip()
    try:
        return fb_auth.verify_id_token(token)
    except Exception as e:
        log.warning(f"verify_token failed: {e}")
        return None
    
def _decode_polyline5(poly: str) -> list[list[float]]:
    """Decode Google/OSRM polyline (1e5 precision) -> [[lat,lng], ...]."""
    if not poly:
        return []
    idx = 0
    lat = 0
    lng = 0
    out: list[list[float]] = []
    L = len(poly)

    while idx < L:
        shift = 0
        result = 0
        while True:
            b = ord(poly[idx]) - 63
            idx += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        lat += ~(result >> 1) if (result & 1) else (result >> 1)

        shift = 0
        result = 0
        while True:
            b = ord(poly[idx]) - 63
            idx += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        lng += ~(result >> 1) if (result & 1) else (result >> 1)

        out.append([lat / 1e5, lng / 1e5])
    return out


# ───────────────────────────── SMTP preflight ─────────────────────────────
def _smtp_preflight() -> Tuple[bool, Optional[str]]:
    if not SMTP_PREFLIGHT:
        return True, None
    host = app.config["MAIL_SERVER"]; port = int(app.config["MAIL_PORT"])
    user = app.config["MAIL_USERNAME"]; pwd = app.config["MAIL_PASSWORD"]
    use_tls = bool(app.config["MAIL_USE_TLS"]); use_ssl = bool(app.config["MAIL_USE_SSL"])
    if use_tls and use_ssl:  return (False, "MAIL_USE_TLS and MAIL_USE_SSL cannot both be true.")
    if port==587 and not use_tls: return (False, "Port 587 requires MAIL_USE_TLS=true and MAIL_USE_SSL=false.")
    if port==465 and not use_ssl: return (False, "Port 465 requires MAIL_USE_SSL=true and MAIL_USE_TLS=false.")
    if not user or not pwd:       return (False, "MAIL_USERNAME and MAIL_PASSWORD are required for preflight.")
    try:
        if use_ssl and port==465:
            ctx = ssl.create_default_context()
            with smtplib.SMTP_SSL(host, port, timeout=MAIL_TIMEOUT_SEC, context=ctx) as s:
                s.ehlo(); s.login(user, pwd); s.noop()
        else:
            with smtplib.SMTP(host, port, timeout=MAIL_TIMEOUT_SEC) as s:
                s.ehlo(); s.starttls(context=ssl.create_default_context()); s.ehlo()
                s.login(user, pwd); s.noop()
        return True, None
    except (smtplib.SMTPServerDisconnected, ConnectionResetError, socket.timeout) as e:
        return False, f"Connection closed/timeout: {e}"
    except smtplib.SMTPAuthenticationError as e:
        return False, f"Auth failed: {e}"
    except ssl.SSLError as e:
        return False, f"TLS handshake failed: {e}"
    except Exception as e:
        return False, f"Unexpected: {type(e).__name__}: {e}"

SMTP_OK, SMTP_ERR = _smtp_preflight()

# ───────────────────────────── DB bootstrap (Postgres) ─────────────────────────────
def get_db_connection():
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False
    return conn

def ensure_users_table():
    ddl = f"""
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        firebase_uid       VARCHAR(128),
        email              VARCHAR({MAX_EMAIL}) UNIQUE NOT NULL,
        name               VARCHAR({MAX_NAME}),
        role               VARCHAR({MAX_ROLE}) DEFAULT 'customer',
        phone              VARCHAR({MAX_PHONE}) DEFAULT '',
        city               VARCHAR({MAX_CITY}) DEFAULT '',
        address            VARCHAR({MAX_ADDRESS}) DEFAULT '',
        gender             VARCHAR({MAX_GENDER}) DEFAULT '',
        profession         VARCHAR({MAX_PROFESSION}) DEFAULT '',
        profession_emoji   VARCHAR({MAX_PROFESSION_EMOJI}) DEFAULT '',
        fare               DOUBLE PRECISION DEFAULT 0.0,
        license_number     VARCHAR({MAX_LICENSE}) DEFAULT '',
        car_plate          VARCHAR({MAX_CAR_PLATE}) DEFAULT '',
        profile_image_url  VARCHAR({MAX_PROFILE_IMAGE_URL}),
        profile_image      BYTEA,
        profile_complete   BOOLEAN DEFAULT FALSE,
        created_at         TIMESTAMP DEFAULT NOW(),
        updated_at         TIMESTAMP DEFAULT NOW()
    );"""
    with get_db_connection() as conn, conn.cursor() as cur:
        cur.execute(ddl); conn.commit()

def ensure_feedback_table():
    ddl = """
    CREATE TABLE IF NOT EXISTS feedback (
      id SERIAL PRIMARY KEY,
      user_id TEXT,
      user_email TEXT,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      app_version TEXT,
      platform TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );"""
    with engine.begin() as conn:
        conn.execute(text(ddl))

try:
    ensure_users_table()
    ensure_feedback_table()
    log.info("DB tables ensured.")
except Exception as e:
    log.warning(f"DB ensure warning: {e}")

@app.get("/api/admin/feedback")
def admin_list_feedback():
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401

    email = (decoded.get("email") or "").strip().lower()
    if email != "pakistanfixme.service1@gmail.com":
        return jsonify({"error": "Forbidden"}), 403

    try:
        with engine.begin() as conn:
            rows = conn.execute(
                text("""
                    SELECT id, user_id, user_email, title, message, app_version, platform, created_at
                    FROM feedback
                    ORDER BY created_at DESC
                """)
            ).mappings().all()

        return jsonify({
            "ok": True,
            "items": [
                {
                    "id": r["id"],
                    "user_id": r["user_id"],
                    "user_email": r["user_email"],
                    "title": r["title"],
                    "message": r["message"],
                    "app_version": r["app_version"],
                    "platform": r["platform"],
                    "created_at": r["created_at"].isoformat() if r["created_at"] else None,
                }
                for r in rows
            ]
        }), 200
    except Exception as e:
        log.exception("admin_list_feedback failed")
        return jsonify({"ok": False, "error": str(e)}), 500    

@app.delete("/api/admin/feedback/<int:feedback_id>")
def admin_delete_feedback(feedback_id: int):
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401

    email = (decoded.get("email") or "").strip().lower()
    if email != "pakistanfixme.service1@gmail.com":
        return jsonify({"error": "Forbidden"}), 403

    try:
        with engine.begin() as conn:
            result = conn.execute(
                text("DELETE FROM feedback WHERE id = :id"),
                {"id": feedback_id}
            )
        return jsonify({"ok": True, "deleted": result.rowcount}), 200
    except Exception as e:
        log.exception("admin_delete_feedback failed")
        return jsonify({"ok": False, "error": str(e)}), 500   

@app.post("/api/chat/upload-image")
def upload_chat_image():
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401

    if "file" not in request.files:
        return jsonify({"error": "No file"}), 400

    file = request.files["file"]
    file_bytes = file.read()

    # Validate
    mime = _sniff_image_mime(file_bytes)
    if mime is None:
        return jsonify({"error": "Invalid image"}), 400

    if len(file_bytes) > MAX_UPLOAD_BYTES:
        return jsonify({"error": "Too large"}), 413

    # Save properly
    unique_name = f"{secrets.token_hex(8)}.jpg"
    path = os.path.join(UPLOAD_FOLDER, unique_name)

    with open(path, "wb") as f:
        f.write(file_bytes)

    url = f"{request.host_url.rstrip('/')}/uploads/chat/{unique_name}"
    return jsonify({"ok": True, "url": url})

@app.get("/api/admin/users")
def admin_list_users():
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401

    email = (decoded.get("email") or "").strip().lower()
    if email != "pakistanfixme.service1@gmail.com":
        return jsonify({"error": "Forbidden"}), 403

    try:
        with engine.begin() as conn:
            rows = conn.execute(
                text("""
                    SELECT id, firebase_uid, email, name, role, phone, city, address,
                           gender, profession, profession_emoji, fare,
                           license_number, car_plate, profile_image_url,
                           profile_complete, created_at, updated_at
                    FROM users
                    ORDER BY updated_at DESC
                """)
            ).mappings().all()

        return jsonify({
            "ok": True,
            "items": [dict(r) for r in rows]
        }), 200
    except Exception as e:
        log.exception("admin_list_users failed")
        return jsonify({"ok": False, "error": str(e)}), 500     


@app.get("/uploads/chat/<path:filename>")
def serve_chat_image(filename):
    path = os.path.join(UPLOAD_FOLDER, filename)

    if not os.path.exists(path):
        return jsonify({"error": "not found"}), 404

    return send_file(path)        

# ───────────────────────────── routes: health ─────────────────────────────
@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "ts": utc_now_iso(),
        "smtp": "ok" if SMTP_OK else f"error: {SMTP_ERR}",
        "mail_disabled": DISABLE_MAIL,
        "inbox": FEEDBACK_INBOX or app.config.get("MAIL_DEFAULT_SENDER") or app.config.get("MAIL_USERNAME"),
        "cors": CORS_ALLOWED_ORIGINS,
        "router": {"base": OSRM_BASE, "profile": OSRM_PROFILE},
        "firestore": bool(fs is not None),
    })

@app.get("/healthz")
def healthz():
    return "ok", 200

# ───────────────────────────── profile (Postgres) ─────────────────────────────
@app.post("/update-profile")
def update_profile():
    decoded = verify_token()
    uid = decoded.get("uid") if decoded else None
    if uid is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.form.to_dict() if request.form else (request.get_json(silent=True) or {})
    if not data and "file" not in request.files:
        return jsonify({"error": "No data provided"}), 400

    email_raw = _trim(data.get("email"), MAX_EMAIL)
    email = (email_raw or f"{uid}@firebase.local").lower()

    name = _trim(data.get("name"), MAX_NAME)
    role = _trim(data.get("role") or "customer", MAX_ROLE)
    phone = _trim(data.get("phone"), MAX_PHONE)
    city = _trim(data.get("city"), MAX_CITY)
    address = _trim(data.get("address"), MAX_ADDRESS)
    gender = _trim(data.get("gender"), MAX_GENDER)
    profession = _trim(data.get("profession"), MAX_PROFESSION)
    profession_emoji = _trim(data.get("professionEmoji") or data.get("profession_emoji"), MAX_PROFESSION_EMOJI)
    fare_val = _num(data.get("fare"), 0.0)
    license_number = _trim(data.get("license") or data.get("license_number"), MAX_LICENSE)
    car_plate = _trim(data.get("carPlate") or data.get("car_plate"), MAX_CAR_PLATE)

    profile_image_bytes: Optional[bytes] = None
    profile_image_url: Optional[str] = None
    if "file" in request.files:
        f = request.files["file"]
        if f and f.filename:
            profile_image_url = _trim(secure_filename(f.filename), MAX_PROFILE_IMAGE_URL)
            blob = f.read(MAX_UPLOAD_BYTES + 1)
            if len(blob) > MAX_UPLOAD_BYTES:
                return jsonify({"error": "file too large", "max_bytes": MAX_UPLOAD_BYTES}), 413
            profile_image_bytes = blob if blob else None

    too_long: Dict[str, int] = {}
    def _check(label: str, value: Optional[str], mx: int):
        if value is not None and len(value) > mx:
            too_long[label] = mx

    _check("email", email, MAX_EMAIL); _check("name", name, MAX_NAME)
    _check("role", role, MAX_ROLE);   _check("phone", phone, MAX_PHONE)
    _check("city", city, MAX_CITY);   _check("address", address, MAX_ADDRESS)
    _check("gender", gender, MAX_GENDER)
    _check("profession", profession, MAX_PROFESSION)
    _check("profession_emoji", profession_emoji, MAX_PROFESSION_EMOJI)
    _check("license_number", license_number, MAX_LICENSE)
    _check("car_plate", car_plate, MAX_CAR_PLATE)
    if profile_image_url: _check("profile_image_url", profile_image_url, MAX_PROFILE_IMAGE_URL)

    if too_long:
        return jsonify({"error": "field too long", "details": too_long}), 400

    upsert_sql = """
        INSERT INTO users (
            firebase_uid, email, name, role, phone, city, address, gender,
            profession, profession_emoji, fare, license_number, car_plate,
            profile_image_url, profile_image, profile_complete, updated_at
        ) VALUES (
            %(firebase_uid)s, %(email)s, %(name)s, COALESCE(%(role)s,'customer'),
            COALESCE(%(phone)s,''), COALESCE(%(city)s,''), COALESCE(%(address)s,''), COALESCE(%(gender)s,''),
            COALESCE(%(profession)s,''), COALESCE(%(profession_emoji)s,''), COALESCE(%(fare)s,0.0),
            COALESCE(%(license_number)s,''), COALESCE(%(car_plate)s,''),
            %(profile_image_url)s, %(profile_image)s, TRUE, NOW()
        )
        ON CONFLICT (email) DO UPDATE SET
            firebase_uid      = EXCLUDED.firebase_uid,
            name              = EXCLUDED.name,
            role              = EXCLUDED.role,
            phone             = EXCLUDED.phone,
            city              = EXCLUDED.city,
            address           = EXCLUDED.address,
            gender            = EXCLUDED.gender,
            profession        = EXCLUDED.profession,
            profession_emoji  = EXCLUDED.profession_emoji,
            fare              = EXCLUDED.fare,
            license_number    = EXCLUDED.license_number,
            car_plate         = EXCLUDED.car_plate,
            profile_image_url = COALESCE(EXCLUDED.profile_image_url, users.profile_image_url),
            profile_image     = COALESCE(EXCLUDED.profile_image, users.profile_image),
            profile_complete  = TRUE,
            updated_at        = NOW()
        RETURNING email, role, profile_complete;
    """

    params = {
        "firebase_uid": uid,
        "email": email,
        "name": name,
        "role": role,
        "phone": phone,
        "city": city,
        "address": address,
        "gender": gender,
        "profession": profession,
        "profession_emoji": profession_emoji,
        "fare": fare_val,
        "license_number": license_number,
        "car_plate": car_plate,
        "profile_image_url": profile_image_url,
        "profile_image": psycopg2.Binary(profile_image_bytes) if profile_image_bytes else None,
    }

    try:
        with get_db_connection() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(upsert_sql, params)
            saved = cur.fetchone()
            conn.commit()
    except pg_errors.StringDataRightTruncation as e:
        return jsonify({"error": "DB column too small for provided data", "psql": str(e)}), 400
    except PGDataError as e:
        return jsonify({"error": "Invalid data for one or more fields", "psql": str(e)}), 400
    except Exception as e:
        log.exception("update_profile failed")
        return jsonify({"error": "update_profile failed", "detail": str(e)}), 500

    image_url = f"{request.host_url.rstrip('/')}/profile-image/{email}"
    return jsonify({
        "status": "profile saved",
        "email": saved.get("email"),
        "role": saved.get("role"),
        "profile_complete": bool(saved.get("profile_complete")),
        "image_url": image_url,
    })



def alter_users_table():
    queries = [

        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS first_name TEXT;
        """,

        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS last_name TEXT;
        """,

        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 5.0;
        """,

        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0;
        """,

        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS car_model TEXT;
        """,

        """
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS car_image_url TEXT;
        """,

    ]

    with get_db_connection() as conn:
        with conn.cursor() as cursor:

            for query in queries:
                cursor.execute(query)

            conn.commit()

    print("users table altered successfully")

@app.post("/api/chat/send")
def send_chat_message():
    decoded = verify_token()
    if decoded is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json() or {}

    chat_id = data.get("chatId")
    text = data.get("text")
    image_url = data.get("imageUrl")
    msg_type = data.get("type", "text")

    if not chat_id:
        return jsonify({"error": "chatId required"}), 400

    try:
        with engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO chat_messages (chat_id, sender_id, text, image_url, type)
                VALUES (:chat_id, :sender_id, :text, :image_url, :type)
            """), {
                "chat_id": chat_id,
                "sender_id": decoded["uid"],
                "text": text,
                "image_url": image_url,
                "type": msg_type
            })

        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    

@app.get("/profile-image/<path:email>")
def get_profile_image(email: str):
    email = _trim(email, MAX_EMAIL)
    if not email:
        return jsonify({"error": "missing email"}), 400
    sql = "SELECT profile_image FROM users WHERE email = %s"
    with get_db_connection() as conn, conn.cursor() as cur:
        cur.execute(sql, (email,))
        row = cur.fetchone()
        if not row or not row[0]:
            return jsonify({"error": "no image"}), 404
        data: bytes = row[0]
    mime = _sniff_image_mime(data) or "application/octet-stream"
    return send_file(io.BytesIO(data), mimetype=mime)

# ───────────────────────────── feedback (Postgres + optional email) ─────────────────────────────
def _verify_firebase_token_from_header() -> Tuple[Optional[str], Optional[str]]:
    if not firebase_admin._apps:
        return None, None
    authz = request.headers.get("Authorization", "")
    if not authz.startswith("Bearer "):
        return None, None
    token = authz.split(" ", 1)[1].strip()
    try:
        decoded = fb_auth.verify_id_token(token)
        return decoded.get("uid"), decoded.get("email")
    except Exception:
        return None, None
    
@app.route("/sound_event", methods=["POST"])
def sound_event():

    data = request.get_json() or {}

    try:

        with engine.begin() as conn:

            conn.execute(

                text("""
                    INSERT INTO sound_notifications
                    (
                        receiver_id,
                        sender_id,
                        chat_id
                    )

                    VALUES
                    (
                        :receiver_id,
                        :sender_id,
                        :chat_id
                    )
                """),

                {
                    "receiver_id":
                        data["receiver_id"],

                    "sender_id":
                        data["sender_id"],

                    "chat_id":
                        data["chat_id"],
                }
            )

        print(
            "POSTGRES SOUND SAVED =>",
            data,
        )

        receiver_id = data["receiver_id"]

        receiver_sid = connected_users.get(
            receiver_id
        )

        if receiver_sid:

            socketio.emit(

                "play_sound",

                {
                    "receiver_id":
                        data["receiver_id"],

                    "sender_id":
                        data["sender_id"],

                    "chat_id":
                        data["chat_id"],
                },

                room=receiver_sid,
            )

            print(
                "SOUND EMITTED TO =>",
                receiver_id,
            )

        else:

            print(
                "USER NOT CONNECTED =>",
                receiver_id,
            )

        return jsonify(
            {
                "success": True,
            }
        )

    except Exception as e:

        print(
            "SOUND EVENT ERROR =>",
            e,
        )

        return jsonify(
            {
                "error": str(e),
            }
        ), 500
    
@app.post("/api/feedback")
def create_feedback():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    message = (data.get("message") or "").strip()
    app_version = (data.get("appVersion") or "").strip()
    platform = (data.get("platform") or "").strip()
    anonymous = bool(data.get("anonymous", False))
    if not title or not message:
        return jsonify({"error": "title and message are required"}), 400

    user_id: Optional[str] = None
    user_email: Optional[str] = None
    if not anonymous:
        uid_from_token, email_from_token = _verify_firebase_token_from_header()
        user_id = uid_from_token
        user_email = email_from_token or (data.get("userEmail") or "").strip()
        if not user_email:
            return jsonify({"error": "user email required (use Firebase token or userEmail)"}), 400

    try:
        with engine.begin() as conn:
            conn.execute(
                text("""INSERT INTO feedback (user_id, user_email, title, message, app_version, platform)
                        VALUES (:uid, :email, :title, :message, :appv, :platform)"""),
                {"uid": user_id, "email": user_email, "title": title, "message": message,
                 "appv": app_version, "platform": platform},
            )
    except SQLAlchemyError as e:
        return jsonify({"error": f"db error: {e}"}), 500

    try:
        if DISABLE_MAIL:
            log.info("Mail disabled; skipping SMTP send.")
            return jsonify({"status": "saved", "email": "skipped"}), 200
        if not SMTP_OK:
            raise RuntimeError(f"SMTP not ready: {SMTP_ERR or 'preflight failed'}")

        to_addr = FEEDBACK_INBOX or app.config.get("MAIL_DEFAULT_SENDER") or app.config.get("MAIL_USERNAME")
        if not to_addr:
            raise RuntimeError("No inbox configured: set FEEDBACK_INBOX or MAIL_DEFAULT_SENDER or MAIL_USERNAME.")

        who = user_email if user_email else "anonymous"
        subj = f"Feedback - {title} (from {who})"
        body = f"""New feedback received.

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
"""
        msg = Message(
            subject=subj,
            recipients=[to_addr],
            body=body,
            sender=app.config.get("MAIL_DEFAULT_SENDER") or app.config.get("MAIL_USERNAME"),
            reply_to=(user_email if (user_email and not anonymous and ALLOW_SENDER_ALIAS) else None),
        )
        msg.charset = "utf-8"
        mail.send(msg)
        return jsonify({"status": "saved", "email": "sent"}), 200
    except Exception as e:
        log.exception("Feedback email send failed")
        return jsonify({"status": "saved", "email": "failed", "error": str(e)}), 202

# ───────────────────────────── Routing endpoint (OSRM) ─────────────────────────────
@app.get("/route")
def route():
    """
    GET /route?from=LAT,LNG&to=LAT,LNG
    Returns:
      {
        "polyline": str,                 # encoded (1e5)
        "points": [[lat,lng], ...],      # decoded for direct drawing
        "distanceKm": float,
        "etaSec": int,
        "source": "osrm"
      }
    """
    f = (request.args.get("from") or "").strip()
    t = (request.args.get("to") or "").strip()
    p_from = _parse_latlng(f); p_to = _parse_latlng(t)
    if not p_from or not p_to:
        return jsonify({"error": "from/to must be 'lat,lng'"}), 400

    # OSRM wants lon,lat
    flonlat = f"{p_from[1]},{p_from[0]}"; tlonlat = f"{p_to[1]},{p_to[0]}"
    url = (f"{OSRM_BASE}/route/v1/{OSRM_PROFILE}/{flonlat};{tlonlat}"
           "?alternatives=false&overview=full&geometries=polyline")
    try:
        res = requests.get(url, timeout=OSRM_TIMEOUT_SEC)
    except requests.RequestException as e:
        return jsonify({"error": f"router unreachable: {e}"}), 502

    if res.status_code != 200:
        return jsonify({"error": f"router status {res.status_code}"}), 502

    try:
        data = res.json()
    except ValueError:
        return jsonify({"error": "router returned non-JSON"}), 502

    if (data.get("code") != "Ok") or not data.get("routes"):
        return jsonify({"error": "no route"}), 422

    r0 = data["routes"][0]
    poly = (r0.get("geometry") or "")
    dist_m = float(r0.get("distance", 0.0))
    dur_s = int(r0.get("duration", 0))

    return jsonify({
        "polyline": poly,
        "points": _decode_polyline5(poly) if poly else [],
        "distanceKm": round(dist_m / 1000.0, 3),
        "etaSec": max(dur_s, 0),
        "source": "osrm",
    }), 200

@app.route('/api/provider/<firebase_uid>', methods=['GET'])
def get_provider(firebase_uid):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
SELECT
    first_name,
    last_name,
    phone,
    car_model,
    car_plate,
    profile_image_url,
    car_image_url
            FROM users
            WHERE firebase_uid = %s
        """, (firebase_uid,))

        row = cursor.fetchone()

        cursor.close()
        conn.close()

        if not row:
            return jsonify({
                "error": "Provider not found"
            }), 404

        return jsonify({
"car_model": row[3],
"car_plate": row[4],
"profile_image_url": row[5],
"car_image_url": row[6],
        })

    except Exception as e:
        print("ERROR:", e)

        return jsonify({
            "error": str(e)
        }), 500

# ───────────────────────────── NEW: /select (bidding → accepted) ─────────────────────────────
@app.post("/select")
def select_offer():
    """
    POST /select
    JSON: { "requestId": "...", "employeeId": "..." }
    - Atomically moves a serviceRequests/{requestId} from status 'bidding' to 'accepted'
      and stamps employee fields from publicUsers/{employeeId}.
    - Returns a generated tripId.
    """
    if fs is None:
        return jsonify({"error": "firestore not available"}), 500

    # Optional: require auth, but allow local dev bypass if configured
    decoded = verify_token()
    if decoded is None and not DEV_ALLOW_NO_AUTH:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    req_id = (data.get("requestId") or "").strip()
    emp_id = (data.get("employeeId") or "").strip()
    if not req_id or not emp_id:
        return jsonify({"error": "requestId and employeeId are required"}), 400

    req_ref = fs.collection("serviceRequests").document(req_id)
    emp_pub_ref = fs.collection("publicUsers").document(emp_id)

    trip_id = _gen_trip_id()

    @fb_fs.transactional
    def _tx(tx: fb_fs.Transaction):
        snap = req_ref.get(transaction=tx)
        if not snap.exists:
            raise ValueError("missing")
        data = snap.to_dict() or {}
        status = str(data.get("status") or "pending")
        if status != "bidding":
            raise ValueError("taken")

        emp_snap = emp_pub_ref.get(transaction=tx)
        emp = emp_snap.to_dict() if emp_snap.exists else {}

        update = {
            "status": "accepted",
            "employeeId": emp_id,
            "employeeName": emp.get("name"),
            "employeePhone": emp.get("phone"),
            "employeeFare": emp.get("fare"),
            "employeeProfession": emp.get("profession"),
            "employeePhotoUrl": emp.get("photoUrl") or emp.get("profileImage"),
            "acceptedAt": fb_fs.SERVER_TIMESTAMP,
            "tripId": trip_id,
        }
        tx.update(req_ref, update)

    try:
        tx = fs.transaction()
        _tx(tx)
        return jsonify({"ok": True, "tripId": trip_id}), 200
    except ValueError as e:
        if str(e) == "taken":
            return jsonify({"ok": False, "error": "already accepted"}), 409
        if str(e) == "missing":
            return jsonify({"ok": False, "error": "request not found"}), 404
        return jsonify({"ok": False, "error": str(e)}), 400
    except Exception as e:
        log.exception("/select failed")
        return jsonify({"ok": False, "error": f"{type(e).__name__}: {e}"}), 500

# ───────────────────────────── main ─────────────────────────────
if __name__ == "__main__":

    port = env_int("PORT", 5000)

    socketio.run(
        app,
        host="0.0.0.0",
        port=port,
        debug=env_bool("FLASK_DEBUG", False)
    )


