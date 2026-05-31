from __future__ import annotations

import secrets
from datetime import datetime, timezone
from typing import Optional, Tuple


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def gen_trip_id() -> str:
    return f"trip_{secrets.token_hex(8)}"


def trim(value, maxlen: Optional[int] = None) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text[:maxlen] if maxlen is not None else text


def num(value, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def parse_latlng(q: str) -> Optional[Tuple[float, float]]:
    if not q or "," not in q:
        return None
    a, b = q.split(",", 1)
    try:
        lat = float(a.strip())
        lng = float(b.strip())
        if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
            return None
        return lat, lng
    except ValueError:
        return None


def decode_polyline5(poly: str) -> list[list[float]]:
    if not poly:
        return []
    idx = lat = lng = 0
    out: list[list[float]] = []
    while idx < len(poly):
        shift = result = 0
        while True:
            b = ord(poly[idx]) - 63
            idx += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        lat += ~(result >> 1) if (result & 1) else (result >> 1)
        shift = result = 0
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
