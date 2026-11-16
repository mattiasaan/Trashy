"""Riconosce la lingua e la categoria di rifiuto da un testo libero."""
from . import ai, config
from .rules import PATTERNS, normalize

_STOPWORDS = {
    "it": {"il", "lo", "la", "le", "gli", "dove", "come", "butto", "buttare", "di", "che",
           "un", "una", "ho", "per", "del", "della", "in", "non", "vecchio", "vecchia", "rotto"},
    "de": {"der", "die", "das", "wo", "wohin", "wie", "ich", "ein", "eine", "einen", "und",
           "mit", "habe", "kann", "werfe", "ist", "den", "nicht", "alte", "alten", "altes", "kaputt"},
}


def detect_lang(text: str) -> str:
    """Rilevamento semplice it/de basato su parole comuni. Default: it."""
    if any(ch in text.lower() for ch in "äöüß"):
        return "de"
    words = set(normalize(text).split())
    de = len(words & _STOPWORDS["de"])
    it = len(words & _STOPWORDS["it"])
    return "de" if de > it else "it"


def classify_regex(text: str) -> dict:
    """Vince il match più lungo (= più specifico) tra tutte le categorie."""
    norm = normalize(text)
    best = None  # (lunghezza, categoria, testo trovato)
    for cid, patterns in PATTERNS.items():
        for p in patterns:
            m = p.search(norm)
            if m and (best is None or len(m.group(0)) > best[0]):
                best = (len(m.group(0)), cid, m.group(0))
    if best is None:
        return {"category": None, "item": None}
    return {"category": best[1], "item": best[2].strip()}


def classify(text: str, ip: str = "unknown") -> dict:
    """Ritorna {"category", "item", "source"}.

    Default: prima le regex; l'AI (se attiva) solo quando le regex non trovano nulla.
    Con AI_FIRST=true l'AI viene chiamata sempre. Se l'AI fallisce si usano le regex.
    """
    regex = classify_regex(text)
    if config.AI_ENABLED and (config.AI_FIRST or regex["category"] is None):
        result = ai.classify(text, ip)
        if result is not None:
            return {**result, "source": "ai"}
    return {**regex, "source": "regex"}
