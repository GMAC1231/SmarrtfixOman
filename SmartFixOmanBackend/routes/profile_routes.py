from __future__ import annotations

import io

import psycopg2
from flask import Blueprint, jsonify, request, send_file
from psycopg2 import DataError as PGDataError
from psycopg2 import errors as pg_errors
from psycopg2.extras import RealDictCursor
from werkzeug.utils import secure_filename

from database.db import (
    MAX_ADDRESS, MAX_CAR_PLATE, MAX_CITY, MAX_EMAIL, MAX_GENDER, MAX_LICENSE,
    MAX_NAME, MAX_PHONE, MAX_PROFESSION, MAX_PROFESSION_EMOJI, MAX_PROFILE_IMAGE_URL,
    MAX_ROLE, get_db_connection,
)
from services.firebase_service import verify_token
from utils.helpers import num, trim
from utils.image_utils import sniff_image_mime

bp = Blueprint("profile", __name__)


@bp.post("/update-profile")
def update_profile():
    decoded = verify_token()
    uid = decoded.get("uid") if decoded else None
    if uid is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.form.to_dict() if request.form else (request.get_json(silent=True) or {})
    if not data and "file" not in request.files:
        return jsonify({"error": "No data provided"}), 400

    email_raw = trim(data.get("email"), MAX_EMAIL)
    email = (email_raw or f"{uid}@firebase.local").lower()
    name = trim(data.get("name"), MAX_NAME)
    role = trim(data.get("role") or "customer", MAX_ROLE)
    phone = trim(data.get("phone"), MAX_PHONE)
    city = trim(data.get("city"), MAX_CITY)
    address = trim(data.get("address"), MAX_ADDRESS)
    gender = trim(data.get("gender"), MAX_GENDER)
    profession = trim(data.get("profession"), MAX_PROFESSION)
    profession_emoji = trim(data.get("professionEmoji") or data.get("profession_emoji"), MAX_PROFESSION_EMOJI)
    fare_val = num(data.get("fare"), 0.0)
    license_number = trim(data.get("license") or data.get("license_number"), MAX_LICENSE)
    car_plate = trim(data.get("carPlate") or data.get("car_plate"), MAX_CAR_PLATE)

    profile_image_bytes = None
    profile_image_url = None
    if "file" in request.files:
        f = request.files["file"]
        if f and f.filename:
            profile_image_url = trim(secure_filename(f.filename), MAX_PROFILE_IMAGE_URL)
            blob = f.read(5 * 1024 * 1024 + 1)
            if len(blob) > 5 * 1024 * 1024:
                return jsonify({"error": "file too large"}), 413
            profile_image_bytes = blob if blob else None

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
            firebase_uid = EXCLUDED.firebase_uid,
            name = EXCLUDED.name,
            role = EXCLUDED.role,
            phone = EXCLUDED.phone,
            city = EXCLUDED.city,
            address = EXCLUDED.address,
            gender = EXCLUDED.gender,
            profession = EXCLUDED.profession,
            profession_emoji = EXCLUDED.profession_emoji,
            fare = EXCLUDED.fare,
            license_number = EXCLUDED.license_number,
            car_plate = EXCLUDED.car_plate,
            profile_image_url = COALESCE(EXCLUDED.profile_image_url, users.profile_image_url),
            profile_image = COALESCE(EXCLUDED.profile_image, users.profile_image),
            profile_complete = TRUE,
            updated_at = NOW()
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
    except pg_errors.StringDataRightTruncation as exc:
        return jsonify({"error": "DB column too small for provided data", "psql": str(exc)}), 400
    except PGDataError as exc:
        return jsonify({"error": "Invalid data for one or more fields", "psql": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": "update_profile failed", "detail": str(exc)}), 500

    image_url = f"{request.host_url.rstrip('/')}/profile-image/{email}"
    return jsonify({
        "status": "profile saved",
        "email": saved.get("email"),
        "role": saved.get("role"),
        "profile_complete": bool(saved.get("profile_complete")),
        "image_url": image_url,
    })


@bp.get("/profile-image/<path:email>")
def get_profile_image(email: str):
    email = trim(email, MAX_EMAIL)
    if not email:
        return jsonify({"error": "missing email"}), 400
    with get_db_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT profile_image FROM users WHERE email = %s", (email,))
        row = cur.fetchone()
        if not row or not row[0]:
            return jsonify({"error": "no image"}), 404
        data: bytes = row[0]
    return send_file(io.BytesIO(data), mimetype=sniff_image_mime(data) or "application/octet-stream")


@bp.get("/api/provider/<firebase_uid>")
def get_provider(firebase_uid):
    with get_db_connection() as conn, conn.cursor() as cur:
        cur.execute("""
            SELECT first_name, last_name, phone, car_model, car_plate, profile_image_url, car_image_url
            FROM users
            WHERE firebase_uid = %s
        """, (firebase_uid,))
        row = cur.fetchone()
    if not row:
        return jsonify({"error": "Provider not found"}), 404
    return jsonify({
        "first_name": row[0],
        "last_name": row[1],
        "phone": row[2],
        "car_model": row[3],
        "car_plate": row[4],
        "profile_image_url": row[5],
        "car_image_url": row[6],
    })
