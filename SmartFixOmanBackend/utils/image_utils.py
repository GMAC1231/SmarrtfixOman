from __future__ import annotations

from typing import Optional


def sniff_image_mime(data: bytes) -> Optional[str]:
    b = data or b""
    if len(b) >= 3 and b[:3] == b"\xFF\xD8\xFF":
        return "image/jpeg"
    if len(b) >= 8 and b[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(b) >= 6 and b[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if len(b) >= 2 and b[:2] == b"BM":
        return "image/bmp"
    if len(b) >= 4 and b[:4] in (b"II*\x00", b"MM\x00*"):
        return "image/tiff"
    if len(b) >= 12 and b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return "image/webp"
    if len(b) >= 12 and b[4:8] == b"ftyp" and b[8:12] in (b"heic", b"heif", b"mif1", b"hevc"):
        return "image/heic"
    return None
