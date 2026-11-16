"""Caricamento delle regole di conferimento dal file JSON."""
import json
import re
import unicodedata

from .config import RULES_PATH

with open(RULES_PATH, encoding="utf-8") as f:
    _data = json.load(f)

MUNICIPALITY = _data["municipality"]
SOURCE = _data.get("source")
NOTES = _data.get("notes", [])
CATEGORIES = {c["id"]: c for c in _data["categories"]}
PATTERNS = {
    cid: [re.compile(p) for p in c["patterns"]] for cid, c in CATEGORIES.items()
}


def normalize(text: str) -> str:
    """Minuscolo, senza accenti/umlaut: 'Kühlschrank' -> 'kuhlschrank'."""
    text = text.lower().replace("ß", "ss")
    text = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in text if not unicodedata.combining(ch))


def localized(category_id: str, lang: str) -> dict:
    """Categoria pronta per il frontend, nella lingua richiesta."""
    c = CATEGORIES[category_id]
    return {
        "id": c["id"],
        "name": c["name"][lang],
        "bin": c["bin"][lang],
        "color": c["color"],
        "instructions": c["instructions"][lang],
        "has_points": c["points"] is not None,
        "ref": c.get("ref"),
    }


def localized_notes(lang: str) -> list[dict]:
    return [{"id": n["id"], "text": n[lang], "ref": n.get("ref")} for n in NOTES]
