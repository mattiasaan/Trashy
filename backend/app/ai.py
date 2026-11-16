"""Classificazione tramite LLM con API compatibile OpenAI (OpenAI, Ollama, Groq, ...).

L'AI sceglie solo la categoria: le istruzioni restituite all'utente arrivano
sempre dal file delle regole ufficiali, così l'AI non può inventare regole.
"""
import json
import logging
import re

from openai import OpenAI

from . import config
from .rules import CATEGORIES

log = logging.getLogger(__name__)

_client = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        _client = OpenAI(
            base_url=config.AI_BASE_URL,
            api_key=config.AI_API_KEY,
            timeout=config.AI_TIMEOUT,
        )
    return _client


def _system_prompt() -> str:
    cats = "\n".join(
        f"- {c['id']}: {c['name']['it']} / {c['name']['de']}" for c in CATEGORIES.values()
    )
    return (
        "Sei un assistente per la raccolta differenziata a Bolzano (Alto Adige). "
        "L'utente scrive in italiano o tedesco e descrive un oggetto da buttare. "
        "Scegli UNA categoria tra queste:\n"
        f"{cats}\n\n"
        "Rispondi SOLO con un JSON: "
        '{"category": "<id oppure null se non è un rifiuto o non capisci>", '
        '"item": "<nome breve dell\'oggetto nella lingua dell\'utente>"}'
    )


def classify(text: str) -> dict | None:
    """Ritorna {"category": id|None, "item": str} oppure None se l'AI non è disponibile."""
    try:
        resp = _get_client().chat.completions.create(
            model=config.AI_MODEL,
            messages=[
                {"role": "system", "content": _system_prompt()},
                {"role": "user", "content": text},
            ],
            temperature=0,
            response_format={"type": "json_object"},
        )
        content = resp.choices[0].message.content or ""
        match = re.search(r"\{.*\}", content, re.DOTALL)
        data = json.loads(match.group(0) if match else content)
    except Exception as e:  # rete, timeout, JSON non valido, ...
        log.warning("AI non disponibile, uso le regex: %s", e)
        return None

    category = data.get("category")
    if category not in CATEGORIES:
        category = None
    return {"category": category, "item": data.get("item") or None}
