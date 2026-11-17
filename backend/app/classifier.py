"""Riconosce la lingua e la categoria di rifiuto da un testo libero."""
import logging

from . import ai, config
from .rules import PATTERNS, normalize

log = logging.getLogger(__name__)

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
    log.info("Domanda da %s: %r -> regex: %s", ip, text, regex["category"])

    if not config.AI_ENABLED:
        log.info("AI non chiamata: AI_ENABLED=false -> rispondo con le regex")
    elif not config.AI_FIRST and regex["category"] is not None:
        log.info("AI non chiamata: le regex hanno trovato '%s' e AI_FIRST=false "
                 "(metti AI_FIRST=true per usare sempre l'AI)", regex["category"])
    else:
        result = ai.classify(text, ip)
        if result is not None:
            log.info("Risposta AI: categoria=%s item=%r", result["category"], result["item"])
            return {**result, "source": "ai"}
        log.info("AI fallita o non disponibile -> rispondo con le regex (%s)", regex["category"])
    return {**regex, "source": "regex"}
