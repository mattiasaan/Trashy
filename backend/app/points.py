"""Ricerca dei punti di raccolta (importati da OpenStreetMap) nel database SQLite."""
import math
import sqlite3

from .config import DB_PATH
from .rules import CATEGORIES

SCHEMA = """
CREATE TABLE IF NOT EXISTS points (
    id TEXT PRIMARY KEY,      -- es. 'node/123'
    lat REAL NOT NULL,
    lon REAL NOT NULL,
    kind TEXT NOT NULL,       -- 'container' | 'centre' | 'pharmacy'
    name TEXT,
    materials TEXT,           -- es. ',glass_bottles,cans,' (virgole ai bordi per LIKE)
    opening_hours TEXT,
    address TEXT
);
CREATE INDEX IF NOT EXISTS idx_points_lat_lon ON points(lat, lon);
"""


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def _distance_m(lat1, lon1, lat2, lon2) -> float:
    """Distanza haversine in metri."""
    r = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def nearby(lat: float, lon: float, radius_m: int = 3000, category: str | None = None,
           kind: str | None = None, limit: int = 20) -> list[dict]:
    """Punti entro radius_m, ordinati per distanza.

    category: filtra per i punti adatti a quella categoria (vedi 'points' nel JSON delle regole).
    kind: filtra per tipo ('container', 'centre', 'pharmacy').
    """
    # Bounding box veloce in SQL, poi distanza esatta in Python
    dlat = radius_m / 111_000
    dlon = radius_m / (111_000 * max(math.cos(math.radians(lat)), 0.01))
    sql = "SELECT * FROM points WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?"
    params: list = [lat - dlat, lat + dlat, lon - dlon, lon + dlon]

    if kind:
        sql += " AND kind = ?"
        params.append(kind)

    if category:
        filt = CATEGORIES[category]["points"]
        if filt is None:  # raccolta porta a porta (es. residuo, organico): niente punti
            return []
        conds = [f"kind IN ({','.join('?' * len(filt['kinds']))})"] if filt["kinds"] else []
        params += filt["kinds"]
        for m in filt["materials"]:
            conds.append("materials LIKE ?")
            params.append(f"%,{m},%")
        if conds:
            sql += " AND (" + " OR ".join(conds) + ")"

    with connect() as conn:
        rows = conn.execute(sql, params).fetchall()

    result = []
    for r in rows:
        d = _distance_m(lat, lon, r["lat"], r["lon"])
        if d <= radius_m:
            result.append({
                "id": r["id"],
                "lat": r["lat"],
                "lon": r["lon"],
                "kind": r["kind"],
                "name": r["name"],
                "materials": [m for m in (r["materials"] or "").split(",") if m],
                "opening_hours": r["opening_hours"],
                "address": r["address"],
                "distance_m": round(d),
            })
    result.sort(key=lambda p: p["distance_m"])
    return result[:limit]


def count() -> int:
    with connect() as conn:
        return conn.execute("SELECT COUNT(*) FROM points").fetchone()[0]
