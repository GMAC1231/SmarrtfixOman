from __future__ import annotations

import psycopg2
from sqlalchemy import text

import extensions

MAX_EMAIL = 255
MAX_NAME = 255
MAX_ROLE = 50
MAX_PHONE = 32
MAX_CITY = 255
MAX_ADDRESS = 512
MAX_GENDER = 32
MAX_PROFESSION = 255
MAX_PROFESSION_EMOJI = 32
MAX_LICENSE = 64
MAX_CAR_PLATE = 32
MAX_PROFILE_IMAGE_URL = 255


def get_db_connection(database_url: str | None = None):
    from flask import current_app
    url = database_url or current_app.config["DATABASE_URL"]
    conn = psycopg2.connect(url)
    conn.autocommit = False
    return conn


def ensure_tables() -> None:
    ensure_users_table()
    ensure_feedback_table()
    ensure_sound_table()
    ensure_chat_table()
    alter_users_table()


def ensure_users_table() -> None:
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
        cur.execute(ddl)
        conn.commit()


def ensure_feedback_table() -> None:
    with extensions.engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS feedback (
                id SERIAL PRIMARY KEY,
                user_id TEXT,
                user_email TEXT,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                app_version TEXT,
                platform TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT NOW()
            );
        """))


def ensure_sound_table() -> None:
    with extensions.engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS sound_notifications (
                id SERIAL PRIMARY KEY,
                receiver_id TEXT NOT NULL,
                sender_id TEXT NOT NULL,
                chat_id TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """))


def ensure_chat_table() -> None:
    with extensions.engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS chat_messages (
                id SERIAL PRIMARY KEY,
                chat_id TEXT NOT NULL,
                sender_id TEXT NOT NULL,
                text TEXT,
                image_url TEXT,
                type TEXT DEFAULT 'text',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """))


def alter_users_table() -> None:
    queries = [
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name TEXT;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_name TEXT;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 5.0;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS car_model TEXT;",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS car_image_url TEXT;",
    ]
    with get_db_connection() as conn, conn.cursor() as cur:
        for query in queries:
            cur.execute(query)
        conn.commit()
